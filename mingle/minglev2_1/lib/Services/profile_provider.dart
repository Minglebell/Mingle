import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ProfileNotifier extends StateNotifier<Map<String, dynamic>> {
  ProfileNotifier()
    : super({
        'name': '',
        'age': '',
        'gender': <String>[],
        'favourite food': <String>[],
        'allergies': <String>[],
      }) {
    fetchProfile(); // Fetch profile data when the notifier is created
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
          'gender': List<String>.from(data['gender'] ?? <String>[]),
          'favourite food': List<String>.from(
            data['favourite food'] ?? <String>[],
          ),
          'allergies': List<String>.from(data['allergies'] ?? <String>[]),
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
        state = {
          ...state,
          category: [preference],
        };
        break;
      case 'favourite food':
        if ((state[category] as List<String>).length < 3) {
          state = {
            ...state,
            category: [...state[category] as List<String>, preference],
          };
        }
        break;
      case 'allergies':
        if (preference == 'None') {
          state = {
            ...state,
            category: ['None'],
          };
        } else if (!(state[category] as List<String>).contains('None') &&
            (state[category] as List<String>).length < 5) {
          state = {
            ...state,
            category: [...state[category] as List<String>, preference],
          };
        }
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
        'favourite food': state['favourite food'],
        'allergies': state['allergies'],
      }, SetOptions(merge: true)); // Merge to avoid overwriting other fields

      // Save to SharedPreferences
      prefs.setString('name', state['name']);
      prefs.setInt('age', state['age']);
      prefs.setStringList(
        'gender',
        List<String>.from(state['gender'] ?? <String>[]),
      );
      prefs.setStringList(
        'favourite food',
        List<String>.from(state['favourite food'] ?? <String>[]),
      );
      prefs.setStringList(
        'allergies',
        List<String>.from(state['allergies'] ?? <String>[]),
      );

      debugPrint('Profile saved successfully: $state');
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }
}

// Riverpod Provider
final profileProvider =
    StateNotifierProvider<ProfileNotifier, Map<String, dynamic>>((ref) {
      return ProfileNotifier();
    });
