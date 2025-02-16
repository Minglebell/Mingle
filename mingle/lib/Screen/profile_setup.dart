import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'profile.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mingle/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    setupLogger();
    _clearProfileData();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Validates the form and updates the `_isFormValid` state.
  void _validateForm() {
    setState(() {
      _isFormValid = _nameController.text.isNotEmpty &&
          _birthdayController.text.isNotEmpty &&
          _emailController.text.isNotEmpty &&
          RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
              .hasMatch(_emailController.text) &&
          _selectedDate != null;
    });
  }

  /// Opens a date picker to select the user's birthday.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
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

  /// Sends the profile data to the backend API.
  Future<void> sendProfileData(Map<String, dynamic> profile) async {
    const String apiUrl = 'https://your-backend-api.com/profile';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(profile),
      );

      if (response.statusCode == 200) {
        logger.info('Profile data sent successfully');
      } else {
        logger.severe('Failed to send profile data: ${response.statusCode}');
      }
    } catch (e) {
      logger.severe('Error sending profile data: $e');
    }
  }

  /// Saves the profile data to local storage using SharedPreferences.
  Future<void> _saveProfileData(Map<String, dynamic> profile) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', profile['name']);
    await prefs.setInt('age', profile['age']);
    await prefs.setString('email', profile['email']);
    await prefs.setString('birthday', profile['birthday']);
  }

  /// Loads the profile data from local storage and populates the form fields.
  Future<void> _loadProfileData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('name') ?? "";
      _emailController.text = prefs.getString('email') ?? "";
      _birthdayController.text = prefs.getString('birthday') ?? "";
      if (prefs.getString('birthday') != null) {
        _selectedDate = DateTime.parse(prefs.getString('birthday')!);
      }
    });
    _validateForm();
  }

  /// Clears the profile data from local storage.
  /// This is called when the user navigates to the profile setup page.
  Future<void> _clearProfileData() async {
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      _nameController.text = '';
      _emailController.text = '';
      _birthdayController.text = '';
      _selectedDate = null;
    });
    _validateForm();
  }

  /// Submits the profile data and navigates to the profile edit page.
  void _submitProfile() {
    final String name = _nameController.text;
    final DateTime birthday = _selectedDate!;
    final int age = DateTime.now().year - birthday.year;

    final Map<String, dynamic> profile = {
      'name': name,
      'age': age,
      'email': _emailController.text,
      'birthday': birthday.toIso8601String(),
    };

    logger.info('Profile data: $profile'); // Log profile data

    sendProfileData(profile);
    _saveProfileData(profile);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditPage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Setting up your profiles',
          style: TextStyle(
              fontFamily: 'Itim', fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFF0F4F8),
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
                      ProfileTextField(
                        label: 'Name',
                        controller: _nameController,
                        onChanged: (value) {
                          _validateForm();
                          logger.info('Name updated: $value');
                        },
                      ),
                      const SizedBox(height: 16),
                      ProfileTextField(
                        label: 'Birthday',
                        controller: _birthdayController,
                        onTap: () => _selectDate(context),
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      ProfileTextField(
                        label: 'Email',
                        controller: _emailController,
                        onChanged: (value) {
                          _validateForm();
                          logger.info('Email updated: $value');
                        },
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
                onPressed: _isFormValid ? _submitProfile : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C9BCF),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: Text(
                  'Confirm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _isFormValid ? const Color(0xFF333333) : Colors.white,
                      fontFamily: 'Itim', fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for profile text fields.
class ProfileTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const ProfileTextField({
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: TextFormField(
            controller: controller,
            onTap: onTap,
            readOnly: readOnly,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: onTap != null
                  ? IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: onTap,
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 18, fontFamily: 'Itim'),
          ),
        ),
      ],
    );
  }
}
