import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:minglev2_1/Services/location_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  bool isPasswordVisible = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _nameController;
  late TextEditingController _birthdayController;
  String? _selectedGender;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Transgender',
    'LGBTQ+',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nameController = TextEditingController();
    _birthdayController = TextEditingController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _birthdayController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isOver20YearsOld(String birthday) {
    try {
      final parts = birthday.split('/');
      final birthDate = DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
      final today = DateTime.now();
      final difference = today.difference(birthDate).inDays;
      return difference >= (20 * 365); // Approximately 20 years
    } catch (e) {
      return false;
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    // Calculate the latest allowed date (20 years ago from today)
    final DateTime now = DateTime.now();
    final DateTime latestAllowedDate = DateTime(
      now.year - 20,
      now.month,
      now.day,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: latestAllowedDate,
      firstDate: DateTime(1900),
      lastDate: latestAllowedDate,
      selectableDayPredicate: (DateTime date) {
        // Only allow dates that would make the user 20 or older
        return date.isBefore(latestAllowedDate) ||
            date.isAtSameMomentAs(latestAllowedDate);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C9BCF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() {
        _birthdayController.text = formattedDate;
      });
    }
  }

  void _showToast(String message, bool isError) {
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder: (context) => ToastCard(
        leading: Icon(
          isError ? Icons.error : Icons.check_circle,
          size: 24,
          color: isError ? Colors.red : Colors.green,
        ),
        title: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ).show(context);
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (isLogin) {
          await _handleLogin();
        } else {
          await _handleRegistration();
        }
      } catch (e) {
        if (!mounted) return;
        _showToast('An unexpected error occurred. Please try again', true);
        _passwordController.clear();
      }
    }
  }

  Future<void> _handleLogin() async {
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        if (!mounted) return;
        _showToast('Login successful!', false);
        NavigationService().navigateToReplacement('/profile');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Please try again later';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection';
          break;
        default:
          errorMessage = 'Login failed. Please try again';
      }

      if (!mounted) return;
      _showToast(errorMessage, true);
      _passwordController.clear();
    }
  }

  Future<void> _handleRegistration() async {
    try {
      // Validate age and gender first
      if (!_isOver20YearsOld(_birthdayController.text)) {
        _showToast('You must be at least 20 years old to register', true);
        return;
      }

      if (_selectedGender == null) {
        _showToast('Please select your gender', true);
        return;
      }

      // Create user in Firebase Auth
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // If registration successful, proceed with storing user data
      if (userCredential.user != null) {
        await _storeUserData(userCredential.user!.uid);

        if (!mounted) return;
        _showToast(
            'Registration successful! Please login with your credentials',
            false);
        _clearRegistrationForm();
        setState(() {
          isLogin = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password should be at least 6 characters';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already registered';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Registration is currently disabled';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection';
          break;
        default:
          errorMessage = 'Registration failed. Please try again';
      }

      if (!mounted) return;
      _showToast(errorMessage, true);
      _passwordController.clear();
    }
  }

  Future<void> _storeUserData(String uid) async {
    try {
      // Calculate age from birthday
      final parts = _birthdayController.text.split('/');
      final birthDate = DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      // Request location permission and get location
      bool hasLocationPermission = await LocationService.checkLocationPermission();
      Map<String, dynamic>? locationData;

      if (hasLocationPermission) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );

          locationData = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'timestamp': FieldValue.serverTimestamp(),
          };
          debugPrint('Location obtained: $locationData');
        } catch (e) {
          debugPrint('Error getting location: $e');
          // Fallback to last known position if getting current position fails
          try {
            Position? lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              locationData = {
                'latitude': lastPosition.latitude,
                'longitude': lastPosition.longitude,
                'accuracy': lastPosition.accuracy,
                'timestamp': FieldValue.serverTimestamp(),
              };
              debugPrint('Last known location obtained: $locationData');
            }
          } catch (e) {
            debugPrint('Error getting last known location: $e');
          }
        }
      } else {
        debugPrint('Location permission not granted');
      }

      // Prepare user data
      final userData = {
        'email': _emailController.text,
        'name': _nameController.text,
        'birthday': _birthdayController.text,
        'age': age.toString(),
        'gender': [_selectedGender!],
        'createdAt': FieldValue.serverTimestamp(),
        'uid': uid,
        'lastActive': FieldValue.serverTimestamp(),
      };

      // Add location data if available
      if (locationData != null) {
        userData['location'] = locationData;
        userData['lastLocationUpdate'] = FieldValue.serverTimestamp();
      }

      // Store user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);

      debugPrint('User data stored successfully');
    } catch (e) {
      debugPrint('Error storing user data: $e');
      rethrow;
    }
  }

  void _clearRegistrationForm() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _birthdayController.clear();
    setState(() {
      _selectedGender = null;
    });
  }

  InputDecoration _getInputDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: const Color(0xFF6C9BCF)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C9BCF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Logo and App Name
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/Activities.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),  // Space between logo and text
                          const Text(
                            'Mingle',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C9BCF),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Text(
                            'Find your activity partner',  // Subtitle
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E8E),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title and Subtitle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLogin ? 'Welcome Back!' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isLogin
                                ? 'Sign in to continue your journey'
                                : 'Begin your adventure with us',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Form Fields
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                _getInputDecoration('Email', Icons.email),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email is required';
                              }
                              if (!_isValidEmail(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !isPasswordVisible,
                            decoration: _getInputDecoration(
                              'Password',
                              Icons.lock,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF6C9BCF),
                                ),
                                onPressed: () {
                                  setState(() {
                                    isPasswordVisible = !isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (!isLogin && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Registration Fields
                          if (!isLogin) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: _getInputDecoration(
                                  'Full Name', Icons.person),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Name is required'
                                      : null,
                            ),
                            const SizedBox(height: 16),

                            // Gender Selection
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: Color(0xFF6C9BCF)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('Select Gender'),
                                items: _genderOptions.map((String gender) {
                                  return DropdownMenuItem<String>(
                                    value: gender,
                                    child: Text(gender),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedGender = newValue;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your gender';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _birthdayController,
                              readOnly: true,
                              decoration: _getInputDecoration(
                                'Birthday',
                                Icons.cake,
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    color: Color(0xFF6C9BCF),
                                  ),
                                  onPressed: () => _selectBirthday(context),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Birthday is required';
                                }
                                if (!_isOver20YearsOld(value)) {
                                  return 'You must be at least 20 years old';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button with gradient
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
                            color: const Color(0xFF6C9BCF).withAlpha(76),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isLogin ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Toggle Button
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            isLogin = !isLogin;
                            _animationController.reset();
                            _animationController.forward();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 16),
                            children: [
                              TextSpan(
                                text: isLogin
                                    ? "Don't have an account? "
                                    : 'Already have an account? ',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              TextSpan(
                                text: isLogin ? 'Sign Up' : 'Sign In',
                                style: const TextStyle(
                                  color: Color(0xFF6C9BCF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  void updatePassword(String password) {
    state = state.copyWith(password: password);
  }

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void updateBirthday(String birthday) {
    state = state.copyWith(birthday: birthday);
  }
}

class AuthState {
  final String email;
  final String password;
  final String name;
  final String birthday;

  AuthState({
    this.email = '',
    this.password = '',
    this.name = '',
    this.birthday = '',
  });

  AuthState copyWith({
    String? email,
    String? password,
    String? name,
    String? birthday,
  }) {
    return AuthState(
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
    );
  }
}
