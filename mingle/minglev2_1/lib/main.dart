import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Screen/profile_otp_authen_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        builder: DevicePreview.appBuilder,
        locale: DevicePreview.locale(context),
        home: ProfileOtp(),
        theme: ThemeData(primarySwatch: Colors.pink, fontFamily: 'Itim'),
      ),
    );
  }
}
