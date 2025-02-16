import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For image picking
import 'dart:io';
import 'dart:convert'; // For JSON encoding
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:mingle/utils/logger.dart';
import 'package:mingle/Widget/bottom_navigation_bar.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileEditPage({super.key, required this.profile});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  XFile? _image;
  bool isEditMode = true;

  List<String> genderPreferences = [];
  List<String> interestPreferences = [];
  List<String> educationPreferences = [];
  List<String> petPreferences = [];
  List<String> exercisePreferences = [];
  List<String> alcoholPreferences = [];
  List<String> smokingPreferences = [];

  @override
  void initState() {
    super.initState();
    setupLogger(); // Initialize the logger
    logger.info('ProfileEditPage initialized'); // Log initialization
    _loadProfileData();

    // Initialize lists with existing profile data
    genderPreferences = List<String>.from(widget.profile['gender'] ?? []);
    interestPreferences = List<String>.from(widget.profile['interest'] ?? []);
    educationPreferences = List<String>.from(widget.profile['education'] ?? []);
    petPreferences = List<String>.from(widget.profile['pet'] ?? []);
    exercisePreferences = List<String>.from(widget.profile['exercise'] ?? []);
    alcoholPreferences = List<String>.from(widget.profile['alcoholic'] ?? []);
    smokingPreferences = List<String>.from(widget.profile['smoking'] ?? []);
  }

  Future<void> _loadProfileData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      
      genderPreferences = prefs.getStringList('gender') ?? [];
      interestPreferences = prefs.getStringList('interest') ?? [];
      educationPreferences = prefs.getStringList('education') ?? [];
      petPreferences = prefs.getStringList('pet') ?? [];
      exercisePreferences = prefs.getStringList('exercise') ?? [];
      alcoholPreferences = prefs.getStringList('alcoholic') ?? [];
      smokingPreferences = prefs.getStringList('smoking') ?? [];
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
      logger.info('Profile image updated'); // Log image update
    }
  }

  Future<void> sendProfileData(Map<String, dynamic> profile) async {
    final String profileJson = jsonEncode(profile);
    final Uri url = Uri.parse('empty... w8 for import');

    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: profileJson,
      );

      if (response.statusCode == 200) {
        logger.info('Profile data updated successfully'); // Log success
      } else {
        logger.severe(
            'Failed to update profile data. Error: ${response.statusCode}'); // Log error
      }
    } catch (e) {
      logger.severe('Error updating profile data: $e'); // Log exception
    }
  }

  void _saveProfile() {
    // Update the profile information
    setState(() {
      widget.profile['gender'] = genderPreferences;
      widget.profile['interest'] = interestPreferences;
      widget.profile['education'] = educationPreferences;
      widget.profile['pet'] = petPreferences;
      widget.profile['exercise'] = exercisePreferences;
      widget.profile['alcoholic'] = alcoholPreferences;
      widget.profile['smoking'] = smokingPreferences;
      isEditMode = false;
    });

    // Save the updated profile data to local storage
    _saveProfileDataToLocalStorage(widget.profile);

    // Send the updated profile data to the backend
    sendProfileData(widget.profile);

    // Show confirmation dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Changes applied successfully!"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );

    logger.info('Profile changes saved'); // Log profile save
  }

  void _toggleEditMode() {
    setState(() {
      isEditMode = true;
    });
    logger.info('Edit mode toggled');
  }

  Future<void> _saveProfileDataToLocalStorage(
      Map<String, dynamic> profile) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', profile['name']);
    await prefs.setInt('age', profile['age']);
    await prefs.setString('email', profile['email']);
    await prefs.setString('birthday', profile['birthday']);
    await prefs.setStringList('gender', profile['gender'].cast<String>());
    await prefs.setStringList('interest', profile['interest'].cast<String>());
    await prefs.setStringList('education', profile['education'].cast<String>());
    await prefs.setStringList('pet', profile['pet'].cast<String>());
    await prefs.setStringList('exercise', profile['exercise'].cast<String>());
    await prefs.setStringList('alcoholic', profile['alcoholic'].cast<String>());
    await prefs.setStringList('smoking', profile['smoking'].cast<String>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 20),
                    if (isEditMode) ...[
                      _buildTextFieldWithAddButton("Gender", genderPreferences),
                      _buildTextFieldWithAddButton(
                          "Interest", interestPreferences),
                      _buildTextFieldWithAddButton(
                          "Education", educationPreferences),
                      _buildTextFieldWithAddButton("Pet", petPreferences),
                      _buildTextFieldWithAddButton(
                          "Exercise", exercisePreferences),
                      _buildTextFieldWithAddButton(
                          "Alcoholic", alcoholPreferences),
                      _buildTextFieldWithAddButton(
                          "Smoking", smokingPreferences),
                    ] else ...[
                      _buildProfileDisplay(),
                    ],
                    const SizedBox(height: 20),
                    if (isEditMode)
                      ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6C9BCF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                        ),
                        child: const Text("Save",
                            style: TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 18,
                                fontFamily: 'Itim')),
                      )
                    else
                      ElevatedButton(
                        onPressed: _toggleEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6C9BCF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                        ),
                        child: const Text("Edit",
                            style: TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 18,
                                fontFamily: 'Itim')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 80, // Increased size
                backgroundColor: Color(0xFFA8D1F0),
                backgroundImage: _image != null
                    ? FileImage(File(_image!.path)) as ImageProvider
                    : null,
              ),
              if (isEditMode) // Only show the edit button in edit mode
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.add_a_photo, color: Colors.black),
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
                        fontSize: 26, // Increased size
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Itim',
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.profile['name'],
                        style: const TextStyle(
                          fontSize: 24, // Increased size
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Itim',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Age",
                      style: TextStyle(
                        fontSize: 26, // Increased size
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Itim',
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.profile['age'].toString(),
                        style: const TextStyle(
                          fontSize: 24, // Increased size
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Itim',
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithAddButton(String label, List<String> preferences) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Itim',
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF6C9BCF), // Chip background color
              border: Border.all(
                  color: Colors.grey), // Add a border for better visibility
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8), // Adjust padding
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8.0, // Adjust spacing between chips
                        runSpacing: 8.0, // Adjust spacing between lines
                        alignment: WrapAlignment.start, // Left-align the chips
                        children: preferences.map((preference) {
                          return Chip(
                            label: Text(
                              preference,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                            backgroundColor:
                                Color(0xFFA8D1F0), // Chip background color
                            deleteIconColor: Colors.black, // Delete icon color
                            onDeleted: () {
                              setState(() {
                                preferences.remove(preference);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.black),
                      onPressed: () {
                        _showAddPreferenceDialog(label);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreferenceDisplay("Gender", widget.profile['gender']),
        _buildPreferenceDisplay("Interest", widget.profile['interest']),
        _buildPreferenceDisplay("Education", widget.profile['education']),
        _buildPreferenceDisplay("Pet", widget.profile['pet']),
        _buildPreferenceDisplay("Exercise", widget.profile['exercise']),
        _buildPreferenceDisplay("Alcoholic", widget.profile['alcoholic']),
        _buildPreferenceDisplay("Smoking", widget.profile['smoking']),
      ],
    );
  }

  Widget _buildPreferenceDisplay(String label, List<String>? preferences) {
    if (preferences == null || preferences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Ensure alignment
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Itim',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 15.0,
              runSpacing: 15.0,
              children: (preferences).map((preference) {
                return Chip(
                  label: Text(
                    preference,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.black,
                    ),
                  ),
                  backgroundColor: Color(0xFFA8D1F0),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPreferenceDialog(String label) {
    TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Add $label"),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: "Enter $label"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  setState(() {
                    if (label == "Gender") {
                      genderPreferences.add(_controller.text);
                    } else if (label == "Interest") {
                      interestPreferences.add(_controller.text);
                    } else if (label == "Education") {
                      educationPreferences.add(_controller.text);
                    } else if (label == "Pet") {
                      petPreferences.add(_controller.text);
                    } else if (label == "Exercise") {
                      exercisePreferences.add(_controller.text);
                    } else if (label == "Alcoholic") {
                      alcoholPreferences.add(_controller.text);
                    } else if (label == "Smoking") {
                      smokingPreferences.add(_controller.text);
                    }
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
}
