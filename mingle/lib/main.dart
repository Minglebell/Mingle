import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:image_picker/image_picker.dart'; // For image picking
import 'dart:io'; 

void main() {
  runApp(
    DevicePreview(
      enabled: true, // Set to true for development purposes
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: DevicePreview.appBuilder,
      locale: DevicePreview.locale(context), // Support locale simulation
      home: const ProfileSetupPage(),
      theme: ThemeData(primarySwatch: Colors.pink, fontFamily: 'Itim'), // Recommended background color
    );
  }
}

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  DateTime? _selectedDate;

  bool _isFormValid = false;

  void _validateForm() {
    setState(() {
      _isFormValid = _nameController.text.isNotEmpty &&
          _birthdayController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(_emailController.text) &&
          _selectedDate != null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _birthdayController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        _validateForm();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 228, 225),
      appBar: AppBar(
        title: const Text(
          'Setting up your profiles',
          style: TextStyle(fontFamily: 'Itim', fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 228, 225),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Name',
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: TextFormField(
                          controller: _nameController,
                          onChanged: (value) => _validateForm(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 18, fontFamily: 'Itim'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Birthday',
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: TextFormField(
                          controller: _birthdayController,
                          onTap: () => _selectDate(context),
                          readOnly: true,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectDate(context),
                            ),
                          ),
                          style: const TextStyle(fontSize: 18, fontFamily: 'Itim'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Email',
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
                      ),
                      Padding(padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child:
                          TextFormField(
                          controller: _emailController,
                          onChanged: (value) => _validateForm(),
                          decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontFamily: 'Itim'),
                      ),
                      ),  
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Warning: This cannot be changed',
                          style: TextStyle(
                              color: Colors.red, fontSize: 12, fontFamily: 'Itim'),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isFormValid
                    ? () {
                        final name = _nameController.text;
                        final birthday = _selectedDate!;
                        final age = DateTime.now().year - birthday.year;

                        final profile = Profile(name: name, age: age);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileEditPage(profile: profile),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: const Text(
                  'Confirm',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white, fontFamily: 'Itim', fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class ProfileEditPage extends StatefulWidget {
  final Profile profile;

  const ProfileEditPage({super.key, required this.profile});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  XFile? _image;

  List<String> genderPreferences = [];
  List<String> interestPreferences = [];
  List<String> educationPreferences = [];
  List<String> petPreferences = [];
  List<String> exercisePreferences = [];
  List<String> alcoholPreferences = [];
  List<String> smokingPreferences = [];

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
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: const Text("Save",
                    style: TextStyle(
                        color: Colors.white, fontSize: 18, fontFamily: 'Itim')),
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
              Text(widget.profile.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Itim')),
              Text("Age: ${widget.profile.age}",
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
                      onDeleted: () {
                        setState(() {
                          preferences.remove(preference);
                        });
                      },
                    );
                  }).toList(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _showAddPreferenceDialog(label);
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

class Profile {
  final String name;
  final int age;
  Profile({required this.name, required this.age});
}


class MatchingPage extends StatelessWidget {
  const MatchingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matching Interests'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Back'),
        ),
      ),
    );
  }
}

