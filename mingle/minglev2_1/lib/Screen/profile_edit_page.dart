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

    final List<String> preferenceSections = [
      "Gender",
      "Religion",
      "Budget level",
      "Education level",
      "Relationship Status",
      "Smoking",
      "Alcoholic",
      "Allergies",
      "Physical Activity level",
      "Transportation",
      "Pet",
      "Personality",
    ];

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
              ...preferenceSections.map((section) {
                return Column(
                  children: [
                    _buildPreferenceSection(
                      section,
                      (profile[section.toLowerCase()] as List<String>?) ?? [],
                      profileNotifier,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),

              // Save Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C9BCF), Color(0xFF4A90E2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C9BCF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    profileNotifier.saveProfile();
                    DelightToastBar(
                      autoDismiss: true,
                      snackbarDuration: const Duration(seconds: 3),
                      builder: (context) => const ToastCard(
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
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Column(
      children: [
        Container(
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
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bio",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: profile['bio'] as String? ?? '',
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: "Write something about yourself...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6C9BCF), width: 2),
                  ),
                ),
                onChanged: (value) {
                  ref.read(profileProvider.notifier).updateBio(value);
                },
              ),
            ],
          ),
        ),
      ],
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
      'Gender': [
        'Male',
        'Female',
        'Non-binary',
        'Transgender',
        'LGBTQ+',
        'Other'
      ],
      'Religion': [
        'Non religiou',
        'Buddhist',
        'Christian',
        'Muslim',
        'Hindu',
        'Agnostic',
        'Atheist',
        'Other'
      ],
      'Budget level': [
        'Low (0-300)',
        'Moderate (300-1000)',
        'High (1000-5000)',
        'Luxury (5000+)'
      ],
      'Education level': [
        'High school or lower',
        'Bachelor\'s degree',
        'Master\'s degree',
        'Doctorate or higher'
      ],
      'Relationship Status': [
        'Single',
        'Unclear relationship',
        'In a relationship',
        'Married',
        'Other'
      ],
      'Smoking': [
        'Non-smoker',
        'Occasional smoker',
        'Only smoke when drinking',
        'Regular smoker'
      ],
      'Alcoholic': [
        'Never',
        'Rarely',
        'Occasionally',
        'Regularly'
      ],
      'Allergies': [
        'None',
        'Milk',
        'Egg',
        'Wheat',
        'Nut',
        'Shellfish',
        'Pollen',
        'Dust',
        'Animal dander',
        'Other'
      ],
      'Physical Activity level': [
        'Low',
        'Moderate',
        'High'
      ],
      'Transportation': [
        'Own vehicle',
        'Public transport',
        'Ride-sharing',
        'Walking',
        'Other'
      ],
      'Pet': [
        'Dog',
        'Cat',
        'Fish',
        'Hamster',
        'Rabbit',
        'Bird',
        'Turtle',
        'Other'
      ],
      'Personality': [
        'Introverted',
        'Extroverted',
        'Ambivert',
        'Other'
      ]
    };

    String? selectedValue;
    final currentPreferences = ref.read(profileProvider)[label.toLowerCase()] as List<dynamic>? ?? [];

    // Check if already at max limit for Allergies and Pets
    if (['Allergies', 'Pet', 'Transportation'].contains(label) && currentPreferences.length >= 4) {
      DelightToastBar(
        autoDismiss: true,
        snackbarDuration: const Duration(seconds: 3),
        builder: (context) => ToastCard(
          leading: const Icon(
            Icons.warning,
            size: 24,
            color: Colors.orange,
          ),
          title: Text(
            'Maximum 4 ${label.toLowerCase()} can be selected',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ).show(context);
      return;
    }

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
              final List<String> availableOptions = options[label] ?? [];
              if (availableOptions.isEmpty) {
                return const Text(
                  "No options available for this category",
                  style: TextStyle(fontSize: 18),
                );
              }
              
              return Container(
                width: double.maxFinite,
                height: 200, // Fixed height for scrollable content
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: availableOptions.map((String value) {
                      final bool isSelected = selectedValue == value;
                      return FilterChip(
                        label: Text(
                          value,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            selectedValue = selected ? value : null;
                          });
                        },
                        selectedColor: const Color(0xFF6C9BCF),
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF6C9BCF) : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
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
                      content: Text("Please select an option"),
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
