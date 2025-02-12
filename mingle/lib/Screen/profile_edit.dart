import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For image picking
import 'dart:io';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> profile; // Accept a Map instead of a Profile object

  const ProfileEditPage({super.key, required this.profile});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  XFile? _image;
  bool isEditMode = true; // Track whether the page is in edit mode

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
    // Initialize lists with existing profile data, providing default empty lists if null
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

    // Show confirmation dialog
     // Show a SnackBar notification instead of a dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Changes applied successfully!"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      isEditMode = true; // Switch back to edit mode
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 184, 211),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              if (isEditMode) ...[
                _buildTextFieldWithAddButton("Gender", genderPreferences),
                _buildTextFieldWithAddButton("Interest", interestPreferences),
                _buildTextFieldWithAddButton("Education", educationPreferences),
                _buildTextFieldWithAddButton("Pet", petPreferences),
                _buildTextFieldWithAddButton("Exercise", exercisePreferences),
                _buildTextFieldWithAddButton("Alcoholic", alcoholPreferences),
                _buildTextFieldWithAddButton("Smoking", smokingPreferences),
              ] else ...[
                _buildProfileDisplay(),
              ],
              const SizedBox(height: 20),
              if (isEditMode)
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                  ),
                  child: const Text("Save",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Itim')),
                )
              else
                ElevatedButton(
                  onPressed: _toggleEditMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                  ),
                  child: const Text("Edit",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Itim')),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
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
              Text(widget.profile['name'], // Access name from the Map
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Itim')),
              Text("Age: ${widget.profile['age']}", // Access age from the Map
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Itim')),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Itim',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 228, 225),
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: preferences.map((preference) {
                      return Chip(
                        label: Text(
                          preference,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        deleteIconColor: Colors.black,
                        onDeleted: () {
                          setState(() {
                            preferences.remove(preference);
                          });
                        },
                      );
                    }).toList(),
                  ),
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
    );
  }

 Widget _buildProfileDisplay() {
  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 255, 228, 225), // Match background color
      borderRadius: BorderRadius.circular(8.0),
      border: Border.all(color: Colors.grey),
    ),
    child: Column(
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
    ),
  );
}

Widget _buildPreferenceDisplay(String label, List<String>? preferences) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label ",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Itim',
          ),
        ),
        if (preferences != null && preferences.isNotEmpty)
          ...preferences.map((preference) => Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  preference,
                  style: const TextStyle(fontSize: 16),
                ),
              )),
        if (preferences == null || preferences.isEmpty)
          const Text(
            "None",
            style: TextStyle(fontSize: 16),
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