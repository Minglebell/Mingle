import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minglev2_1/Screen/profile_start_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delightful_toast/delight_toast.dart';

final otpProvider = StateNotifierProvider<OtpNotifier, OtpState>(
  (ref) => OtpNotifier(),
);

class OtpState {
  final bool isOtpSent;
  final bool isOtpVerified;
  final String mockOtp;

  OtpState({
    this.isOtpSent = false,
    this.isOtpVerified = false,
    this.mockOtp = '123456',
  });

  OtpState copyWith({bool? isOtpSent, bool? isOtpVerified}) {
    return OtpState(
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isOtpVerified: isOtpVerified ?? this.isOtpVerified,
      mockOtp: mockOtp,
    );
  }
}

class OtpNotifier extends StateNotifier<OtpState> {
  OtpNotifier() : super(OtpState());

  void sendOtp() {
    state = state.copyWith(isOtpSent: true);
  }

  bool verifyOtp(String inputOtp) {
    if (inputOtp == state.mockOtp) {
      state = state.copyWith(isOtpVerified: true);
      return true;
    }
    return false;
  }
}

class ProfileOtp extends ConsumerWidget {
  ProfileOtp({Key? key}) : super(key: key);

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  // Callback function to show toast
  void _showToast(BuildContext context, String message) {
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder:
          (context) => ToastCard(
            leading: const Icon(Icons.error, size: 24, color: Colors.red),
            title: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
    ).show(context);
  }

  Future<void> _saveUserToFirestore(String phoneNumber) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      await firestore.collection('users').doc(phoneNumber).set({
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': true,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phoneNumber', phoneNumber);

      debugPrint('User data saved successfully');
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  void _navigateToSetupProfile(BuildContext context, String phoneNumber) async {
    await _saveUserToFirestore(phoneNumber);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SetupProfile(phoneNumber: phoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otpState = ref.watch(otpProvider);
    final otpNotifier = ref.read(otpProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/OTP.png', width: 200, height: 200),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'OTP Verification',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 32,
                    fontFamily: 'Itim',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Start by entering your phone number to get OTP for verification',
                style: TextStyle(color: const Color(0xCC333333), fontSize: 16),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
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
                        filled: true,
                        fillColor: const Color(0xFFF0F4F8),
                      ),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly, // Only allow digits
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          _showToast(
                            context,
                            'Please enter your phone number',
                          ); // Show toast
                          return 'Please enter your phone number'; // Return error message
                        } else if (value.length != 10) {
                          _showToast(
                            context,
                            'Phone number must be 10 digits',
                          ); // Show toast
                          return 'Phone number must be 10 digits'; // Return error message
                        } else if (!value.startsWith('0')) {
                          _showToast(
                            context,
                            'Phone number must start with 0',
                          ); // Show toast
                          return 'Phone number must start with 0'; // Return error message
                        }
                        return null; // Validation passed
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (otpState.isOtpVerified)
                            return; // Prevent multiple taps if already verified
                          final phoneNumber = _phoneController.text;
                          if (phoneNumber.isEmpty) {
                            DelightToastBar(
                              autoDismiss: true,
                              snackbarDuration: Duration(seconds: 3),
                              builder:
                                  (context) => const ToastCard(
                                    leading: Icon(
                                      Icons.error,
                                      size: 24,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      'Please enter your phone number',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                            ).show(context);
                          }

                          final firestore = FirebaseFirestore.instance;
                          final docRef = firestore
                              .collection('users')
                              .doc(phoneNumber);
                          final doc = await docRef.get();

                          if (doc.exists) {
                            DelightToastBar(
                              autoDismiss: true,
                              snackbarDuration: Duration(seconds: 3),
                              builder:
                                  (context) => const ToastCard(
                                    leading: Icon(
                                      Icons.error,
                                      size: 24,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      'Phone number already exists',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                            ).show(context);
                            return;
                          }

                          otpNotifier.sendOtp();

                          if (_formKey.currentState!.validate()) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                final otpController = TextEditingController();
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.0),
                                  ),
                                  title: const Text(
                                    'Enter OTP',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Itim',
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Please enter the OTP sent to your phone number',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xCC333333),
                                          fontFamily: 'Itim',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: otpController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontFamily: 'Itim',
                                          color: Color(0xFF333333),
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF0F4F8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12.0,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 20,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(
                                              context,
                                            ); // Close the dialog
                                          },
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Itim',
                                              color: Color(0xFF6C9BCF),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (otpNotifier.verifyOtp(
                                              otpController.text,
                                            )) {
                                              DelightToastBar(
                                                autoDismiss: true,
                                                snackbarDuration: Duration(
                                                  seconds: 3,
                                                ),
                                                builder:
                                                    (
                                                      context,
                                                    ) => const ToastCard(
                                                      leading: Icon(
                                                        Icons.check,
                                                        size: 24,
                                                        color:
                                                            Colors.lightGreen,
                                                      ),
                                                      title: Text(
                                                        'OTP Verified',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                              ).show(context);
                                              _navigateToSetupProfile(
                                                context,
                                                phoneNumber,
                                              );
                                            } else {
                                              DelightToastBar(
                                                autoDismiss: true,
                                                snackbarDuration: Duration(
                                                  seconds: 3,
                                                ),
                                                builder:
                                                    (context) =>
                                                        const ToastCard(
                                                          leading: Icon(
                                                            Icons.error,
                                                            size: 24,
                                                            color: Colors.red,
                                                          ),
                                                          title: Text(
                                                            'Invalid OTP',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                              ).show(context);
                                              otpController
                                                  .clear(); // Clear on invalid OTP
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF6C9BCF,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 24,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                            ),
                                          ),
                                          child: const Text(
                                            'Submit',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Itim',
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              otpState.isOtpVerified
                                  ? Colors.grey[400]
                                  : const Color(0xFF6C9BCF),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: Text(
                          otpState.isOtpVerified ? 'Verified' : 'Send OTP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontFamily: 'Itim',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
