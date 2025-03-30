import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/searching_page.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/custom_app_bar.dart';

class NotFoundPage extends StatefulWidget {
  const NotFoundPage({super.key});

  @override
  State<NotFoundPage> createState() => _NotFoundPageState();
}

class _NotFoundPageState extends State<NotFoundPage> {
  int currentPageIndex = 0; // Track the current index for the bottom navigation bar

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Not Found',
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'No matches found. Please try again or go back to the match menu.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Try Again: Navigate back to SearchingPage
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchingPage(
                      selectedGender: 'Male', // Default value
                      ageRange: RangeValues(18, 100), // Default range
                      maxDistance: 10.0, // Default distance
                      selectedPlace: 'Any', // Default place
                      selectedCategory: 'Any', // Default category
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Go Back to Match Menu
                Navigator.pushReplacement(
                  context,
                  FadePageRoute(builder: (context) => const FindMatchPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
              ),
              child: const Text(
                'Go Back to Match Menu',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
          // Handle navigation based on the selected index
          switch (index) {
            case 0:
              // Navigate to Home (if needed)
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                FadePageRoute(builder: (context) => const ChatListPage()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                FadePageRoute(builder: (context) => const ProfileDisplayPage()),
              );
              break;
          }
        },
      ),
    );
  }
}