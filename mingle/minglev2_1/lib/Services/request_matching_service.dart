import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'navigation_services.dart';

class RequestMatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _matchSubscription;
  String? _currentRequestId;
  final BuildContext context;
  Function(Map<String, dynamic>)? onMatchFound;

  RequestMatchingService(this.context);

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
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
      'timeRange': timeRange,
      'status': 'waiting',
      'userAge': userAge, // Add user's age to the request
    };

    print('Creating request with timeRange: $timeRange and user age: $userAge');

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
        print('Request document does not exist: $requestId');
        return;
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      final userId = requestData['userId'] as String;
      print('Listening for matches for user: $userId');

      // Query for potential matches
      _matchSubscription = _firestore
          .collection('requests')
          .where('status', isEqualTo: 'waiting')
          .where('userId', isNotEqualTo: userId)
          .snapshots()
          .listen((snapshot) async {
        print('Found ${snapshot.docs.length} potential matches');
        for (var doc in snapshot.docs) {
          final matchData = doc.data();
          print('Checking match with user: ${matchData['userId']}');
          if (await _arePotentialMatches(requestData, matchData)) {
            print('Match found! Creating chat...');
            await _handleMatch(requestId, doc.id);
            break;
          }
        }
      }, onError: (error) {
        print('Error in match subscription: $error');
        if (error.toString().contains('requires an index')) {
          // Show a user-friendly message about the missing index
          print('Please wait while the matching system is being set up. This may take a few minutes.');
          // You might want to show this message to the user in the UI
        } else {
          print('An error occurred while searching for matches: $error');
        }
      });

      // Also listen for when this request gets matched
      _firestore.collection('requests').doc(requestId).snapshots().listen((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'matched' && data['matchedWith'] != null) {
            print('Request was matched with user: ${data['matchedWith']}');
            // Get the matched user's information
            _firestore.collection('users').doc(data['matchedWith']).get().then((userDoc) {
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                // Calculate distance
                final distance = _calculateDistance(
                  requestData['location']['latitude'],
                  requestData['location']['longitude'],
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

  // Check if two requests are a potential match
  Future<bool> _arePotentialMatches(Map<String, dynamic> request1, Map<String, dynamic> request2) async {
    // First check if category and place match
    if (request1['category'] != request2['category'] || request1['place'] != request2['place']) {
      print('Category or place mismatch');
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
      if (time1.year != time2.year || time1.month != time2.month || time1.day != time2.day) {
        print('Date mismatch');
        return false;
      }
      
      // Check if the time ranges match
      if (timeRange1 != null && timeRange2 != null && timeRange1 != timeRange2) {
        print('Time range mismatch: $timeRange1 != $timeRange2');
        return false;
      }
      
      // Check if the time difference is within 30 minutes
      final timeDiff = time1.difference(time2).abs();
      if (timeDiff.inMinutes > 30) {
        print('Time difference too large: ${timeDiff.inMinutes} minutes');
        return false;
      }
    } else if (scheduledTime1 != null || scheduledTime2 != null) {
      // If one has a schedule and the other doesn't, they don't match
      print('Schedule mismatch - one has schedule, other doesn\'t');
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

        // Check if the selected gender matches the other user's profile gender
        final hasMatchingGender = 
            (selectedGender1 == user2Gender.first) && 
            (selectedGender2 == user1Gender.first);

        print('Checking gender match: Selected gender $selectedGender1 with profile gender ${user2Gender.first} and Selected gender $selectedGender2 with profile gender ${user1Gender.first}');
        if (!hasMatchingGender) {
          print('Gender mismatch: Selected gender does not match profile gender');
          return false;
        }
        return true;
      } catch (e) {
        print('Error checking gender match: $e');
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
          print('Age data missing in requests');
          return false;
        }

        // Get age range preferences from requests
        final ageRange1 = request1['ageRange'] as Map<String, dynamic>;
        final ageRange2 = request2['ageRange'] as Map<String, dynamic>;

        // Check if ages are within each other's preferred ranges
        final isAge1InRange2 = user1Age >= ageRange2['start'] && user1Age <= ageRange2['end'];
        final isAge2InRange1 = user2Age >= ageRange1['start'] && user2Age <= ageRange1['end'];

        print('Checking age match: User1 age $user1Age in range ${ageRange2['start']}-${ageRange2['end']} and User2 age $user2Age in range ${ageRange1['start']}-${ageRange1['end']}');
        if (!isAge1InRange2 || !isAge2InRange1) {
          print('Age mismatch based on request ages and preferences');
          return false;
        }
        return true;
      } catch (e) {
        print('Error checking age match: $e');
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
          print('Location data missing in profiles');
          return false;
        }

        // Get max distance preferences from requests
        final maxDistance1 = request1['maxDistance'] as double;
        final maxDistance2 = request2['maxDistance'] as double;
        final maxAllowedDistance = maxDistance1 < maxDistance2 ? maxDistance1 : maxDistance2;

        // Calculate distance between users using profile locations
        final distance = _calculateDistance(
          location1['latitude'] as double,
          location1['longitude'] as double,
          location2['latitude'] as double,
          location2['longitude'] as double,
        );

        print('Distance between users from profiles: $distance km, Max allowed: $maxAllowedDistance km');
        if (distance > maxAllowedDistance) {
          print('Distance too far based on profile locations');
          return false;
        }
        return true;
      } catch (e) {
        print('Error checking distance match: $e');
        return false;
      }
    }

    // Check additional preferences
    Future<bool> checkAdditionalPreferences() async {
      try {
        final user1Data = (await user1Doc).data();
        final user2Data = (await user2Doc).data();
        
        if (user1Data == null || user2Data == null) return true;

        // Check religion compatibility
        final religion1 = List<String>.from(user1Data['religion'] ?? []);
        final religion2 = List<String>.from(user2Data['religion'] ?? []);
        if (religion1.isNotEmpty && religion2.isNotEmpty) {
          final hasMatchingReligion = religion1.any((r) => religion2.contains(r));
          if (!hasMatchingReligion) {
            print('Religion mismatch');
            return false;
          }
        }

        // Check budget level compatibility
        final budget1 = List<String>.from(user1Data['budget level'] ?? []);
        final budget2 = List<String>.from(user2Data['budget level'] ?? []);
        if (budget1.isNotEmpty && budget2.isNotEmpty) {
          final hasMatchingBudget = budget1.any((b) => budget2.contains(b));
          if (!hasMatchingBudget) {
            print('Budget level mismatch');
            return false;
          }
        }

        // Check education level compatibility
        final education1 = List<String>.from(user1Data['education level'] ?? []);
        final education2 = List<String>.from(user2Data['education level'] ?? []);
        if (education1.isNotEmpty && education2.isNotEmpty) {
          final hasMatchingEducation = education1.any((e) => education2.contains(e));
          if (!hasMatchingEducation) {
            print('Education level mismatch');
            return false;
          }
        }

        // Check relationship status compatibility
        final relationship1 = List<String>.from(user1Data['relationship status'] ?? []);
        final relationship2 = List<String>.from(user2Data['relationship status'] ?? []);
        if (relationship1.isNotEmpty && relationship2.isNotEmpty) {
          final hasMatchingStatus = relationship1.any((s) => relationship2.contains(s));
          if (!hasMatchingStatus) {
            print('Relationship status mismatch');
            return false;
          }
        }

        // Check lifestyle compatibility (smoking, alcohol)
        final smoking1 = List<String>.from(user1Data['smoking'] ?? []);
        final smoking2 = List<String>.from(user2Data['smoking'] ?? []);
        if (smoking1.isNotEmpty && smoking2.isNotEmpty) {
          final hasMatchingSmoking = smoking1.any((s) => smoking2.contains(s));
          if (!hasMatchingSmoking) {
            print('Smoking preference mismatch');
            return false;
          }
        }

        final alcohol1 = List<String>.from(user1Data['alcoholic'] ?? []);
        final alcohol2 = List<String>.from(user2Data['alcoholic'] ?? []);
        if (alcohol1.isNotEmpty && alcohol2.isNotEmpty) {
          final hasMatchingAlcohol = alcohol1.any((a) => alcohol2.contains(a));
          if (!hasMatchingAlcohol) {
            print('Alcohol preference mismatch');
            return false;
          }
        }

        // Check physical activity level compatibility
        final activity1 = List<String>.from(user1Data['physical activity level'] ?? []);
        final activity2 = List<String>.from(user2Data['physical activity level'] ?? []);
        if (activity1.isNotEmpty && activity2.isNotEmpty) {
          final hasMatchingActivity = activity1.any((a) => activity2.contains(a));
          if (!hasMatchingActivity) {
            print('Physical activity level mismatch');
            return false;
          }
        }

        // Check personality compatibility
        final personality1 = List<String>.from(user1Data['personality'] ?? []);
        final personality2 = List<String>.from(user2Data['personality'] ?? []);
        if (personality1.isNotEmpty && personality2.isNotEmpty) {
          final hasMatchingPersonality = personality1.any((p) => personality2.contains(p));
          if (!hasMatchingPersonality) {
            print('Personality mismatch');
            return false;
          }
        }

        print('All additional preferences match!');
        return true;
      } catch (e) {
        print('Error checking additional preferences: $e');
        return true; // Default to true if there's an error
      }
    }

    // Execute all checks
    final results = await Future.wait([
      checkGenderMatch(),
      checkAgeMatch(),
      checkDistanceMatch(),
      checkAdditionalPreferences(),
    ]);

    final allChecksPassed = results.every((result) => result);
    if (allChecksPassed) {
      print('All matching criteria passed!');
      return true;
    }
    return false;
  }

  // Calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  // Handle match between two users
  Future<void> _handleMatch(String requestId1, String requestId2) async {
    try {
      print('Handling match between requests: $requestId1 and $requestId2');
      
      // Get both requests
      final request1Doc = await _firestore.collection('requests').doc(requestId1).get();
      final request2Doc = await _firestore.collection('requests').doc(requestId2).get();

      if (!request1Doc.exists || !request2Doc.exists) {
        print('One or both requests no longer exist');
        return;
      }

      final request1Data = request1Doc.data() as Map<String, dynamic>;
      final request2Data = request2Doc.data() as Map<String, dynamic>;

      // Get both users' information
      final user1Doc = await _firestore.collection('users').doc(request1Data['userId']).get();
      final user2Doc = await _firestore.collection('users').doc(request2Data['userId']).get();
      
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
      print('Creating chat with ID: $chatId');
      
      // Create the chat first with match details including timeRange
      await _firestore.collection('chats').doc(chatId).set({
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
      await Future.wait([
        _firestore.collection('requests').doc(requestId1).update({
          'chatId': chatId,
          'status': 'matched',
          'matchedWith': request2Data['userId'],
          'matchedAt': FieldValue.serverTimestamp(),
        }),
        _firestore.collection('requests').doc(requestId2).update({
          'chatId': chatId,
          'status': 'matched',
          'matchedWith': request1Data['userId'],
          'matchedAt': FieldValue.serverTimestamp(),
        })
      ]);

      // Create matched user info for both users
      final matchedUserInfo1 = {
        'matchedUserName': user2Data['name'] ?? 'Unknown',
        'chatId': chatId,
      };

      final matchedUserInfo2 = {
        'matchedUserName': user1Data['name'] ?? 'Unknown',
        'chatId': chatId,
      };

      // Call the onMatchFound callback for both users
      if (onMatchFound != null) {
        onMatchFound!(matchedUserInfo1);
        onMatchFound!(matchedUserInfo2);
      }

      // Now try to delete the requests
      try {
        await Future.wait([
          _firestore.collection('requests').doc(requestId1).delete(),
          _firestore.collection('requests').doc(requestId2).delete()
        ]);
        print('Successfully deleted matched requests');
      } catch (e) {
        print('Warning: Could not delete requests: $e');
        // Continue even if deletion fails, as the requests are marked as matched
      }

      // Cancel the subscription
      _matchSubscription?.cancel();
      _currentRequestId = null;
      print('Match handling completed successfully');

    } catch (e) {
      print('Error handling match: $e');
      rethrow;
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
      print('Error canceling request: $e');
      rethrow;
    }
  }

  void dispose() {
    _matchSubscription?.cancel();
    _currentRequestId = null;
  }
} 