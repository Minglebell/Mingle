import 'package:flutter/material.dart';
import 'package:minglev2_1/Screen/profile_otp_authen_page.dart';
import 'package:minglev2_1/Screen/profile_start_setup_page.dart';
import 'package:minglev2_1/Screen/profile_edit_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/searching_page.dart';
import 'package:minglev2_1/Screen/found_page.dart';
import 'package:minglev2_1/Screen/not_found_page.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';


class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final Map<String, WidgetBuilder> routes = {
    '/': (context) => ProfileOtp(),
    '/setupProfile': (context) {
      final phoneNumber = ModalRoute.of(context)!.settings.arguments as String;
      return SetupProfile(phoneNumber: phoneNumber);
    },
    '/editProfile': (context) => ProfileEditPage(),
    '/profile': (context) => ProfileDisplayPage(),
    '/match': (context) => FindMatchPage(),
    '/search': (context) => SearchingPage(),
    '/found': (context) => FoundPage(),
    '/notFound': (context) => NotFoundPage(),
    '/chatList': (context) => ChatListPage(),
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