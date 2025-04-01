import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:minglev2_1/Services/navigation_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // Replace with actual values
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCiZMeMdKrpFWB6hyIFfShfu_N3DJrgVr0',
      appId: '1:410780510942:web:538244212c2cb157e5b04f',
      messagingSenderId: '410780510942',
      projectId: 'mingle-6db44',
    ),
  );

  runApp(DevicePreview(enabled: true, builder: (context) => const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationService = NavigationService();

    return ProviderScope(
      child: MaterialApp(
        builder: DevicePreview.appBuilder,
        locale: DevicePreview.locale(context),
        navigatorKey: navigationService.navigatorKey,
        initialRoute: '/', // Set the initial route
        routes:
            navigationService.routes, // Use the routes from NavigationService
        theme: ThemeData(primarySwatch: Colors.pink, fontFamily: 'Itim'),
      ),
    );
  }
}
