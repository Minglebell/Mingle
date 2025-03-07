import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_customization_page.dart';
class MatchMenuPage extends StatefulWidget {
  @override
  _MatchMenuPageState createState() => _MatchMenuPageState();
}

class _MatchMenuPageState extends State<MatchMenuPage> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Matchmaking'),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
          // Navigate to other pages based on the index
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
      body: ListView(
        children: [
          ListTile(
            title: Text('Casual Match'),
            onTap: () {
              Navigator.pushNamed(context, '/casual-match');
            },
          ),
          ListTile(
            title: Text('Ranked Match'),
            onTap: () {
              Navigator.pushNamed(context, '/ranked-match');
            },
          ),
          ListTile(
            title: Text('Tournament'),
            onTap: () {
              Navigator.pushNamed(context, '/tournament');
            },
          ),
        ],
      ),
    );
  }
}

