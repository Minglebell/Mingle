import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';

import '../Widget/bottom_navigation_bar.dart';

// Riverpod StateNotifier for managing profile state
class ProfileNotifier extends StateNotifier<Map<String, dynamic>> {
  ProfileNotifier()
    : super({
        'name': '',
        'age': '',
        'gender': <String>[],
        'favourite food': <String>[],
        'allergies': <String>[],
      }) {
    _fetchProfile(); // Fetch profile data when the notifier is created
  }

  Future<void> _fetchProfile() async {
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

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  XFile? _image;
  bool isEditMode = true;
  bool showBottomNavBar = true; // Controls visibility of the bottom nav bar
  int currentPageIndex = 2;

  @override
  void initState() {
    super.initState();
    // Fetch profile data when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier)._fetchProfile();
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      bottomNavigationBar:
          showBottomNavBar
              ? CustomBottomNavBar(
                currentIndex: currentPageIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    currentPageIndex = index;
                  });
                  // Navigate to other pages based on the index
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MatchMenuPage()),
                    );
                  } else if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => ChatListPage()),
                    );
                  } else if (index == 2) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileEditPage(),
                      ),
                    );
                  }
                },
              )
              : null, // Hide the bottom nav bar
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileHeader(profile),
                    const SizedBox(height: 20),
                    if (isEditMode) ...[
                      _buildPreferenceSection(
                        "Gender",
                        profile['gender'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Favourite food",
                        profile['favourite food'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Allergies",
                        profile['allergies'] as List<String>,
                        profileNotifier,
                      ),
                    ] else ...[
                      _buildProfileDisplay(profile),
                    ],
                    const SizedBox(height: 20),

                    // Save/Edit Button
                    ElevatedButton(
                      onPressed: () {
                        if (isEditMode) {
                          profileNotifier.saveProfile();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Changes applied successfully!"),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        setState(() {
                          isEditMode = !isEditMode;
                          showBottomNavBar = !isEditMode;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C9BCF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                      ),
                      child: Text(
                        isEditMode ? "Save" : "Edit",
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // รูป + ชื่อ + อายุ
  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 80,
                backgroundColor: const Color(0xFF6C9BCF),
                backgroundImage:
                    _image != null ? FileImage(File(_image!.path)) : null,
              ),
              if (isEditMode)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.add_a_photo,
                      color: Colors.black,
                      size: 30,
                    ),
                    onPressed: _pickImage,
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFA8D1F0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Name",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Center(
                      child: Text(
                        profile['name'],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Age",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Center(
                      child: Text(
                        profile['age'].toString(),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // อันนี้คือ กล่องใส่ Preferences หลายแหล่
  Widget _buildPreferenceSection(
    String label,
    List<String> preferences,
    ProfileNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF6C9BCF),
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children:
                        preferences.map((preference) {
                          return Chip(
                            label: Text(
                              preference,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF333333),
                              ),
                            ),
                            backgroundColor: const Color(0xFFA8D1F0),
                            deleteIconColor: const Color(0xFF333333),
                            onDeleted:
                                () => notifier.removePreference(
                                  label.toLowerCase(),
                                  preference,
                                ),
                          );
                        }).toList(),
                  ),
                ),
                if (preferences.length < 3)
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF333333)),
                    onPressed: () => _showAddPreferenceDialog(label, notifier),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // กล่อง Display Preferences หน้า Profile
  Widget _buildProfileDisplay(Map<String, dynamic> profile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreferenceDisplay("Gender", profile['gender']),
          _buildPreferenceDisplay("Favourite food", profile['favourite food']),
          _buildPreferenceDisplay("Allergies", profile['allergies']),
        ],
      ),
    );
  }

  Widget _buildPreferenceDisplay(String label, List<String> preferences) {
    if (preferences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 15.0,
            runSpacing: 15.0,
            crossAxisAlignment: WrapCrossAlignment.start,
            children:
                preferences.map((preference) {
                  return Chip(
                    label: Text(
                      preference,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF333333),
                      ),
                    ),
                    backgroundColor: const Color(0xFF6C9BCF),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAddPreferenceDialog(String label, ProfileNotifier notifier) {
    final Map<String, List<String>> options = {
      'Gender': ['Male', 'Female', 'Other'],
      'Favourite food': [
        'Thai food',
        'Japanese Food',
        'Korean food',
        'Italian food',
      ],
      'Allergies': [
        'Peanuts',
        'Eggs',
        'Fish',
        'Shellfish',
        'Tree nuts',
        'None',
      ],
    };

    String? selectedValue;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select $label"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                value: selectedValue,
                items:
                    options[label]!.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedValue = value;
                  });
                },
                decoration: const InputDecoration(hintText: "Choose an option"),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (selectedValue != null) {
                  final currentPreferences =
                      ref.read(profileProvider)[label.toLowerCase()]
                          as List<String>;
                  if (label == 'Allergies' &&
                      currentPreferences.contains('None')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Cannot add more allergies when 'None' is selected.",
                        ),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if ((label == 'Favourite food' ||
                          label == 'Allergies') &&
                      currentPreferences.length >= 5) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Maximum number of selections reached."),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    notifier.addPreference(label.toLowerCase(), selectedValue!);
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please select an option."),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }
}
