import 'package:flutter/material.dart';
import '../../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/chat_tile.dart';

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

  // Controller for the search bar
  final TextEditingController _searchController = TextEditingController();

  // Filtered list of chats based on search input
  List<Map<String, String>> filteredChats = [];

  @override
  void initState() {
    super.initState();
    // Initialize filteredChats with all chats
    filteredChats = List.from(chats);
    // Listen to changes in the search bar
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    _searchController.dispose();
    super.dispose();
  }

  // Function to filter chats based on search input
  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredChats = chats
          .where((chat) =>
              chat['name']!.toLowerCase().contains(query) ||
              chat['message']!.toLowerCase().contains(query))
          .toList();
    });
  }

  // Function to clear the search bar and reset the chat list
  void _clearSearch() {
    _searchController.clear();
    _filterChats(); // Call _filterChats to reset the list
  }

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
            NavigationService().navigateToReplacement('/match');
          } else if (index == 1) {
            NavigationService().navigateToReplacement('/chatList');
          } else if (index == 2) {
            NavigationService().navigateToReplacement('/profile');
          }
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController, // Connect the controller
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                // Clear search button
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: _clearSearch, // Call _clearSearch
                      )
                    : null,
              ),
              onChanged: (value) {
                // Trigger filtering when the text changes
                _filterChats();
              },
            ),
          ),
          // Chat List
          Expanded(
            child: filteredChats.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return ChatTile(
                        name: chat['name']!,
                        message: chat['message']!,
                        time: chat['time']!,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}