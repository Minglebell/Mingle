import 'package:flutter/material.dart';
import 'package:minglev2_1/Screen/auth_page.dart';
import 'package:minglev2_1/Screen/profile_edit_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/searching_page.dart';
import 'package:minglev2_1/Screen/found_page.dart';
import 'package:minglev2_1/Screen/not_found_page.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/chat_page.dart';

// Custom FadePageRoute for smooth fade transitions
class FadePageRoute<T> extends PageRoute<T> {
  FadePageRoute({
    required this.builder,
    RouteSettings? settings,
  }) : super(settings: settings);

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final Map<String, WidgetBuilder> routes = {
    '/': (context) => AuthPage(),
    '/editProfile': (context) => ProfileEditPage(),
    '/profile': (context) => ProfileDisplayPage(),
    '/match': (context) => FindMatchPage(),
    '/search': (context) => SearchingPage(
      selectedGender: 'Male',
      ageRange: const RangeValues(18, 100),
      maxDistance: 10.0,
      selectedPlace: 'Any',
      selectedCategory: 'Any',
    ),
    '/found': (context) => FoundPage(),
    '/notFound': (context) => NotFoundPage(),
    '/chatList': (context) => ChatListPage(),
  };

  Future<dynamic> navigateTo(String routeName, {dynamic arguments}) {
    return navigatorKey.currentState!.push(
      FadePageRoute(
        builder: (context) => routes[routeName]!(context),
        settings: RouteSettings(name: routeName, arguments: arguments),
      ),
    );
  }

  Future<dynamic> navigateToReplacement(String routeName, {dynamic arguments}) {
    return navigatorKey.currentState!.pushReplacement(
      FadePageRoute(
        builder: (context) => routes[routeName]!(context),
        settings: RouteSettings(name: routeName, arguments: arguments),
      ),
    );
  }

  Future<dynamic> navigateToChat(String chatId, String name, String partnerId) {
    return navigatorKey.currentState!.push(
      FadePageRoute(
        builder: (context) => ChatPage(
          chatPersonName: name,
          chatId: chatId,
          partnerId: partnerId,
        ),
      ),
    );
  }

  Future<dynamic> navigateToProfile(String userId) {
    return navigatorKey.currentState!.push(
      FadePageRoute(
        builder: (context) => ProfileDisplayPage(
          userId: userId,
          showBottomNav: false,
        ),
      ),
    );
  }

  void goBack() {
    return navigatorKey.currentState!.pop();
  }
}