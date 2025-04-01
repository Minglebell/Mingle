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
  bool _isProcessingBatch = false;
  Timer? _batchTimer;
  List<Map<String, dynamic>> _currentBatch = [];
  static const batchDuration = Duration(seconds: 10);

  RequestMatchingService(this.context) {
    _configureLogger();
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
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
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
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
      'timeRange': timeRange,
      'status': 'waiting',
      'userAge': userAge,
      'batchId': null, // Will be set when processed
    };

    _logger.info('Creating request with timeRange: $timeRange and user age: $userAge');

    // Add to requests collection
    final docRef = await _firestore.collection('requests').add(requestData);
    _currentRequestId = docRef.id;

    // Start listening for matches
    _listenForMatches(docRef.id);
  }

  // Listen for potential matches
  void _listenForMatches(String requestId) {
    _logger.info('=== Starting Match Listener ===');
    _logger.info('Request ID: $requestId');

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
      
      _logger.info('User: $userId');
      _logger.info('Place: ${requestData['place']}');
      _logger.info('Category: ${requestData['category']}');
      _logger.info('Gender Preference: ${requestData['gender']}');
      _logger.info('Age Range: ${requestData['ageRange']['start']}-${requestData['ageRange']['end']}');
      _logger.info('Max Distance: ${requestData['maxDistance']}km');
      _logger.info('Scheduled Time: ${requestData['scheduledTime']}');
      _logger.info('Time Range: ${requestData['timeRange']}');
      _logger.info('===============================');

      // Query for potential matches
      _matchSubscription = _firestore
          .collection('requests')
          .where('status', isEqualTo: 'waiting')
          .where('userId', isNotEqualTo: userId)
          .snapshots()
          .listen((snapshot) async {
        if (_isProcessingBatch) {
          _logger.info('⏳ Already processing a batch, skipping this update');
          return;
        }

        _logger.info('🔍 Found ${snapshot.docs.length} potential matches');
        
        // First check if current user is still waiting
        final currentRequestDoc = await _firestore.collection('requests').doc(requestId).get();
        if (!currentRequestDoc.exists || currentRequestDoc.data()?['status'] != 'waiting') {
          _logger.info('❌ Current user is no longer waiting for a match');
          _matchSubscription?.cancel();
          _currentRequestId = null;
          return;
        }

        // Start a new batch if not already processing one
        if (_currentBatch.isEmpty) {
          _logger.info('🔄 Starting new batch collection');
          _currentBatch = [];
          _batchTimer?.cancel();
          _batchTimer = Timer(batchDuration, () => _processBatch());
        }

        // Add new requests to the batch
        for (var doc in snapshot.docs) {
          final matchData = doc.data();
          if (matchData['status'] == 'waiting' && 
              !_currentBatch.any((req) => req['requestId'] == doc.id)) {
            _currentBatch.add({
              'requestId': doc.id,
              'data': matchData,
              'timestamp': matchData['createdAt'] as Timestamp? ?? Timestamp.now()
            });
            _logger.info('📥 Added request ${doc.id} to current batch');
          }
        }
      }, onError: (error) {
        _logger.severe('❌ Error in match subscription: $error');
        if (error.toString().contains('requires an index')) {
          _logger.info('⏳ Please wait while the matching system is being set up. This may take a few minutes.');
        } else {
          _logger.severe('❌ An error occurred while searching for matches: $error');
        }
      });
    });
  }

  // Process the current batch of requests
  Future<void> _processBatch() async {
    if (_currentBatch.isEmpty) {
      _logger.info('📦 No requests in batch to process');
      return;
    }

    _logger.info('=== Processing Batch ===');
    _logger.info('Number of requests in batch: ${_currentBatch.length}');
    
    // Add current user's request to the batch if it exists
    if (_currentRequestId != null) {
      final currentRequestDoc = await _firestore.collection('requests').doc(_currentRequestId).get();
      if (currentRequestDoc.exists && currentRequestDoc.data()?['status'] == 'waiting') {
        _currentBatch.add({
          'requestId': _currentRequestId,
          'data': currentRequestDoc.data()!,
          'timestamp': currentRequestDoc.data()?['createdAt'] as Timestamp? ?? Timestamp.now()
        });
      }
    }

    // Generate a unique batch ID
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Update all requests with the batch ID
    final batch = _firestore.batch();
    for (var request in _currentBatch) {
      batch.update(
        _firestore.collection('requests').doc(request['requestId']),
        {'batchId': batchId}
      );
    }
    await batch.commit();

    // Create score matrix for all requests in the batch
    _logger.info('\n=== Creating Score Matrix ===');
    final n = _currentBatch.length;
    final List<List<double>> scores = List.generate(n, (_) => List.filled(n, 0.0));
    
    // Calculate scores for all pairs
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i != j) {
          final request1 = _currentBatch[i]['data'];
          final request2 = _currentBatch[j]['data'];
          
          if (await _arePotentialMatches(request1, request2)) {
            final user1Doc = await _firestore.collection('users').doc(request1['userId']).get();
            final user2Doc = await _firestore.collection('users').doc(request2['userId']).get();
            
            if (user1Doc.exists && user2Doc.exists) {
              final score1to2 = await _calculateMatchScore(
                user1Doc.data()!,
                user2Doc.data()!,
                request1['place']
              );
              final score2to1 = await _calculateMatchScore(
                user2Doc.data()!,
                user1Doc.data()!,
                request1['place']
              );
              scores[i][j] = score1to2 + score2to1;
            }
          }
        }
      }
    }

    // Print score matrix
    _logger.info('\nScore Matrix:');
    _logger.info('-' * (n * 15 + 5));
    
    String headerRow = '     ';
    for (var request in _currentBatch) {
      final userId = request['data']['userId'] as String;
      headerRow += '${userId.substring(0, 5)}... ';
    }
    _logger.info(headerRow);
    _logger.info('-' * (n * 15 + 5));
    
    for (int i = 0; i < n; i++) {
      final userId = _currentBatch[i]['data']['userId'] as String;
      String row = '${userId.substring(0, 5)}... ';
      
      for (int j = 0; j < n; j++) {
        if (i == j) {
          row += '   -    ';
          continue;
        }
        row += '${scores[i][j].toStringAsFixed(1).padLeft(6)} ';
      }
      
      _logger.info(row);
    }
    _logger.info('-' * (n * 15 + 5));

    // Find best matches using Hungarian algorithm
    _logger.info('\n=== Finding Best Matches ===');
    Set<int> matched = {};
    List<Map<String, dynamic>> matches = [];
    
    while (matched.length < n - 1) {
      double bestScore = double.negativeInfinity;
      int bestI = -1;
      int bestJ = -1;
      
      // Find pair with highest score
      for (int i = 0; i < n; i++) {
        if (matched.contains(i)) continue;
        for (int j = i + 1; j < n; j++) {
          if (matched.contains(j)) continue;
          
          if (scores[i][j] > bestScore) {
            bestScore = scores[i][j];
            bestI = i;
            bestJ = j;
          }
        }
      }
      
      if (bestI != -1 && bestJ != -1 && bestScore > 0) {
        final request1 = _currentBatch[bestI];
        final request2 = _currentBatch[bestJ];
        
        _logger.info('🎯 Found match: ${request1['data']['userId']} ↔ ${request2['data']['userId']} with score $bestScore');
        
        try {
          await _handleMatch(request1['requestId'], request2['requestId']);
          matches.add({
            'request1': request1,
            'request2': request2,
            'score': bestScore
          });
          matched.add(bestI);
          matched.add(bestJ);
        } catch (e) {
          _logger.warning('⚠️ Failed to create match: $e');
        }
      } else {
        break;
      }
    }

    _logger.info('\n=== Batch Processing Complete ===');
    _logger.info('Total matches created: ${matches.length}');
    _logger.info('Unmatched requests: ${n - matched.length}');
    
    // Clear the batch
    _currentBatch = [];
    _isProcessingBatch = false;
  }

  // Calculate match score between two users based on preferences
  Future<double> _calculateMatchScore(Map<String, dynamic> user1Data, Map<String, dynamic> user2Data, String place) async {
    double score = 0.0;

    // Smoking preferences
    final smoking1 = List<String>.from(user1Data['smoking'] ?? []);
    final smoking2 = List<String>.from(user2Data['smoking'] ?? []);
    if (smoking1.isNotEmpty && smoking2.isNotEmpty) {
      final smoking1Status = smoking1.first;
      final smoking2Status = smoking2.first;
      
      if (smoking1Status == smoking2Status) {
        score += 3;
      } else if (smoking1Status == 'Avoidance with smoker') {
        if (smoking2Status == 'Regular smoker') {
          return double.negativeInfinity;
        } else if (['Occasional smoker', 'Only smoke when drinking'].contains(smoking2Status)) {
          score -= 5;
        }
      } else if (smoking1Status == 'Non-smoker' && smoking2Status == 'Regular smoker') {
        score -= 5;
      }
    }

    // Alcohol preferences
    final alcohol1 = List<String>.from(user1Data['alcoholic'] ?? []);
    final alcohol2 = List<String>.from(user2Data['alcoholic'] ?? []);
    if (alcohol1.isNotEmpty && alcohol2.isNotEmpty) {
      final alcohol1Status = alcohol1.first;
      final alcohol2Status = alcohol2.first;
      
      if (alcohol1Status == alcohol2Status) {
        score += 3;
      } else {
        final alcoholScores = {
          'Never': {'Rarely': 1, 'Occasionally': 0, 'Regularly': -3},
          'Rarely': {'Never': 1, 'Occasionally': 1, 'Regularly': -1},
          'Occasionally': {'Never': 0, 'Rarely': 1, 'Regularly': 1},
          'Regularly': {'Never': -1, 'Rarely': 0, 'Occasionally': 1}
        };
        final alcoholScore = alcoholScores[alcohol1Status]?[alcohol2Status] ?? 0;
        score += alcoholScore;
      }
    }

    // Allergies
    final allergies1 = List<String>.from(user1Data['allergies'] ?? []);
    final allergies2 = List<String>.from(user2Data['allergies'] ?? []);
    if (allergies1.isNotEmpty && allergies2.isNotEmpty) {
      if (place == 'Zoos' && allergies2.contains('Animal dander')) {
        score -= 3;
      } else if (place == 'Seafood Restaurants' && allergies2.contains('Shellfish')) {
        score -= 5;
      } else if (place == 'Dessert cafes' && allergies2.contains('Milk')) {
        score -= 2;
      }
      
      final sharedAllergies = allergies1.toSet().intersection(allergies2.toSet());
      if (sharedAllergies.isNotEmpty) {
        score += 2;
      }
    }

    // Transportation
    final transport1 = List<String>.from(user1Data['transportation'] ?? []);
    final transport2 = List<String>.from(user2Data['transportation'] ?? []);
    if (transport1.isNotEmpty && transport2.isNotEmpty) {
      final sharedTransport = transport1.toSet().intersection(transport2.toSet());
      if (sharedTransport.isEmpty) {
        score -= 1;
      } else {
        score += 1;
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
      
      if (outdoorPlaces.contains(place)) {
        if (activity1.first == activity2.first) {
          score += 3;
        } else if ((activity1.first == 'Low' && activity2.first == 'High') ||
                   (activity1.first == 'High' && activity2.first == 'Low')) {
          score -= 5;
        } else {
          score -= 2;
        }
      } else {
        if (activity1.first == activity2.first) {
          score += 2;
        } else {
          score -= 1;
        }
      }
    }

    // Personality
    final personality1 = List<String>.from(user1Data['personality'] ?? []);
    final personality2 = List<String>.from(user2Data['personality'] ?? []);
    if (personality1.isNotEmpty && personality2.isNotEmpty) {
      final personalityScores = {
        'Ambivert': {'Introverted': 2, 'Extroverted': 2, 'Ambivert': 2},
        'Introverted': {'Extroverted': 1, 'Introverted': -1},
        'Extroverted': {'Extroverted': 2}
      };
      final personalityScore = personalityScores[personality1.first]?[personality2.first] ?? 0;
      score += personalityScore;
    }

    // Relationship Status
    final relationship1 = List<String>.from(user1Data['relationship status'] ?? []);
    final relationship2 = List<String>.from(user2Data['relationship status'] ?? []);
    if (relationship1.isNotEmpty && relationship2.isNotEmpty) {
      if (relationship1.first == relationship2.first) {
        if (relationship1.first == 'Single') {
          score += 3;
        } else {
          score += 1;
        }
      } else if (relationship1.first == 'Single' || relationship2.first == 'Single') {
        if (['Married', 'In a relationship'].contains(relationship1.first) || 
            ['Married', 'In a relationship'].contains(relationship2.first)) {
          score -= 3;
        } else if (relationship1.first == 'Unclear relationship' || 
                   relationship2.first == 'Unclear relationship') {
          score -= 1;
        }
      }
    }

    // Education Level
    final education1 = List<String>.from(user1Data['education level'] ?? []);
    final education2 = List<String>.from(user2Data['education level'] ?? []);
    if (education1.isNotEmpty && education2.isNotEmpty) {
      if (education1.first == education2.first) {
        score += 2;
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
      }
    }

    // Budget Level
    final budget1 = List<String>.from(user1Data['budget level'] ?? []);
    final budget2 = List<String>.from(user2Data['budget level'] ?? []);
    if (budget1.isNotEmpty && budget2.isNotEmpty) {
      if (budget1.first == budget2.first) {
        score += 3;
      }
    }

    // Religion
    final religion1 = List<String>.from(user1Data['religion'] ?? []);
    final religion2 = List<String>.from(user2Data['religion'] ?? []);
    if (religion1.isNotEmpty && religion2.isNotEmpty) {
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
      } else if (religion1.first == 'Muslim' || religion2.first == 'Muslim') {
        if (foodPlaces.contains(place)) {
          score -= 5;
        } else {
          score -= 1;
        }
      }
    }

    // Pets
    final pets1 = List<String>.from(user1Data['pets'] ?? []);
    final pets2 = List<String>.from(user2Data['pets'] ?? []);
    if (pets1.isNotEmpty && pets2.isNotEmpty) {
      final sharedPets = pets1.toSet().intersection(pets2.toSet());
      if (sharedPets.isNotEmpty) {
        score += 2;
      }
    }

    // Average Rating
    final rating1 = user1Data['averageRating'] as double?;
    final rating2 = user2Data['averageRating'] as double?;
    if (rating1 != null) {
      score += rating1;
    }
    if (rating2 != null) {
      score += rating2;
    }

    _logger.info('Final match score between ${user1Data['name']} and ${user2Data['name']}: $score');
    return score;
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
        'userId': request1Data['userId'], // Add current user's ID
      };

      final matchedUserInfo2 = {
        'matchedUserName': user1Data['name'] ?? 'Unknown',
        'matchedUserAge': user1Data['age']?.toString() ?? 'Unknown',
        'matchedUserDistance': distance.toStringAsFixed(1),
        'matchedUserGender': user1Data['gender'] ?? 'Unknown',
        'matchedUserProfileImage': user1Data['profileImage'] ?? '',
        'chatId': chatId,
        'userId': request2Data['userId'], // Add current user's ID
      };

      // Call the onMatchFound callback only for the current user
      if (onMatchFound != null) {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == request1Data['userId']) {
          _logger.info('Calling onMatchFound callback for current user (user1): ${request1Data['userId']}');
          onMatchFound!(matchedUserInfo1);
        } else if (currentUserId == request2Data['userId']) {
          _logger.info('Calling onMatchFound callback for current user (user2): ${request2Data['userId']}');
          onMatchFound!(matchedUserInfo2);
        } else {
          _logger.warning('Current user ID ${currentUserId} does not match either matched user');
        }
      } else {
        _logger.warning('onMatchFound callback is null! This might cause the match UI not to show.');
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
