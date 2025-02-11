import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'profile_edit.dart'; // Import the ProfileEditPage

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