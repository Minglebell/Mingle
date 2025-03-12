import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// Riverpod StateNotifier for managing profile state
class ProfileNotifier extends StateNotifier<Map<String, dynamic>> {
  ProfileNotifier()
    : super({
        'name': 'Matt',
        'age': 22,
        'gender': <String>[],
        'interest': <String>[],
        'education': <String>[],
        'pet': <String>[],
        'exercise': <String>[],
        'alcoholic': <String>[],
        'smoking': <String>[],
      });

  void updateName(String name) {
    state = {...state, 'name': name};
  }

  void updateAge(int age) {
    state = {...state, 'age': age};
  }

  void addPreference(String category, String preference) {
    if (category == 'gender' ||
        category == 'education' ||
        category == 'exercise' ||
        category == 'alcoholic' ||
        category == 'smoking') {
      // Only one selection allowed for these categories
      state = {
        ...state,
        category: [preference],
      };
    } else if (category == 'interest') {
      // Allow up to 5 selections for interests
      if (state[category] is List<String> &&
          (state[category] as List<String>).length < 5) {
        state = {
          ...state,
          category: [...state[category] as List<String>, preference],
        };
      }
    } else if (category == 'pet') {
      // Allow up to 5 selections for pets, but if "None" is selected, no other options are allowed
      if (preference == 'None') {
        state = {
          ...state,
          category: ['None'],
        };
      } else if (state[category] is List<String> &&
          !(state[category] as List<String>).contains('None') &&
          (state[category] as List<String>).length < 5) {
        state = {
          ...state,
          category: [...state[category] as List<String>, preference],
        };
      }
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

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      'name': prefs.getString('name') ?? 'Matt',
      'age': prefs.getInt('age') ?? 22,
      'gender': prefs.getStringList('gender') ?? <String>[],
      'interest': prefs.getStringList('interest') ?? <String>[],
      'education': prefs.getStringList('education') ?? <String>[],
      'pet': prefs.getStringList('pet') ?? <String>[],
      'exercise': prefs.getStringList('exercise') ?? <String>[],
      'alcoholic': prefs.getStringList('alcoholic') ?? <String>[],
      'smoking': prefs.getStringList('smoking') ?? <String>[],
    };
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('name', state['name']);
    prefs.setInt('age', state['age']);
    prefs.setStringList(
      'gender',
      List<String>.from(state['gender'] ?? <String>[]),
    );
    prefs.setStringList(
      'interest',
      List<String>.from(state['interest'] ?? <String>[]),
    );
    prefs.setStringList(
      'education',
      List<String>.from(state['education'] ?? <String>[]),
    );
    prefs.setStringList('pet', List<String>.from(state['pet'] ?? <String>[]));
    prefs.setStringList(
      'exercise',
      List<String>.from(state['exercise'] ?? <String>[]),
    );
    prefs.setStringList(
      'alcoholic',
      List<String>.from(state['alcoholic'] ?? <String>[]),
    );
    prefs.setStringList(
      'smoking',
      List<String>.from(state['smoking'] ?? <String>[]),
    );
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
                        "Interest",
                        profile['interest'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Education",
                        profile['education'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Pet",
                        profile['pet'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Exercise",
                        profile['exercise'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Alcoholic",
                        profile['alcoholic'] as List<String>,
                        profileNotifier,
                      ),
                      _buildPreferenceSection(
                        "Smoking",
                        profile['smoking'] as List<String>,
                        profileNotifier,
                      ),
                    ] else ...[
                      _buildProfileDisplay(profile),
                    ],
                    const SizedBox(height: 20),

                    // ปุ่ม Save / Edit
                    if (isEditMode)
                      ElevatedButton(
                        onPressed: () {
                          profileNotifier.saveProfile();
                          setState(() {
                            isEditMode = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Changes applied successfully!"),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C9BCF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isEditMode = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C9BCF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                        ),
                        child: const Text(
                          "Edit",
                          style: TextStyle(
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
                Wrap(
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
                          deleteIconColor: Color(0xFF333333),
                          onDeleted:
                              () => notifier.removePreference(
                                label.toLowerCase(),
                                preference,
                              ),
                        );
                      }).toList(),
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
          _buildPreferenceDisplay("Interest", profile['interest']),
          _buildPreferenceDisplay("Education", profile['education']),
          _buildPreferenceDisplay("Pet", profile['pet']),
          _buildPreferenceDisplay("Exercise", profile['exercise']),
          _buildPreferenceDisplay("Alcoholic", profile['alcoholic']),
          _buildPreferenceDisplay("Smoking", profile['smoking']),
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
      'Interest': ['Sports', 'Music', 'Reading', 'Travel', 'Game', 'Eating'],
      'Education': ['High School', 'Bachelor', 'Master', 'PhD'],
      'Pet': ['Dog', 'Cat', 'Bird', 'Rabbit', 'Fish', 'None'],
      'Exercise': ['Frequently', 'Occasionally', 'Rarely', 'Never'],
      'Alcoholic': ['Frequently', 'Occasionally', 'Rarely', 'Never'],
      'Smoking': ['Frequently', 'Occasionally', 'Rarely', 'Never'],
    };

    String? selectedValue; // This variable needs to update dynamically

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
                    selectedValue = value; // Updates when user selects
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
                  if (label == 'Pet' && currentPreferences.contains('None')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Cannot add more pets when 'None' is selected.",
                        ),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if ((label == 'Interest' || label == 'Pet') &&
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

