import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:minglev2_1/services/location_service.dart';
import 'dart:async';

class DatabaseServices extends StateNotifier<Map<String, dynamic>> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSubscription;

  DatabaseServices()
      : super({
          'name': '',
          'age': '',
          'bio': '',
          'gender': <String>[],
          'religion': <String>[],
          'budget level': <String>[],
          'education level': <String>[],
          'relationship status': <String>[],
          'smoking': <String>[],
          'alcoholic': <String>[],
          'allergies': <String>[],
          'physical activity level': <String>[],
          'transportation': <String>[],
          'pet': <String>[],
          'personality': <String>[],
          'location': null,
          'lastLocationUpdate': null,
        }) {
    fetchProfile(); // Fetch profile data when the notifier is created
    startLocationTracking(); // Start tracking location
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> startLocationTracking() async {
    debugPrint('Starting location tracking...');
    final hasPermission = await LocationService.checkLocationPermission();
    debugPrint('Location permission status: $hasPermission');
    
    if (hasPermission) {
      debugPrint('Setting up location stream...');
      _locationSubscription = LocationService.getLocationStream().listen(
        (Position position) {
          debugPrint('Received location update: ${position.latitude}, ${position.longitude}');
          updateLocation(position);
        },
        onError: (error) {
          debugPrint('Error in location stream: $error');
        },
      );
    } else {
      debugPrint('Location permission denied');
    }
  }

  Future<void> updateLocation(Position position) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${currentUser?.uid}');
      
      if (currentUser != null) {
        final locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        };

        debugPrint('Updating location in Firestore: $locationData');
        
        // Update local state
        state = {
          ...state,
          'location': locationData,
          'lastLocationUpdate': DateTime.now().toIso8601String(),
        };

        // Update Firestore
        await firestore.collection('users').doc(currentUser.uid).update({
          'location': locationData,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
        
        debugPrint('Location updated successfully in Firestore');
      } else {
        debugPrint('No authenticated user found');
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        await updateLocation(position);
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> saveUserToFirestore(String phoneNumber) async {
    try {
      await firestore.collection('users').doc(phoneNumber).set({
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': true,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phoneNumber', phoneNumber);

      debugPrint('User data saved successfully');
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  Future<bool> checkIfUserExists(String phoneNumber) async {
    try {
      final doc = await firestore.collection('users').doc(phoneNumber).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      rethrow;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          debugPrint('Fetched user data: $userData');
          
          // Calculate age from birthday
          String birthday = userData['birthday'] ?? '';
          String age = '';
          if (birthday.isNotEmpty) {
            final parts = birthday.split('/');
            final birthDate = DateTime(
              int.parse(parts[2]), // year
              int.parse(parts[1]), // month
              int.parse(parts[0]), // day
            );
            final today = DateTime.now();
            age = (today.difference(birthDate).inDays / 365).floor().toString();
          }

          state = {
            'name': userData['name'] ?? '',
            'age': age,
            'bio': userData['bio'] ?? '',
            'gender': List<String>.from(userData['gender'] ?? []),
            'religion': List<String>.from(userData['religion'] ?? []),
            'budget level': List<String>.from(userData['budget level'] ?? []),
            'education level': List<String>.from(userData['education level'] ?? []),
            'relationship status': List<String>.from(userData['relationship status'] ?? []),
            'smoking': List<String>.from(userData['smoking'] ?? []),
            'alcoholic': List<String>.from(userData['alcoholic'] ?? []),
            'allergies': List<String>.from(userData['allergies'] ?? []),
            'physical activity level': List<String>.from(userData['physical activity level'] ?? []),
            'transportation': List<String>.from(userData['transportation'] ?? []),
            'pet': List<String>.from(userData['pet'] ?? []),
            'personality': List<String>.from(userData['personality'] ?? []),
            'location': userData['location'],
            'lastLocationUpdate': userData['lastLocationUpdate'],
          };
          debugPrint('Updated state with location: ${state['location']}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  void updateName(String name) {
    state = {...state, 'name': name};
  }

  void updateAge(int age) {
    state = {...state, 'age': age};
  }

  void updateBio(String bio) {
    state = {...state, 'bio': bio};
  }

  void addPreference(String category, String preference) {
    final List<String> currentPreferences = List<String>.from(state[category] ?? []);
    
    // Handle single-selection categories
    if (['gender', 'religion', 'budget level', 'education level', 
         'relationship status', 'smoking', 'alcoholic', 'physical activity level',
         'personality'].contains(category)) {
      state = {
        ...state,
        category: [preference],
      };
    }
    // Handle multi-selection categories with limits
    else if (['pet', 'allergies', 'transportation'].contains(category)) {
      if (!currentPreferences.contains(preference) && currentPreferences.length < 4) {
        state = {
          ...state,
          category: [...currentPreferences, preference],
        };
      } else if (currentPreferences.length >= 4) {
        // You can handle this case by showing a message to the user
        debugPrint('Maximum 4 selections allowed for $category');
      }
    }
  }

  void removePreference(String category, String preference) {
    if (state[category] is List<String>) {
      state = {
        ...state,
        category: (state[category] as List<String>)
            .where((item) => item != preference)
            .toList(),
      };
    }
  }

  Future<void> saveProfile() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No authenticated user found');
        return;
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(state);

      debugPrint('Profile saved successfully: $state');
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }

  Future<void> fetchUserProfile(String userId) async {
    try {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        debugPrint('Fetched user data: $userData');
        
        // Calculate age from birthday
        String birthday = userData['birthday'] ?? '';
        String age = '';
        if (birthday.isNotEmpty) {
          final parts = birthday.split('/');
          final birthDate = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
          final today = DateTime.now();
          age = (today.difference(birthDate).inDays / 365).floor().toString();
        }

        state = {
          'name': userData['name'] ?? '',
          'age': age,
          'bio': userData['bio'] ?? '',
          'gender': List<String>.from(userData['gender'] ?? []),
          'religion': List<String>.from(userData['religion'] ?? []),
          'budget level': List<String>.from(userData['budget level'] ?? []),
          'education level': List<String>.from(userData['education level'] ?? []),
          'relationship status': List<String>.from(userData['relationship status'] ?? []),
          'smoking': List<String>.from(userData['smoking'] ?? []),
          'alcoholic': List<String>.from(userData['alcoholic'] ?? []),
          'allergies': List<String>.from(userData['allergies'] ?? []),
          'physical activity level': List<String>.from(userData['physical activity level'] ?? []),
          'transportation': List<String>.from(userData['transportation'] ?? []),
          'pet': List<String>.from(userData['pet'] ?? []),
          'personality': List<String>.from(userData['personality'] ?? []),
          'location': userData['location'],
          'lastLocationUpdate': userData['lastLocationUpdate'],
        };
        debugPrint('Updated state with location: ${state['location']}');
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }
}

final profileProvider =
    StateNotifierProvider<DatabaseServices, Map<String, dynamic>>((ref) {
  return DatabaseServices();
});
