import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:math' as math;

// Configure logger
void _configureLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class RequestMatchingService {
  final _logger = Logger('RequestMatchingService');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _matchSubscription;
  String? _currentRequestId;
  final BuildContext context;
  Function(Map<String, dynamic>)? onMatchFound;
  bool _isProcessingMatch = false; // Add lock mechanism
  static bool _globalMatchLock = false; // Add global lock for all instances

  RequestMatchingService(this.context) {
    _configureLogger(); // Initialize logger configuration
  }

  // Getter for current request ID
  String? get currentRequestId => _currentRequestId;

  // Create a request for a specific place
  Future<void> createRequest({
    required String place,
    required String category,
    required String gender,
    required RangeValues ageRange,
    required double maxDistance,
    required DateTime? scheduledTime,
    String? timeRange,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user');

    // Get current user's data
    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data();
    if (userData == null) throw Exception('User data not found');

    // Get current user's location
    final location = userData['location'];
    if (location == null) throw Exception('User location not found');

    // Calculate age from birthday
    int? userAge;
    if (userData['birthday'] != null) {
      final birthday = userData['birthday'] as String;
      final parts = birthday.split('/');
      if (parts.length == 3) {
        final birthDate = DateTime(
          int.parse(parts[2]), // year
          int.parse(parts[1]), // month
          int.parse(parts[0]), // day
        );
        final today = DateTime.now();
        userAge = today.year - birthDate.year;
        // Adjust age if birthday hasn't occurred this year
        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          userAge--;
        }
      }
    }

    // Create request document
    final requestData = {
      'userId': currentUser.uid,
      'place': place,
      'category': category,
      'gender': gender,
      'ageRange': {
        'start': ageRange.start,
        'end': ageRange.end,
      },
      'maxDistance': maxDistance,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledTime':
          scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
      'timeRange': timeRange,
      'status': 'waiting',
      'userAge': userAge, // Add user's age to the request
    };

    _logger.info(
        'Creating request with timeRange: $timeRange and user age: $userAge');

    // Add to requests collection
    final docRef = await _firestore.collection('requests').add(requestData);
    _currentRequestId = docRef.id;

    // Start listening for matches
    _listenForMatches(docRef.id);
  }

  // Listen for potential matches
  void _listenForMatches(String requestId) {
    // Cancel any existing subscription
    _matchSubscription?.cancel();

    // Get the current user's request
    _firestore.collection('requests').doc(requestId).get().then((requestDoc) {
      if (!requestDoc.exists) {
        _logger.warning('Request document does not exist: $requestId');
        return;
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      final userId = requestData['userId'] as String;
      _logger.info('Listening for matches for user: $userId');

      // Query for potential matches
      _matchSubscription = _firestore
          .collection('requests')
          .where('status', isEqualTo: 'waiting')
          .where('userId', isNotEqualTo: userId)
          .snapshots()
          .listen((snapshot) async {
        if (_isProcessingMatch || RequestMatchingService._globalMatchLock) {
          _logger.info('Already processing a match or global lock is active, skipping this update');
          return;
        }

        _logger.info('Found ${snapshot.docs.length} potential matches');
        
        // First check if current user is still waiting
        final currentRequestDoc = await _firestore.collection('requests').doc(requestId).get();
        if (!currentRequestDoc.exists || currentRequestDoc.data()?['status'] != 'waiting') {
          _logger.info('Current user is no longer waiting for a match');
          _matchSubscription?.cancel();
          _currentRequestId = null;
          return;
        }

        // Store potential matches with their scores
        Map<String, Map<String, dynamic>> uniqueMatches = {};
        
        // Process each potential match
        for (var doc in snapshot.docs) {
          final matchData = doc.data();
          
          // Check if the potential match is still waiting
          if (matchData['status'] != 'waiting') {
            _logger.info('Potential match ${matchData['userId']} is no longer waiting');
            continue;
          }
          
          _logger.info('Checking match with user: ${matchData['userId']}');
          
          // Check if they are potential matches
          if (await _arePotentialMatches(requestData, matchData)) {
            // Get user data for scoring
            final user1Doc = await _firestore.collection('users').doc(userId).get();
            final user2Doc = await _firestore.collection('users').doc(matchData['userId']).get();
            
            if (user1Doc.exists && user2Doc.exists) {
              final user1Data = user1Doc.data() as Map<String, dynamic>;
              final user2Data = user2Doc.data() as Map<String, dynamic>;
              
              // Calculate bidirectional scores
              final score1to2 = await _calculateMatchScore(user1Data, user2Data, requestData['place']);
              final score2to1 = await _calculateMatchScore(user2Data, user1Data, requestData['place']);
              final totalScore = score1to2 + score2to1;
              
              _logger.info('Match score with ${matchData['userId']}: $totalScore (User1→User2: $score1to2, User2→User1: $score2to1)');
              
              // Use a unique key combining both user IDs
              final List<String> sortedIds = [userId, matchData['userId']];
              sortedIds.sort();
              final uniqueKey = '${sortedIds[0]}_${sortedIds[1]}';
              
              // Only add if this is a better score for this unique pair
              if (!uniqueMatches.containsKey(uniqueKey) || 
                  uniqueMatches[uniqueKey]!['score'] < totalScore) {
                uniqueMatches[uniqueKey] = {
                  'requestId': doc.id,
                  'userId': matchData['userId'],
                  'score': totalScore,
                  'score1to2': score1to2,
                  'score2to1': score2to1,
                  'user1Name': user1Data['name'],
                  'user2Name': user2Data['name'],
                  'timestamp': matchData['createdAt'] as Timestamp? ?? Timestamp.now()
                };
              }
            }
          }
        }
        
        // Convert unique matches to list and sort
        final potentialMatches = uniqueMatches.values.toList();
        potentialMatches.sort((a, b) {
          // First sort by score
          final scoreCompare = (b['score'] as double).compareTo(a['score'] as double);
          if (scoreCompare != 0) return scoreCompare;
          
          // If scores are equal, sort by timestamp (newer first)
          return (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp);
        });
        
        // Log all potential matches and their scores
        _logger.info('All potential matches sorted by score:');
        for (var match in potentialMatches) {
          _logger.info('User ${match['user1Name']} ↔ ${match['user2Name']}: Total Score = ${match['score']} (${match['score1to2']} + ${match['score2to1']})');
        }
        
        // If we have any potential matches, take the best one
        if (potentialMatches.isNotEmpty) {
          final bestMatch = potentialMatches.first;
          _logger.info('Best match found: ${bestMatch['user1Name']} ↔ ${bestMatch['user2Name']} with total score ${bestMatch['score']}');
          
          // Set both local and global processing locks
          _isProcessingMatch = true;
          RequestMatchingService._globalMatchLock = true;
          
          try {
            // Double check both users are still waiting before creating match
            final currentRequestCheck = await _firestore.collection('requests').doc(requestId).get();
            final matchRequestCheck = await _firestore.collection('requests').doc(bestMatch['requestId']).get();
            
            if (currentRequestCheck.exists && 
                matchRequestCheck.exists && 
                currentRequestCheck.data()?['status'] == 'waiting' && 
                matchRequestCheck.data()?['status'] == 'waiting') {
              _logger.info('Both users are still waiting, creating match...');
              
              // Add a small delay to ensure we have the latest state
              await Future.delayed(const Duration(milliseconds: 100));
              
              // Final check to ensure we're still the best match
              final finalCurrentRequest = await _firestore.collection('requests').doc(requestId).get();
              final finalMatchRequest = await _firestore.collection('requests').doc(bestMatch['requestId']).get();
              
              if (finalCurrentRequest.exists && 
                  finalMatchRequest.exists && 
                  finalCurrentRequest.data()?['status'] == 'waiting' && 
                  finalMatchRequest.data()?['status'] == 'waiting') {
                try {
                  // Get current user data for verification
                  final currentUserDoc = await _firestore.collection('users').doc(userId).get();
                  if (!currentUserDoc.exists) {
                    _logger.warning('Current user data not found during verification');
                    return;
                  }
                  final user1Data = currentUserDoc.data() as Map<String, dynamic>;
                  
                  // Verify this is still the best match by checking all potential matches again
                  final verifySnapshot = await _firestore
                      .collection('requests')
                      .where('status', isEqualTo: 'waiting')
                      .where('userId', isNotEqualTo: userId)
                      .get();
                      
                  bool isStillBestMatch = true;
                  for (var doc in verifySnapshot.docs) {
                    if (doc.id == bestMatch['requestId']) continue;
                    
                    final verifyData = doc.data();
                    if (verifyData['status'] != 'waiting') continue;
                    
                    if (await _arePotentialMatches(requestData, verifyData)) {
                      final verifyUserDoc = await _firestore.collection('users').doc(verifyData['userId']).get();
                      if (verifyUserDoc.exists) {
                        final verifyUserData = verifyUserDoc.data() as Map<String, dynamic>;
                        final verifyScore1to2 = await _calculateMatchScore(user1Data, verifyUserData, requestData['place']);
                        final verifyScore2to1 = await _calculateMatchScore(verifyUserData, user1Data, requestData['place']);
                        final verifyTotalScore = verifyScore1to2 + verifyScore2to1;
                        
                        if (verifyTotalScore > bestMatch['score']) {
                          isStillBestMatch = false;
                          _logger.info('Found a better match during verification, skipping current match');
                          break;
                        }
                      }
                    }
                  }
                  
                  if (isStillBestMatch) {
                    // Try to handle the match with retries
                    bool matchSuccess = false;
                    int retryCount = 0;
                    const maxRetries = 3;
                    
                    while (!matchSuccess && retryCount < maxRetries) {
                      try {
                        await _handleMatch(requestId, bestMatch['requestId']);
                        matchSuccess = true;
                      } catch (e) {
                        retryCount++;
                        if (e.toString().contains('permission-denied')) {
                          _logger.warning('Permission denied while handling match (Attempt $retryCount). This might be due to concurrent updates.');
                          if (retryCount < maxRetries) {
                            // Wait before retrying with exponential backoff
                            await Future.delayed(Duration(milliseconds: 500 * retryCount));
                            continue;
                          }
                        }
                        _logger.severe('Error handling match: $e');
                        break;
                      }
                    }
                    
                    if (!matchSuccess) {
                      _logger.warning('Failed to create match after $maxRetries attempts');
                    }
                  }
                } catch (e) {
                  _logger.severe('Error during match verification: $e');
                }
              } else {
                _logger.info('One or both users are no longer waiting after final check, skipping match');
              }
            } else {
              _logger.info('One or both users are no longer waiting, skipping match');
            }
          } finally {
            // Release both local and global processing locks
            _isProcessingMatch = false;
            RequestMatchingService._globalMatchLock = false;
          }
        } else {
          _logger.info('No valid matches found');
        }
      }, onError: (error) {
        _logger.severe('Error in match subscription: $error');
        if (error.toString().contains('requires an index')) {
          _logger.info('Please wait while the matching system is being set up. This may take a few minutes.');
        } else {
          _logger.severe('An error occurred while searching for matches: $error');
        }
        // Release both locks in case of error
        _isProcessingMatch = false;
        RequestMatchingService._globalMatchLock = false;
      });

      // Also listen for when this request gets matched
      _firestore
          .collection('requests')
          .doc(requestId)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'matched' && data['matchedWith'] != null) {
            _logger.info('Request was matched with user: ${data['matchedWith']}');
            // Get the matched user's information
            _firestore
                .collection('users')
                .doc(data['matchedWith'])
                .get()
                .then((userDoc) {
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                // Calculate distance
                final distance = _calculateDistance(
                  data['location']['latitude'],
                  data['location']['longitude'],
                  userData['location']['latitude'],
                  userData['location']['longitude'],
                );

                // Create matched user info
                final matchedUserInfo = {
                  'matchedUserName': userData['name'] ?? 'Unknown',
                  'matchedUserAge': userData['age']?.toString() ?? 'Unknown',
                  'matchedUserDistance': distance.toStringAsFixed(1),
                  'matchedUserGender': userData['gender'] ?? 'Unknown',
                  'matchedUserProfileImage': userData['profileImage'] ?? '',
                  'chatId': data['chatId'],
                };

                // Call the onMatchFound callback
                if (onMatchFound != null) {
                  onMatchFound!(matchedUserInfo);
                }
              }
            });
          }
        }
      });
    });
  }

  // Calculate match score between two users based on preferences
  Future<double> _calculateMatchScore(Map<String, dynamic> user1Data, Map<String, dynamic> user2Data, String place) async {
    double score = 0.0;
    _logger.info('Calculating match score between users: ${user1Data['name']} and ${user2Data['name']}');

    // Smoking preferences
    final smoking1 = List<String>.from(user1Data['smoking'] ?? []);
    final smoking2 = List<String>.from(user2Data['smoking'] ?? []);
    if (smoking1.isNotEmpty && smoking2.isNotEmpty) {
      final smoking1Status = smoking1.first;
      final smoking2Status = smoking2.first;
      
      _logger.info('Smoking preferences - User1: $smoking1Status, User2: $smoking2Status');
      
      if (smoking1Status == smoking2Status) {
        score += 3;
        _logger.info('Smoking exact match: +3');
      } else if (smoking1Status == 'Avoidance with smoker') {
        if (smoking2Status == 'Regular smoker') {
          _logger.info('Smoking mismatch: Avoidance with smoker → Regular smoker');
          return double.negativeInfinity;
        } else if (['Occasional smoker', 'Only smoke when drinking'].contains(smoking2Status)) {
          score -= 5;
          _logger.info('Smoking partial mismatch: -5');
        }
      } else if (smoking1Status == 'Non-smoker' && smoking2Status == 'Regular smoker') {
        score -= 5;
        _logger.info('Smoking mismatch: Non-smoker → Regular smoker: -5');
      }
    }

    // Alcohol preferences
    final alcohol1 = List<String>.from(user1Data['alcoholic'] ?? []);
    final alcohol2 = List<String>.from(user2Data['alcoholic'] ?? []);
    if (alcohol1.isNotEmpty && alcohol2.isNotEmpty) {
      final alcohol1Status = alcohol1.first;
      final alcohol2Status = alcohol2.first;
      
      _logger.info('Alcohol preferences - User1: $alcohol1Status, User2: $alcohol2Status');
      
      if (alcohol1Status == alcohol2Status) {
        score += 3;
        _logger.info('Alcohol exact match: +3');
      } else {
        final alcoholScores = {
          'Never': {'Rarely': 1, 'Occasionally': 0, 'Regularly': -3},
          'Rarely': {'Never': 1, 'Occasionally': 1, 'Regularly': -1},
          'Occasionally': {'Never': 0, 'Rarely': 1, 'Regularly': 1},
          'Regularly': {'Never': -1, 'Rarely': 0, 'Occasionally': 1}
        };
        final alcoholScore = alcoholScores[alcohol1Status]?[alcohol2Status] ?? 0;
        score += alcoholScore;
        _logger.info('Alcohol partial match: $alcoholScore');
      }
    }

    // Allergies
    final allergies1 = List<String>.from(user1Data['allergies'] ?? []);
    final allergies2 = List<String>.from(user2Data['allergies'] ?? []);
    if (allergies1.isNotEmpty && allergies2.isNotEmpty) {
      _logger.info('Checking allergies - User1: $allergies1, User2: $allergies2');
      
      if (place == 'Zoos' && allergies2.contains('Animal dander')) {
        score -= 3;
        _logger.info('Allergy mismatch for Zoos: -3');
      } else if (place == 'Seafood Restaurants' && allergies2.contains('Shellfish')) {
        score -= 5;
        _logger.info('Allergy mismatch for Seafood Restaurants: -5');
      } else if (place == 'Dessert cafes' && allergies2.contains('Milk')) {
        score -= 2;
        _logger.info('Allergy mismatch for Dessert cafes: -2');
      }
      
      // Check for shared allergies
      final sharedAllergies = allergies1.toSet().intersection(allergies2.toSet());
      if (sharedAllergies.isNotEmpty) {
        score += 2;
        _logger.info('Shared allergies: +2');
      }
    }

    // Transportation
    final transport1 = List<String>.from(user1Data['transportation'] ?? []);
    final transport2 = List<String>.from(user2Data['transportation'] ?? []);
    if (transport1.isNotEmpty && transport2.isNotEmpty) {
      _logger.info('Checking transportation - User1: $transport1, User2: $transport2');
      
      final sharedTransport = transport1.toSet().intersection(transport2.toSet());
      if (sharedTransport.isEmpty) {
        score -= 1;
        _logger.info('No shared transportation methods: -1');
      } else {
        score += 1;
        _logger.info('Shared transportation methods: +1');
      }
    }

    // Physical Activity Level
    final activity1 = List<String>.from(user1Data['physical activity level'] ?? []);
    final activity2 = List<String>.from(user2Data['physical activity level'] ?? []);
    if (activity1.isNotEmpty && activity2.isNotEmpty) {
      final outdoorPlaces = [
        "Parks", "Beaches", "Lakes", "Zoos", "Safari parks",
        "Amusement parks", "Water parks"
      ];
      
      _logger.info('Physical activity - User1: ${activity1.first}, User2: ${activity2.first}');
      
      if (outdoorPlaces.contains(place)) {
        if (activity1.first == activity2.first) {
          score += 3;
          _logger.info('Activity level exact match for outdoor place: +3');
        } else if ((activity1.first == 'Low' && activity2.first == 'High') ||
                   (activity1.first == 'High' && activity2.first == 'Low')) {
          score -= 5;
          _logger.info('Activity level mismatch for outdoor place: -5');
        } else {
          score -= 2;
          _logger.info('Activity level partial mismatch for outdoor place: -2');
        }
      } else {
        if (activity1.first == activity2.first) {
          score += 2;
          _logger.info('Activity level exact match: +2');
        } else {
          score -= 1;
          _logger.info('Activity level mismatch: -1');
        }
      }
    }

    // Personality
    final personality1 = List<String>.from(user1Data['personality'] ?? []);
    final personality2 = List<String>.from(user2Data['personality'] ?? []);
    if (personality1.isNotEmpty && personality2.isNotEmpty) {
      _logger.info('Personality - User1: ${personality1.first}, User2: ${personality2.first}');
      
      final personalityScores = {
        'Ambivert': {'Introverted': 2, 'Extroverted': 2, 'Ambivert': 2},
        'Introverted': {'Extroverted': 1, 'Introverted': -1},
        'Extroverted': {'Extroverted': 2}
      };
      final personalityScore = personalityScores[personality1.first]?[personality2.first] ?? 0;
      score += personalityScore;
      _logger.info('Personality match score: $personalityScore');
    }

    // Relationship Status
    final relationship1 = List<String>.from(user1Data['relationship status'] ?? []);
    final relationship2 = List<String>.from(user2Data['relationship status'] ?? []);
    if (relationship1.isNotEmpty && relationship2.isNotEmpty) {
      _logger.info('Relationship status - User1: ${relationship1.first}, User2: ${relationship2.first}');
      
      if (relationship1.first == relationship2.first) {
        if (relationship1.first == 'Single') {
          score += 3;
          _logger.info('Both single: +3');
        } else {
          score += 1;
          _logger.info('Same relationship status: +1');
        }
      } else if (relationship1.first == 'Single' || relationship2.first == 'Single') {
        if (['Married', 'In a relationship'].contains(relationship1.first) || 
            ['Married', 'In a relationship'].contains(relationship2.first)) {
          score -= 3;
          _logger.info('Single with married/in relationship: -3');
        } else if (relationship1.first == 'Unclear relationship' || 
                   relationship2.first == 'Unclear relationship') {
          score -= 1;
          _logger.info('Single with unclear relationship: -1');
        }
      }
    }

    // Education Level
    final education1 = List<String>.from(user1Data['education level'] ?? []);
    final education2 = List<String>.from(user2Data['education level'] ?? []);
    if (education1.isNotEmpty && education2.isNotEmpty) {
      _logger.info('Education level - User1: ${education1.first}, User2: ${education2.first}');
      
      if (education1.first == education2.first) {
        score += 2;
        _logger.info('Same education level: +2');
      } else {
        final educationScores = {
          'High school or lower': {
            'Doctorate or higher': -1,
            'Master\'s': 0,
            'Bachelor\'s': 1
          },
          'Bachelor\'s': {
            'Doctorate or higher': 0,
            'Master\'s': 1,
            'High school or lower': 0
          },
          'Doctorate or higher': {
            'Master\'s': 1,
            'High school or lower': -1,
            'Bachelor\'s': 0
          }
        };
        final educationScore = educationScores[education1.first]?[education2.first] ?? 0;
        score += educationScore;
        _logger.info('Education level score: $educationScore');
      }
    }

    // Budget Level
    final budget1 = List<String>.from(user1Data['budget level'] ?? []);
    final budget2 = List<String>.from(user2Data['budget level'] ?? []);
    if (budget1.isNotEmpty && budget2.isNotEmpty) {
      _logger.info('Budget level - User1: ${budget1.first}, User2: ${budget2.first}');
      
      if (budget1.first == budget2.first) {
        score += 3;
        _logger.info('Budget level exact match: +3');
      } else {
        _logger.info('Budget level mismatch: 0');
      }
    }

    // Religion
    final religion1 = List<String>.from(user1Data['religion'] ?? []);
    final religion2 = List<String>.from(user2Data['religion'] ?? []);
    if (religion1.isNotEmpty && religion2.isNotEmpty) {
      _logger.info('Religion - User1: ${religion1.first}, User2: ${religion2.first}');
      
      final foodPlaces = [
        "Thai restaurants", "Italian restaurants", "Japanese restaurants",
        "Chinese restaurants", "Korean restaurants", "Indian restaurants",
        "Buffet restaurants", "Thai barbecue restaurants", "Korean barbecue restaurants",
        "Japanese barbecue restaurants", "Thai-style hot pot restaurants",
        "Chinese hot pot Restaurants", "Japanese hot pot restaurants",
        "Northeastern Thai restaurants", "Steak restaurant"
      ];

      if (religion1.first == religion2.first) {
        score += 2;
        _logger.info('Same religion: +2');
      } else if (religion1.first == 'Muslim' || religion2.first == 'Muslim') {
        if (foodPlaces.contains(place)) {
          score -= 5;
          _logger.info('Muslim-Non-Muslim mismatch in food place: -5');
        } else {
          score -= 1;
          _logger.info('Muslim-Non-Muslim mismatch: -1');
        }
      }
    }

    // Pets
    final pets1 = List<String>.from(user1Data['pets'] ?? []);
    final pets2 = List<String>.from(user2Data['pets'] ?? []);
    if (pets1.isNotEmpty && pets2.isNotEmpty) {
      _logger.info('Pets - User1: $pets1, User2: $pets2');
      
      final sharedPets = pets1.toSet().intersection(pets2.toSet());
      if (sharedPets.isNotEmpty) {
        score += 2;
        _logger.info('Shared pet types: +2');
      }
    }

    // Average Rating
    final rating1 = user1Data['averageRating'] as double?;
    final rating2 = user2Data['averageRating'] as double?;
    if (rating1 != null) {
      _logger.info('User1 rating: $rating1');
      score += rating1;
      _logger.info('Added User1 rating score: $rating1');
    }
    if (rating2 != null) {
      _logger.info('User2 rating: $rating2');
      score += rating2;
      _logger.info('Added User2 rating score: $rating2');
    }

    _logger.info('Final match score: $score');
    return score;
  }

  // Find best matches using complete graph algorithm
  Future<List<Map<String, dynamic>>> _findBestMatches(List<Map<String, dynamic>> users) async {
    _logger.info('Finding best matches among ${users.length} users');
    
    final int n = users.length;
    final List<List<double>> scores = List.generate(
      n, (_) => List.filled(n, 0.0)
    );
    
    // Calculate scores for all pairs
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i != j) {
          _logger.info('Calculating score between ${users[i]['name']} and ${users[j]['name']}');
          final score = await _calculateMatchScore(
            users[i], users[j],
            users[i]['place'] ?? ''
          );
          scores[i][j] = score;
          _logger.info('Score between ${users[i]['name']} and ${users[j]['name']}: $score');
        }
      }
    }
    
    // Find best matches
    List<Map<String, dynamic>> matches = [];
    Set<int> matched = {};
    
    while (matched.length < n - 1) {
      double bestScore = double.negativeInfinity;
      int bestI = -1;
      int bestJ = -1;
      
      // Find pair with highest bidirectional score
      for (int i = 0; i < n; i++) {
        if (matched.contains(i)) continue;
        for (int j = i + 1; j < n; j++) {
          if (matched.contains(j)) continue;
          
          double totalScore = scores[i][j] + scores[j][i];
          _logger.info('Total bidirectional score between ${users[i]['name']} and ${users[j]['name']}: $totalScore');
          
          if (totalScore > bestScore) {
            bestScore = totalScore;
            bestI = i;
            bestJ = j;
          }
        }
      }
      
      if (bestI != -1 && bestJ != -1) {
        _logger.info('Found best match: ${users[bestI]['name']} ↔ ${users[bestJ]['name']} with score $bestScore');
        matches.add({
          'user1': users[bestI],
          'user2': users[bestJ],
          'score': bestScore
        });
        matched.add(bestI);
        matched.add(bestJ);
      } else {
        _logger.info('No more valid matches found');
        break;
      }
    }
    
    _logger.info('Final matches: ${matches.length} pairs');
    return matches;
  }

  // Check if two requests are a potential match
  Future<bool> _arePotentialMatches(
      Map<String, dynamic> request1, Map<String, dynamic> request2) async {
    _logger.info('Checking potential match between requests: ${request1['userId']} and ${request2['userId']}');
    
    // First check if either user is already matched
    if (request1['status'] != 'waiting' || request2['status'] != 'waiting') {
      _logger.info('One or both users are already matched');
      return false;
    }

    // First check if category and place match
    if (request1['category'] != request2['category'] ||
        request1['place'] != request2['place']) {
      _logger.info('Category or place mismatch - Category1: ${request1['category']}, Category2: ${request2['category']}, Place1: ${request1['place']}, Place2: ${request2['place']}');
      return false;
    }

    // Check if schedules match (if both have scheduled times)
    final scheduledTime1 = request1['scheduledTime'] as Timestamp?;
    final scheduledTime2 = request2['scheduledTime'] as Timestamp?;
    final timeRange1 = request1['timeRange'] as String?;
    final timeRange2 = request2['timeRange'] as String?;

    if (scheduledTime1 != null && scheduledTime2 != null) {
      final time1 = scheduledTime1.toDate();
      final time2 = scheduledTime2.toDate();

      // Check if the dates match
      if (time1.year != time2.year ||
          time1.month != time2.month ||
          time1.day != time2.day) {
        _logger.info('Date mismatch');
        return false;
      }

      // Check if the time ranges match
      if (timeRange1 != null &&
          timeRange2 != null &&
          timeRange1 != timeRange2) {
        _logger.info('Time range mismatch: $timeRange1 != $timeRange2');
        return false;
      }

      // Check if the time difference is within 30 minutes
      final timeDiff = time1.difference(time2).abs();
      if (timeDiff.inMinutes > 30) {
        _logger
            .info('Time difference too large: ${timeDiff.inMinutes} minutes');
        return false;
      }
    } else if (scheduledTime1 != null || scheduledTime2 != null) {
      // If one has a schedule and the other doesn't, they don't match
      _logger.info('Schedule mismatch - one has schedule, other doesn\'t');
      return false;
    }

    // Get user data for both requests
    final userId1 = request1['userId'] as String;
    final userId2 = request2['userId'] as String;

    // Get user profiles
    final user1Doc = _firestore.collection('users').doc(userId1).get();
    final user2Doc = _firestore.collection('users').doc(userId2).get();

    // Check gender preference using profile preferences
    Future<bool> checkGenderMatch() async {
      try {
        final user1Data = (await user1Doc).data();
        final user2Data = (await user2Doc).data();

        if (user1Data == null || user2Data == null) return false;

        // Get gender from match menu selection (request) and profile
        final selectedGender1 = request1['gender'] as String;
        final selectedGender2 = request2['gender'] as String;
        final user1Gender = List<String>.from(user1Data['gender'] ?? []);
        final user2Gender = List<String>.from(user2Data['gender'] ?? []);

        // Check if the selected genders match between users
        final hasMatchingGender = (selectedGender1 == user2Gender.first) &&
            (selectedGender2 == user1Gender.first);

        _logger.info(
            'Checking gender match: User1 selected $selectedGender1 with User2 profile ${user2Gender.first} and User2 selected $selectedGender2 with User1 profile ${user1Gender.first}');
        if (!hasMatchingGender) {
          _logger.warning(
              'Gender mismatch: Selected genders do not match between users');
          return false;
        }
        return true;
      } catch (e) {
        _logger.warning('Error checking gender match: $e');
        return false;
      }
    }

    // Check age range using profile preferences
    Future<bool> checkAgeMatch() async {
      try {
        // Get age from requests
        final user1Age = request1['userAge'] as int?;
        final user2Age = request2['userAge'] as int?;

        if (user1Age == null || user2Age == null) {
          _logger.warning('Age data missing in requests');
          return false;
        }

        // Get age range preferences from requests
        final ageRange1 = request1['ageRange'] as Map<String, dynamic>;
        final ageRange2 = request2['ageRange'] as Map<String, dynamic>;

        // Check if ages are within each other's preferred ranges
        final isAge1InRange2 =
            user1Age >= ageRange2['start'] && user1Age <= ageRange2['end'];
        final isAge2InRange1 =
            user2Age >= ageRange1['start'] && user2Age <= ageRange1['end'];

        _logger.info(
            'Checking age match: User1 age $user1Age in range ${ageRange2['start']}-${ageRange2['end']} and User2 age $user2Age in range ${ageRange1['start']}-${ageRange1['end']}');
        if (!isAge1InRange2 || !isAge2InRange1) {
          _logger.warning('Age mismatch based on request ages and preferences');
          return false;
        }
        return true;
      } catch (e) {
        _logger.warning('Error checking age match: $e');
        return false;
      }
    }

    // Check distance using profile locations
    Future<bool> checkDistanceMatch() async {
      try {
        final user1Data = (await user1Doc).data();
        final user2Data = (await user2Doc).data();

        if (user1Data == null || user2Data == null) return false;

        // Get locations from profiles
        final location1 = user1Data['location'] as Map<String, dynamic>?;
        final location2 = user2Data['location'] as Map<String, dynamic>?;

        if (location1 == null || location2 == null) {
          _logger.warning('Location data missing in profiles');
          return false;
        }

        // Get max distance preferences from requests
        final maxDistance1 = request1['maxDistance'] as double;
        final maxDistance2 = request2['maxDistance'] as double;
        final maxAllowedDistance =
            maxDistance1 < maxDistance2 ? maxDistance1 : maxDistance2;

        // Calculate distance between users using profile locations
        final distance = _calculateDistance(
          location1['latitude'] as double,
          location1['longitude'] as double,
          location2['latitude'] as double,
          location2['longitude'] as double,
        );

        _logger.info(
            'Distance between users from profiles: $distance km, Max allowed: $maxAllowedDistance km');
        if (distance > maxAllowedDistance) {
          _logger.warning('Distance too far based on profile locations');
          return false;
        }
        return true;
      } catch (e) {
        _logger.warning('Error checking distance match: $e');
        return false;
      }
    }

    // Check additional preferences
    Future<bool> checkAdditionalPreferences() async {
      try {
        final user1Data = (await user1Doc).data();
        final user2Data = (await user2Doc).data();

        if (user1Data == null || user2Data == null) return true;

        // All preferences are now handled in the scoring system
        // No strict matching criteria here
        _logger.info('All basic checks passed, proceeding to scoring system');
        return true;
      } catch (e) {
        _logger.warning('Error checking additional preferences: $e');
        return true; // Default to true if there's an error
      }
    }

    // Execute all checks
    _logger.info('Executing all basic checks...');
    final results = await Future.wait([
      checkGenderMatch(),
      checkAgeMatch(),
      checkDistanceMatch(),
      checkAdditionalPreferences(),
    ]);

    final allChecksPassed = results.every((result) => result);
    if (!allChecksPassed) {
      _logger.info('Basic matching criteria failed');
      return false;
    }

    _logger.info('All basic checks passed, proceeding with scoring system');

    // If basic checks pass, proceed with scoring system
    final user1Data = (await user1Doc).data()!;
    final user2Data = (await user2Doc).data()!;

    // Calculate bidirectional scores
    _logger.info('Calculating bidirectional scores...');
    final score1to2 = await _calculateMatchScore(user1Data, user2Data, request1['place']);
    final score2to1 = await _calculateMatchScore(user2Data, user1Data, request1['place']);
    
    _logger.info('Bidirectional scores - User1→User2: $score1to2, User2→User1: $score2to1');
    
    // If either score is negative infinity, it's a definite mismatch
    if (score1to2 == double.negativeInfinity || score2to1 == double.negativeInfinity) {
      _logger.info('Scoring system detected definite mismatch');
      return false;
    }

    // Calculate total bidirectional score
    final totalScore = score1to2 + score2to1;
    _logger.info('Total bidirectional score: $totalScore');

    // Only match if the total score is positive
    return totalScore > 0;
  }

  // Calculate distance between two points
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  // Handle match between two users
  Future<void> _handleMatch(String requestId1, String requestId2) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        _logger.info('Handling match between requests: $requestId1 and $requestId2 (Attempt ${retryCount + 1})');

        // Use a transaction to ensure atomic updates
        await _firestore.runTransaction((transaction) async {
          // Get both requests
          final request1Doc = await transaction.get(_firestore.collection('requests').doc(requestId1));
          final request2Doc = await transaction.get(_firestore.collection('requests').doc(requestId2));

          if (!request1Doc.exists || !request2Doc.exists) {
            _logger.warning('One or both requests no longer exist');
            return;
          }

          final request1Data = request1Doc.data() as Map<String, dynamic>;
          final request2Data = request2Doc.data() as Map<String, dynamic>;

          // Double check both requests are still waiting
          if (request1Data['status'] != 'waiting' || request2Data['status'] != 'waiting') {
            _logger.warning('One or both requests are no longer waiting');
            return;
          }

          // Get both users' information
          final user1Doc = await transaction.get(_firestore.collection('users').doc(request1Data['userId']));
          final user2Doc = await transaction.get(_firestore.collection('users').doc(request2Data['userId']));

          if (!user1Doc.exists || !user2Doc.exists) {
            _logger.warning('One or both user profiles no longer exist');
            return;
          }

          final user1Data = user1Doc.data() as Map<String, dynamic>;
          final user2Data = user2Doc.data() as Map<String, dynamic>;

          // Calculate distance between users
          final distance = _calculateDistance(
            request1Data['location']['latitude'],
            request1Data['location']['longitude'],
            request2Data['location']['latitude'],
            request2Data['location']['longitude'],
          );

          // Create a chat between the matched users
          final chatId = _createChatId(request1Data['userId'], request2Data['userId']);
          _logger.info('Creating chat with ID: $chatId');

          // Create the chat first with match details including timeRange
          transaction.set(_firestore.collection('chats').doc(chatId), {
            'participants': [request1Data['userId'], request2Data['userId']],
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': null,
            'lastMessageTime': null,
            'matchDetails': {
              'place': request1Data['place'],
              'category': request1Data['category'],
              'scheduledTime': request1Data['scheduledTime'],
              'timeRange': request1Data['timeRange'],
            },
          });

          // Update both requests with the chat ID and match status
          transaction.update(_firestore.collection('requests').doc(requestId1), {
            'chatId': chatId,
            'status': 'matched',
            'matchedWith': request2Data['userId'],
            'matchedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(_firestore.collection('requests').doc(requestId2), {
            'chatId': chatId,
            'status': 'matched',
            'matchedWith': request1Data['userId'],
            'matchedAt': FieldValue.serverTimestamp(),
          });

          // Create matched user info for both users
          final matchedUserInfo1 = {
            'matchedUserName': user2Data['name'] ?? 'Unknown',
            'matchedUserAge': user2Data['age']?.toString() ?? 'Unknown',
            'matchedUserDistance': distance.toStringAsFixed(1),
            'matchedUserGender': user2Data['gender'] ?? 'Unknown',
            'matchedUserProfileImage': user2Data['profileImage'] ?? '',
            'chatId': chatId,
          };

          final matchedUserInfo2 = {
            'matchedUserName': user1Data['name'] ?? 'Unknown',
            'matchedUserAge': user1Data['age']?.toString() ?? 'Unknown',
            'matchedUserDistance': distance.toStringAsFixed(1),
            'matchedUserGender': user1Data['gender'] ?? 'Unknown',
            'matchedUserProfileImage': user1Data['profileImage'] ?? '',
            'chatId': chatId,
          };

          // Call the onMatchFound callback for both users
          if (onMatchFound != null) {
            onMatchFound!(matchedUserInfo1);
            onMatchFound!(matchedUserInfo2);
          }
        });

        // Now try to delete the requests
        try {
          await Future.wait([
            _firestore.collection('requests').doc(requestId1).delete(),
            _firestore.collection('requests').doc(requestId2).delete()
          ]);
          _logger.info('Successfully deleted matched requests');
        } catch (e) {
          _logger.warning('Warning: Could not delete requests: $e');
          // Continue even if deletion fails, as the requests are marked as matched
        }

        // If we get here, the match was successful
        _matchSubscription?.cancel();
        _currentRequestId = null;
        _logger.info('Match handling completed successfully');
        return; // Exit the retry loop on success

      } catch (e) {
        retryCount++;
        if (e.toString().contains('permission-denied')) {
          _logger.warning('Permission denied while handling match (Attempt $retryCount). This might be due to concurrent updates.');
          if (retryCount < maxRetries) {
            // Wait before retrying with exponential backoff
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
            continue;
          }
        }
        _logger.severe('Error handling match: $e');
        rethrow;
      }
    }
  }

  String _createChatId(String uid1, String uid2) {
    // Create a consistent chat ID by sorting the UIDs
    final sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }

  // Cancel request
  Future<void> cancelRequest(String requestId) async {
    try {
      // Cancel the subscription first
      _matchSubscription?.cancel();
      _matchSubscription = null;

      // Delete the request from Firestore
      await _firestore.collection('requests').doc(requestId).delete();

      // Clear the current request ID
      _currentRequestId = null;
    } catch (e) {
      _logger.severe('Error canceling request: $e');
      rethrow;
    }
  }

  void dispose() {
    _matchSubscription?.cancel();
    _currentRequestId = null;
  }
}
