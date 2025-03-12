import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_customization_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/found_page.dart'; // Import the new FoundPage

class SearchingPage extends StatefulWidget {
  @override
  _SearchingPageState createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage>
    with SingleTickerProviderStateMixin {
  int currentPageIndex = 0;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);

    // Simulate finding a user after 1 minute
    Future.delayed(Duration(minutes: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => FoundPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Searching...'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RotationTransition(
              turns: _animation,
              child: Icon(Icons.search, size: 50, color: Colors.blue),
            ),
            SizedBox(height: 20),
            Text(
              'Tips: The more distance you have, more likely you will found someone.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => FindMatchPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
              ),
              child: Text(
                'Cancel',
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
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ChatListPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProfileEditPage()),
            );
          }
        },
      ),
    );
  }
}