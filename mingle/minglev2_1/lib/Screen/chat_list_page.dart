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
  String _searchQuery = '';

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
    if (currentUserId == null) return;

    final chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final chatId = doc.id;
        final chatData = doc.data();
        final hasUnreadMessages = chatData['hasUnreadMessages'] ?? false;
        
        if (!hasUnreadMessages) {
          setState(() {
            _unreadCounts[chatId] = 0;
          });
          continue;
        }
        
        final messagesSubscription = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', isNotEqualTo: currentUserId)
            .where('read', isEqualTo: false)
            .snapshots()
            .listen((messages) {
          if (!mounted) return;
          
          final count = messages.docs.length;
          setState(() {
            _unreadCounts[chatId] = count;
          });

          if (count == 0) {
            FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .update({
              'hasUnreadMessages': false,
              'lastReadBy': {
                currentUserId: FieldValue.serverTimestamp(),
              },
            });
          }
        });
        
        _subscriptions.add(messagesSubscription);
      }
    });
    
    _subscriptions.add(chatsSubscription);
  }

  void _filterChats() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  bool _matchesSearch(String name) {
    if (_searchQuery.isEmpty) return true;
    return name.toLowerCase().contains(_searchQuery);
  }

  Future<String> _getParticipantName(String chatId, List<dynamic> participants) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'Unknown';

    final otherParticipantId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherParticipantId.isEmpty) return 'Unknown';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherParticipantId)
        .get();

    return userDoc.data()?['name'] ?? 'Unknown';
  }

  Future<void> _markChatAsRead(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'read': true});
      }

      batch.update(
        FirebaseFirestore.instance.collection('chats').doc(chatId),
        {
          'hasUnreadMessages': false,
          'lastReadBy': {
            currentUserId: FieldValue.serverTimestamp(),
          },
        },
      );

      await batch.commit();
      
      setState(() {
        _unreadCounts[chatId] = 0;
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
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
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Something went wrong',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }

                final chats = snapshot.data?.docs ?? [];
                
                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index].data() as Map<String, dynamic>;
                    final chatId = chats[index].id;
                    
                    final lastMessage = chat['lastMessage'] ?? '';
                    final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                    final timeString = lastMessageTime != null
                        ? _formatTimestamp(lastMessageTime)
                        : '';
                    final participants = List<String>.from(chat['participants'] ?? []);

                    final unreadCount = _unreadCounts[chatId] ?? 0;
                    final hasUnreadMessages = unreadCount > 0;

                    return FutureBuilder<String>(
                      future: _getParticipantName(chatId, participants),
                      builder: (context, nameSnapshot) {
                        final participantName = nameSnapshot.data ?? 'Loading...';
                        
                        if (!_matchesSearch(participantName)) {
                          return SizedBox.shrink();
                        }
                        
                        final otherParticipantId = participants.firstWhere(
                          (id) => id != _auth.currentUser?.uid,
                          orElse: () => '',
                        );
                        
                        return GestureDetector(
                          onTap: () async {
                            await _markChatAsRead(chatId);
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