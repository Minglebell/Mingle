import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:minglev2_1/Services/database_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:minglev2_1/Services/navigation_services.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  XFile? _image;
  bool showBottomNavBar = true; // Controls visibility of the bottom nav bar
  int currentPageIndex = 2;

  @override
  void initState() {
    super.initState();
    // Fetch profile data when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).fetchProfile();
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', pickedImage.path);
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
                  if (index == 0) {
                    NavigationService().navigateToReplacement('/match');
                  } else if (index == 1) {
                    NavigationService().navigateToReplacement('/chatList');
                  } else if (index == 2) {
                    NavigationService().navigateToReplacement('/profile');
                  }
                },
              )
              : null, // Hide the bottom nav bar
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header
              _buildProfileHeader(profile),
              const SizedBox(height: 20),

              // Preference Sections
              _buildPreferenceSection(
                "Gender",
                profile['gender'] as List<String>,
                profileNotifier,
              ),
              const SizedBox(height: 16),
              _buildPreferenceSection(
                "Interests",
                profile['interests'] as List<String>,
                profileNotifier,
              ),
              const SizedBox(height: 16),
              _buildPreferenceSection(
                "Preferences",
                profile['preferences'] as List<String>,
                profileNotifier,
              ),
              const SizedBox(height: 16),
              _buildPreferenceSection(
                "Favourite Activities",
                profile['favourite activities'] as List<String>,
                profileNotifier,
              ),
              const SizedBox(height: 16),
              _buildPreferenceSection(
                "Alcoholic",
                profile['alcoholic'] as List<String>,
                profileNotifier,
              ),
              const SizedBox(height: 16),
              _buildPreferenceSection(
                "Smoking",
                profile['smoking'] as List<String>,
                profileNotifier,
              ),
              const SizedBox(height: 20),

              // Save Button
              ElevatedButton(
                onPressed: () {
                  profileNotifier.saveProfile();
                  DelightToastBar(
                    autoDismiss: true,
                    snackbarDuration: Duration(seconds: 3),
                    builder:
                        (context) => const ToastCard(
                          leading: Icon(
                            Icons.check_circle,
                            size: 24,
                            color: Colors.lightGreen,
                          ),
                          title: Text(
                            'Profile saved successfully',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                  ).show(context);
                  NavigationService().navigateToReplacement('/profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C9BCF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Save",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF6C9BCF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                backgroundImage:
                    _image != null ? FileImage(File(_image!.path)) : null,
                child:
                    _image == null
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
              ),
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
          const SizedBox(height: 16),
          Text(
            profile['name'],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Age: ${profile['age']}",
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSection(
    String label,
    List<String> preferences,
    DatabaseServices databaseServices,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
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
                      backgroundColor: const Color(0xFFA8D1F0),
                      deleteIconColor: const Color(0xFF333333),
                      onDeleted:
                          () => databaseServices.removePreference(
                            label.toLowerCase(),
                            preference,
                          ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed:
                  () => _showAddPreferenceDialog(label, databaseServices),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C9BCF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Add",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPreferenceDialog(String label, DatabaseServices notifier) {
    final Map<String, List<String>> options = {
      'Gender': ['Male', 'Female', 'Non-Binary'],
      'Interests': ['Hiking', 'Reading', 'Cooking', 'Traveling', 'Gaming'],
      'Preferences': ['Outdoor', 'Indoor', 'Adventurous', 'Relaxing'],
      'Favourite Activities': ['Swimming', 'Cycling', 'Yoga', 'Dancing'],
      'Alcoholic': ['Yes', 'No', 'Occasionally'],
      'Smoking': ['Yes', 'No', 'Occasionally'],
    };

    String? selectedValue;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Select $label",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                value: selectedValue,
                items:
                    options[label]!.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedValue = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Choose an option",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                if (selectedValue != null) {
                  notifier.addPreference(label.toLowerCase(), selectedValue!);
                  Navigator.of(context).pop();
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
              child: const Text(
                "Add",
                style: TextStyle(fontSize: 18, color: Color(0xFF6C9BCF)),
              ),
            ),
          ],
        );
      },
    );
  }
}
