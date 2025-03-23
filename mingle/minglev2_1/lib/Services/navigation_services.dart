import 'package:flutter/material.dart';
import 'package:minglev2_1/Screen/profile_otp_authen_page.dart';
import 'package:minglev2_1/Screen/profile_start_setup_page.dart';
import 'package:minglev2_1/Screen/profile_edit_page.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Define your routes here
  final Map<String, WidgetBuilder> routes = {
    '/': (context) => ProfileOtp(),
    '/setupProfile': (context) {
      final phoneNumber = ModalRoute.of(context)!.settings.arguments as String;
      return SetupProfile(phoneNumber: phoneNumber);
    },
    '/editProfile': (context) => ProfileEditPage(),
  };

  factory NavigationService() {
    return _instance;
  }

  NavigationService._internal();

  Future<dynamic> navigateTo(String routeName, {dynamic arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  Future<dynamic> navigateToReplacement(String routeName, {dynamic arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  Future<dynamic> navigateToAndRemoveUntil(String routeName, {dynamic arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }
}