import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'Screen/profile_setup.dart';

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
      theme: ThemeData(primarySwatch: Colors.pink, fontFamily: 'Itim'),
    );
  }
}