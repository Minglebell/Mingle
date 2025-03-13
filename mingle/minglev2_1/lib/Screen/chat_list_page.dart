import 'package:flutter/material.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Screen/chat_page.dart';
import '../../Widget/bottom_navigation_bar.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  int _currentPageIndex = 1;

  // Dummy chat data
  final List<Map<String, String>> chats = [
    {'name': 'Jennifer', 'message': 'You: How are you?', 'time': '2 mins ago'},
    {'name': 'Noxi', 'message': 'Ok!', 'time': '10 mins ago'},
    {
      'name': 'Matthew',
      'message': 'Where did you want to go',
      'time': '2 hours ago',
    },
    {'name': 'Alexi', 'message': 'Hey!', 'time': 'Yesterday'},
    {'name': 'Zeni', 'message': 'Hey!', 'time': 'Yesterday'},
    {'name': 'Oiko', 'message': 'Hey!', 'time': 'Yesterday'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Search...',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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
              MaterialPageRoute(builder: (context) => ProfileDisplayPage()),
            );
          }
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // Chat List
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                ChatPage(chatPersonName: chat['name']!),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      chat['name']![0],
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    chat['name']!,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat['message']!,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  trailing: Text(
                    chat['time']!,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
