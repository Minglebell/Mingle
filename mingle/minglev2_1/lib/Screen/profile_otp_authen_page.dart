import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Screen/profile_start_setup_page.dart';

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

  void _navigateToSetupProfile(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SetupProfile()),
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
              Image.asset(
                'assets/images/OTP.png',
                width: 200,
                height: 200,
              ),
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
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? 'Please enter your phone number'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                final otpController = TextEditingController();
                                return AlertDialog(
                                  title: const Text(
                                    'Enter OTP',
                                    style: TextStyle(
                                      color: Color(0xFF333333),
                                      fontSize: 24,
                                      fontFamily: 'Itim',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Enter received OTP',
                                      labelStyle: TextStyle(
                                        color: Color(0xFF333333),
                                        fontSize: 16,
                                        fontFamily: 'Itim',
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFF6C9BCF),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFF6C9BCF),
                                        ),
                                      ),
                                    ),
                                    controller: otpController,
                                    validator:
                                        (value) =>
                                            value == null || value.isEmpty
                                                ? 'Please enter the OTP'
                                                : null,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        if (otpNotifier.verifyOtp(
                                          otpController.text,
                                        )) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'OTP verified successfully',
                                              ),
                                            ),
                                          );
                                          _navigateToSetupProfile(context);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Invalid OTP'),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Submit'),
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
                            color: Color(0xFF333333),
                            fontSize: 24,
                            fontFamily: 'Itim',
                            fontWeight: FontWeight.bold,
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

