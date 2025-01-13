import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:intl/intl.dart'; // For date formatting

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
      theme: ThemeData(primarySwatch: Colors.blue),
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
          _emailController.text.isNotEmpty;
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
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        _validateForm();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Setting up your profiles',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                TextFormField(
                  controller: _nameController,
                  onChanged: (value) => _validateForm(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Roboto'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Birthday',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                TextFormField(
                  controller: _birthdayController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  style: const TextStyle(fontFamily: 'Roboto'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Email',
                  textAlign: TextAlign.left,
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                TextFormField(
                  controller: _emailController,
                  onChanged: (value) => _validateForm(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Roboto'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Warning: This cannot be changed',
                    style: TextStyle(
                        color: Colors.red, fontSize: 12, fontFamily: 'Roboto'),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
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
                                    ProfileDetailsPage(profile: profile),
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
                          TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Profile {
  final String name;
  final int age;

  Profile({required this.name, required this.age});
}


class ProfileDetailsPage extends StatelessWidget {
  final Profile profile;

  const ProfileDetailsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${profile.name}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Age: ${profile.age}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
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
