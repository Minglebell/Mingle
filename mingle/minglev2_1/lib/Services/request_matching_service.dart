import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      'status': 'waiting',
    };

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
          if (_arePotentialMatches(requestData, matchData)) {
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
    });
  }

  // Check if two requests are a potential match
  bool _arePotentialMatches(Map<String, dynamic> request1, Map<String, dynamic> request2) {
    // Check gender preference
    final gender1 = request1['gender'] as String;
    final gender2 = request2['gender'] as String;
    
    print('Checking gender match: $gender1 with $gender2');
    // Allow matching if either user's gender matches the other's preference
    if (gender1 != gender2 && gender2 != gender1) {
      print('Gender mismatch');
      return false;
    }

    // Check age range
    final ageRange1 = request1['ageRange'] as Map<String, dynamic>;
    final ageRange2 = request2['ageRange'] as Map<String, dynamic>;
    print('Checking age ranges: ${ageRange1['start']}-${ageRange1['end']} with ${ageRange2['start']}-${ageRange2['end']}');
    if (ageRange1['start'] > ageRange2['end'] || ageRange1['end'] < ageRange2['start']) {
      print('Age range mismatch');
      return false;
    }

    // Check distance
    final maxDistance1 = request1['maxDistance'] as double;
    final maxDistance2 = request2['maxDistance'] as double;
    final maxAllowedDistance = maxDistance1 < maxDistance2 ? maxDistance1 : maxDistance2;

    // Get user locations and calculate distance
    final location1 = request1['location'] as Map<String, dynamic>;
    final location2 = request2['location'] as Map<String, dynamic>;
    
    final distance = _calculateDistance(
      location1['latitude'] as double,
      location1['longitude'] as double,
      location2['latitude'] as double,
      location2['longitude'] as double,
    );

    print('Distance between users: $distance km, Max allowed: $maxAllowedDistance km');
    if (distance > maxAllowedDistance) {
      print('Distance too far');
      return false;
    }

    // Check scheduled time if both requests have it
    final scheduledTime1 = request1['scheduledTime'] as Timestamp?;
    final scheduledTime2 = request2['scheduledTime'] as Timestamp?;
    if (scheduledTime1 != null && scheduledTime2 != null) {
      final time1 = scheduledTime1.toDate();
      final time2 = scheduledTime2.toDate();
      final timeDiff = time1.difference(time2).abs();
      print('Time difference: ${timeDiff.inMinutes} minutes');
      if (timeDiff.inMinutes > 30) {
        print('Time difference too large');
        return false;
      }
    }

    print('All matching criteria passed!');
    return true;
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

      // Get the matched user's information
      final currentUserId = _auth.currentUser?.uid;
      final matchedUserId = request1Data['userId'] == currentUserId 
          ? request2Data['userId'] 
          : request1Data['userId'];

      // Fetch matched user's details
      final matchedUserDoc = await _firestore.collection('users').doc(matchedUserId).get();
      final matchedUserData = matchedUserDoc.data() as Map<String, dynamic>;

      // Calculate distance between users
      final currentUserLocation = request1Data['userId'] == currentUserId 
          ? request1Data['location'] 
          : request2Data['location'];
      final matchedUserLocation = request1Data['userId'] == currentUserId 
          ? request2Data['location'] 
          : request1Data['location'];

      final distance = _calculateDistance(
        currentUserLocation['latitude'],
        currentUserLocation['longitude'],
        matchedUserLocation['latitude'],
        matchedUserLocation['longitude'],
      );

      // Create a chat between the matched users
      final chatId = _createChatId(request1Data['userId'], request2Data['userId']);
      print('Creating chat with ID: $chatId');
      
      // Create the chat first
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [request1Data['userId'], request2Data['userId']],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'matchDetails': {
          'place': request1Data['place'],
          'category': request1Data['category'],
          'scheduledTime': request1Data['scheduledTime'],
        },
      });

      // Update both requests with the chat ID before deleting
      await Future.wait([
        _firestore.collection('requests').doc(requestId1).update({
          'chatId': chatId,
          'status': 'matched'
        }),
        _firestore.collection('requests').doc(requestId2).update({
          'chatId': chatId,
          'status': 'matched'
        })
      ]);

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

      // Navigate to FoundPage with matched user's information
      if (context.mounted) {
        NavigationService().navigateToReplacement('/found', arguments: {
          'matchedUserName': matchedUserData['name'] ?? 'Unknown',
          'matchedUserAge': matchedUserData['age']?.toString() ?? 'Unknown',
          'matchedUserDistance': distance.toStringAsFixed(1),
          'matchedUserGender': matchedUserData['gender'] ?? 'Unknown',
          'matchedUserProfileImage': matchedUserData['profileImage'] ?? '',
        });
      }
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