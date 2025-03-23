import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DatabaseServices extends StateNotifier<Map<String, dynamic>> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  DatabaseServices()
    : super({
        'name': '',
        'age': '',
        'gender': <String>[],
        'allergies': <String>[],
        'interests': <String>[],
        'preferences': <String>[],
        'favourite activities': <String>[],
        'alcoholic': <String>[],
        'smoking': <String>[],
      }) {
    fetchProfile(); // Fetch profile data when the notifier is created
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
      throw e; // Rethrow to handle in the UI
    }
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phoneNumber');

      if (phoneNumber == null) {
        debugPrint('Phone number not found in SharedPreferences');
        return;
      }

      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(phoneNumber);

      final profileDoc = await profileRef.get();

      if (profileDoc.exists) {
        final data = profileDoc.data()!;
        final birthday =
            data['birthday'] != null
                ? DateFormat('M/d/yyyy').parse(data['birthday'])
                : null;
        final age = birthday != null ? DateTime.now().year - birthday.year : '';

        state = {
          'name': data['name'] ?? '',
          'age': age,
          'gender': List<String>.from(
            data['gender'] ?? <String>[],
          ), // Ensure 'gender' is fetched
          'allergies': List<String>.from(data['allergies'] ?? <String>[]),
          'interests': List<String>.from(data['interests'] ?? <String>[]),
          'preferences': List<String>.from(data['preferences'] ?? <String>[]),
          'favourite activities': List<String>.from(
            data['favourite activities'] ?? <String>[],
          ),
          'alcoholic': List<String>.from(data['alcoholic'] ?? <String>[]),
          'smoking': List<String>.from(data['smoking'] ?? <String>[]),
        };

        debugPrint('Profile data fetched successfully: $state');
      } else {
        debugPrint(
          'Firestore document does not exist for phoneNumber: $phoneNumber',
        );
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

  void addPreference(String category, String preference) {
    switch (category) {
      case 'gender':
        if ((state[category] as List<String>).isEmpty) {
          state = {
            ...state,
            category: [preference],
          };
        }
        break;
      case 'interests':
      case 'preferences':
      case 'favourite activities':
        if ((state[category] as List<String>).length < 5) {
          state = {
            ...state,
            category: [...state[category] as List<String>, preference],
          };
        }
        break;
      case 'alcoholic':
      case 'smoking':
        state = {
          ...state,
          category: [preference],
        };
        break;
    }
  }

  void removePreference(String category, String preference) {
    if (state[category] is List<String>) {
      state = {
        ...state,
        category:
            (state[category] as List<String>)
                .where((item) => item != preference)
                .toList(),
      };
    }
  }

  Future<void> saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phoneNumber');

      if (phoneNumber == null) {
        debugPrint('Phone number not found in SharedPreferences');
        return;
      }

      // Save to Firestore
      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(phoneNumber);

      await profileRef.set({
        'name': state['name'],
        'age': state['age'],
        'gender': state['gender'],
        'allergies': state['allergies'],
        'interests': state['interests'],
        'preferences': state['preferences'],
        'favourite activities': state['favourite activities'],
        'alcoholic': state['alcoholic'],
        'smoking': state['smoking'],
      }, SetOptions(merge: true)); // Merge to avoid overwriting other fields

      // Save to SharedPreferences
      prefs.setString('name', state['name']);
      prefs.setInt('age', state['age']);
      prefs.setStringList(
        'gender',
        List<String>.from(state['gender'] ?? <String>[]),
      );
      prefs.setStringList(
        'allergies',
        List<String>.from(state['allergies'] ?? <String>[]),
      );
      prefs.setStringList(
        'interests',
        List<String>.from(state['interests'] ?? <String>[]),
      );
      prefs.setStringList(
        'preferences',
        List<String>.from(state['preferences'] ?? <String>[]),
      );
      prefs.setStringList(
        'favourite activities',
        List<String>.from(state['favourite activities'] ?? <String>[]),
      );
      prefs.setStringList(
        'alcoholic',
        List<String>.from(state['alcoholic'] ?? <String>[]),
      );
      prefs.setStringList(
        'smoking',
        List<String>.from(state['smoking'] ?? <String>[]),
      );

      debugPrint('Profile saved successfully: $state');
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }
}

// Riverpod Provider
final profileProvider =
    StateNotifierProvider<DatabaseServices, Map<String, dynamic>>((ref) {
      return DatabaseServices();
    });
