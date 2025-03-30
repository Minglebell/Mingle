import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Calculate distance between two points using the Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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

  // Calculate age from birthday
  int calculateAge(String birthday) {
    final parts = birthday.split('/');
    final birthDate = DateTime(
      int.parse(parts[2]), // year
      int.parse(parts[1]), // month
      int.parse(parts[0]), // day
    );
    final today = DateTime.now();
    return (today.difference(birthDate).inDays / 365).floor();
  }

  Future<List<Map<String, dynamic>>> findMatches({
    required String gender,
    required RangeValues ageRange,
    required double maxDistance,
  }) async {
    try {
      // Get current user's data
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final currentUserData = currentUserDoc.data();
      
      if (currentUserData == null) return [];

      // Get current user's location
      final currentLocation = currentUserData['location'];
      if (currentLocation == null) return [];

      final currentLat = currentLocation['latitude'];
      final currentLon = currentLocation['longitude'];

      // Query all users
      final usersSnapshot = await _firestore.collection('users').get();
      final matches = <Map<String, dynamic>>[];

      for (var doc in usersSnapshot.docs) {
        if (doc.id == currentUser.uid) continue; // Skip current user

        final userData = doc.data();
        final userLocation = userData['location'];
        if (userLocation == null) continue;

        // Check gender match
        final userGender = userData['gender'] as List<dynamic>?;
        if (userGender == null || !userGender.contains(gender)) continue;

        // Check age match
        final birthday = userData['birthday'] as String?;
        if (birthday == null) continue;

        final age = calculateAge(birthday);
        if (age < ageRange.start || age > ageRange.end) continue;

        // Check distance
        final userLat = userLocation['latitude'];
        final userLon = userLocation['longitude'];
        final distance = calculateDistance(currentLat, currentLon, userLat, userLon);
        
        if (distance > maxDistance) continue;

        // Add to matches if all criteria are met
        matches.add({
          'uid': doc.id,
          'name': userData['name'] ?? 'Unknown',
          'age': age,
          'gender': userGender.first,
          'distance': distance,
          'profileImage': userData['profileImage'],
        });
      }

      return matches;
    } catch (e) {
      print('Error finding matches: $e');
      return [];
    }
  }

  // Create a chat between two matched users
  Future<String> createChat(String matchedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      // Create a unique chat ID by combining both user IDs
      final List<String> sortedIds = [currentUser.uid, matchedUserId]..sort();
      final chatId = sortedIds.join('_');

      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // Create new chat
        await _firestore.collection('chats').doc(chatId).set({
          'participants': [currentUser.uid, matchedUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTime': null,
        });

        // Add chat reference to both users' documents
        await Future.wait([
          _firestore.collection('users').doc(currentUser.uid).update({
            'chats': FieldValue.arrayUnion([chatId])
          }),
          _firestore.collection('users').doc(matchedUserId).update({
            'chats': FieldValue.arrayUnion([chatId])
          })
        ]);
      }

      return chatId;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }
} 