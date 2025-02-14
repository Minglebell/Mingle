import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'profile_edit.dart';
import 'dart:convert'; // For JSON encoding
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:mingle/utils/logger.dart';

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

  @override
  void initState() {
    super.initState();
    setupLogger(); // Initialize the logger
    logger.info('ProfileSetupPage initialized'); // Log initialization
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _nameController.text.isNotEmpty &&
          _birthdayController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
              .hasMatch(_emailController.text) &&
          _selectedDate != null;
    });
    logger.info('Form validation status: $_isFormValid'); // Log form validation status
  }

  Future<void> _selectDate(BuildContext context) async {
    logger.info('Date picker opened'); // Log date picker opening
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
      logger.info('Selected date: ${_birthdayController.text}'); // Log selected date
    } else {
      logger.info('Date picker closed without selection'); // Log no date selected
    }
  }

  // Function to send profile data to the backend
  Future<void> sendProfileData(Map<String, dynamic> profile) async {
    final String profileJson = jsonEncode(profile);
    final Uri url = Uri.parse('https://your-backend-api.com/profile');

    try {
      logger.info('Sending profile data to the backend...'); // Log sending data
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: profileJson,
      );

      if (response.statusCode == 200) {
        logger.info('Profile data sent successfully'); // Log success
      } else {
        logger.severe('Failed to send profile data. Error: ${response.statusCode}'); // Log error
      }
    } catch (e) {
      logger.severe('Error sending profile data: $e'); // Log exception
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 228, 225),
      appBar: AppBar(
        title: const Text(
          'Setting up your profiles',
          style: TextStyle(
              fontFamily: 'Itim', fontSize: 26, fontWeight: FontWeight.bold),
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
                        style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Itim',
                            fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: TextFormField(
                          controller: _nameController,
                          onChanged: (value) {
                            _validateForm();
                            logger.info('Name updated: $value'); // Log name update
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          style:
                              const TextStyle(fontSize: 18, fontFamily: 'Itim'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Birthday',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Itim',
                            fontWeight: FontWeight.bold),
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
                          style:
                              const TextStyle(fontSize: 18, fontFamily: 'Itim'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Email',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Itim',
                            fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: TextFormField(
                          controller: _emailController,
                          onChanged: (value) {
                            _validateForm();
                            logger.info('Email updated: $value'); // Log email update
                          },
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
                              color: Colors.red,
                              fontSize: 12,
                              fontFamily: 'Itim'),
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
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isFormValid
                    ? () {
                        final name = _nameController.text;
                        final birthday = _selectedDate!;
                        final age = DateTime.now().year - birthday.year;

                        // Create a Map with the profile data
                        final profile = {
                          'name': name,
                          'age': age,
                          'email': _emailController.text,
                          'birthday': birthday.toIso8601String(),
                        };

                        logger.info('Profile data: $profile'); // Log profile data

                        // Send the profile data to the backend
                        sendProfileData(profile);

                        // Navigate to the ProfileEditPage and pass the Map
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
                  style: TextStyle(
                      color: Colors.white, fontFamily: 'Itim', fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}