import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minglev2_1/Screen/profile_edit_page.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(),
);

class SetupProfile extends ConsumerStatefulWidget {
  final String phoneNumber; // Added to pass phone number from OTP screen

  const SetupProfile({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  ConsumerState<SetupProfile> createState() => _SetupProfileState();
}

class _SetupProfileState extends ConsumerState<SetupProfile> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _birthdayController;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _birthdayController = TextEditingController(text: profile.birthday);
    _nameController = TextEditingController(text: profile.name);
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveUserProfile() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    final profileState = ref.read(profileProvider);

    try {
      await firestore.collection('users').doc(widget.phoneNumber).update({
        'name': profileState.name,
        'birthday': profileState.birthday,
      });

      debugPrint('User profile updated successfully');
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  void _navigateToProfileCustom(BuildContext context) async {
    await _saveUserProfile(); 
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ProfileEditPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileNotifier = ref.read(profileProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Setting up profile',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 32,
            fontFamily: 'Itim',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF0F4F8),
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Please enter your name and birthday to continue',
              style: TextStyle(
                color: Color(0xCC333333),
                fontSize: 18,
                fontFamily: 'Itim',
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Name Field
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6C9BCF)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6C9BCF)),
                        ),
                      ),
                      controller: _nameController,
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Name is required'
                                  : null,
                      onChanged: (value) => profileNotifier.updateName(value),
                    ),
                    const SizedBox(height: 16),
                    // Birthday Field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Birthday',
                        labelStyle: TextStyle(
                          color: const Color(0xFF333333),
                          fontSize: 18,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6C9BCF)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF6C9BCF)),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF333333),
                          ),
                          onPressed: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );

                            if (pickedDate != null) {
                              final formattedDate =
                                  "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                              profileNotifier.updateBirthday(formattedDate);
                              _birthdayController.text = formattedDate;
                            }
                          },
                        ),
                      ),
                      controller: _birthdayController,
                      readOnly: true,
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Birthday is required'
                                  : null,
                    ),
                  ],
                ),
              ),
            ),
            // Save Button
            Container(
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _navigateToProfileCustom(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C9BCF),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 24,
                    fontFamily: 'Itim',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(ProfileState());

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void updateBirthday(String birthday) {
    state = state.copyWith(birthday: birthday);
  }
}

class ProfileState {
  final String name;
  final String birthday;

  ProfileState({this.name = '', this.birthday = ''});

  ProfileState copyWith({String? name, String? birthday}) {
    return ProfileState(
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
    );
  }
}
