import 'package:flutter/material.dart';
import 'dart:async';
import '../Widget/bottom_navigation_bar.dart';
import '../Widget/chat_tile.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/custom_app_bar.dart';
import 'package:minglev2_1/Services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  int _currentPageIndex = 1;
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot>? _chatsStream;
  Map<String, int> _unreadCounts = {};
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _chatsStream = _chatService.getUserChats();
    _searchController.addListener(_filterChats);
    _setupUnreadMessagesListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _setupUnreadMessagesListener() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('Debug: No current user ID in unread listener');
      return;
    }

    print('Debug: Setting up unread messages listener for user: $currentUserId');

    final chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      print('Debug: Found ${snapshot.docs.length} chats for user');
      
      for (var doc in snapshot.docs) {
        final chatId = doc.id;
        final chatData = doc.data();
        print('Debug: Chat $chatId data: $chatData');
        
        // Check if the chat document indicates unread messages
        final hasUnreadMessages = chatData['hasUnreadMessages'] ?? false;
        print('Debug: Chat $chatId hasUnreadMessages: $hasUnreadMessages');
        
        if (!hasUnreadMessages) {
          setState(() {
            _unreadCounts[chatId] = 0;
          });
          continue;
        }
        
        print('Debug: Setting up listener for chat: $chatId');
        
        // Query for unread messages (read: false)
        final messagesSubscription = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', isNotEqualTo: currentUserId)
            .where('read', isEqualTo: false)
            .snapshots()
            .listen((messages) {
          if (!mounted) return;
          
          print('Debug: Chat $chatId has ${messages.docs.length} unread messages');
          print('Debug: Unread messages data: ${messages.docs.map((doc) => doc.data()).toList()}');
          
          setState(() {
            _unreadCounts[chatId] = messages.docs.length;
          });
        }, onError: (error) {
          print('Debug: Error listening to unread messages for chat $chatId: $error');
        });
        
        _subscriptions.add(messagesSubscription);
      }
    }, onError: (error) {
      print('Debug: Error listening to chats: $error');
    });
    
    _subscriptions.add(chatsSubscription);
  }

  void _filterChats() {
    // Implement search functionality if needed
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<String> _getParticipantName(String chatId, List<dynamic> participants) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('Debug: No current user ID');
      return 'Unknown';
    }

    print('Debug: Current user ID: $currentUserId');
    print('Debug: Participants: $participants');

    // Find the other participant's ID
    final otherParticipantId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    print('Debug: Other participant ID: $otherParticipantId');

    if (otherParticipantId.isEmpty) {
      print('Debug: No other participant found');
      return 'Unknown';
    }

    // Fetch the other participant's data from users collection
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherParticipantId)
        .get();

    print('Debug: User document data: ${userDoc.data()}');
    return userDoc.data()?['name'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chat',
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
          ),
          // Chat List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Debug: Stream error: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data?.docs ?? [];
                print('Debug: Number of chats: ${chats.length}');
                print('Debug: Current unread counts: $_unreadCounts');
                
                if (chats.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index].data() as Map<String, dynamic>;
                    final chatId = chats[index].id;
                    print('Debug: Chat data: $chat');
                    
                    final lastMessage = chat['lastMessage'] ?? '';
                    final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                    final timeString = lastMessageTime != null
                        ? _formatTimestamp(lastMessageTime)
                        : '';
                    final participants = List<String>.from(chat['participants'] ?? []);
                    print('Debug: Chat participants: $participants');

                    final unreadCount = _unreadCounts[chatId] ?? 0;
                    final hasUnreadMessages = unreadCount > 0;
                    print('Debug: Chat $chatId has $unreadCount unread messages');

                    return FutureBuilder<String>(
                      future: _getParticipantName(chatId, participants),
                      builder: (context, nameSnapshot) {
                        final participantName = nameSnapshot.data ?? 'Loading...';
                        print('Debug: Participant name: $participantName');
                        
                        // Get the other participant's ID
                        final otherParticipantId = participants.firstWhere(
                          (id) => id != _auth.currentUser?.uid,
                          orElse: () => '',
                        );
                        
                        return GestureDetector(
                          onTap: () {
                            NavigationService().navigateToChat(chatId, participantName, otherParticipantId);
                          },
                          child: ChatTile(
                            name: participantName,
                            message: lastMessage,
                            time: timeString,
                            chatId: chatId,
                            partnerId: otherParticipantId,
                            hasUnreadMessages: hasUnreadMessages,
                            unreadCount: unreadCount,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}