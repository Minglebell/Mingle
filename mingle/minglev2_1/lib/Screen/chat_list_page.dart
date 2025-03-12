import 'package:flutter/material.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/profile_customization_page.dart';
import '../Widget/bottom_navigation_bar.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  int _currentPageIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Chat List'),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
          // Navigate to other pages based on the index
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => FindMatchPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProfileEditPage()),
            );
          }
        },
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              child: Text('A'),
            ),
            title: Text('User $index'),
            subtitle: Text('This is a chat message'),
          );
        },
      ),
    );
  }
}

