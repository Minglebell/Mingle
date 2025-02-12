import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For image picking
import 'dart:io';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileEditPage({super.key, required this.profile});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  XFile? _image;
  bool isEditing = true;

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
    genderPreferences = List<String>.from(widget.profile['gender'] ?? []);
    interestPreferences = List<String>.from(widget.profile['interest'] ?? []);
    educationPreferences = List<String>.from(widget.profile['education'] ?? []);
    petPreferences = List<String>.from(widget.profile['pet'] ?? []);
    exercisePreferences = List<String>.from(widget.profile['exercise'] ?? []);
    alcoholPreferences = List<String>.from(widget.profile['alcoholic'] ?? []);
    smokingPreferences = List<String>.from(widget.profile['smoking'] ?? []);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _image = pickedImage;
      });
    }
  }

  void _saveProfile() {
    setState(() {
      isEditing = false;
      widget.profile['gender'] = genderPreferences;
      widget.profile['interest'] = interestPreferences;
      widget.profile['education'] = educationPreferences;
      widget.profile['pet'] = petPreferences;
      widget.profile['exercise'] = exercisePreferences;
      widget.profile['alcoholic'] = alcoholPreferences;
      widget.profile['smoking'] = smokingPreferences;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 228, 225),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildTextFieldWithAddButton("Gender", genderPreferences),
              _buildTextFieldWithAddButton("Interest", interestPreferences),
              _buildTextFieldWithAddButton("Education", educationPreferences),
              _buildTextFieldWithAddButton("Pet", petPreferences),
              _buildTextFieldWithAddButton("Exercise", exercisePreferences),
              _buildTextFieldWithAddButton("Alcoholic", alcoholPreferences),
              _buildTextFieldWithAddButton("Smoking", smokingPreferences),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isEditing) {
                    _saveProfile();
                  } else {
                    setState(() {
                      isEditing = true;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  isEditing ? "Save" : "Edit",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Itim'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              backgroundImage: _image != null
                  ? FileImage(File(_image!.path)) as ImageProvider
                  : null,
            ),
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
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.profile['name'],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Itim')),
              Text("Age: ${widget.profile['age']}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.normal, fontFamily: 'Itim')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldWithAddButton(String label, List<String> preferences) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Container(
            decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: preferences.map((preference) {
                    return Chip(
                      label: Text(preference),
                      onDeleted: isEditing
                          ? () {
                              setState(() {
                                preferences.remove(preference);
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
                if (isEditing)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _showAddPreferenceDialog(label, preferences);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPreferenceDialog(String label, List<String> preferences) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  setState(() {
                    preferences.add(_controller.text);
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

