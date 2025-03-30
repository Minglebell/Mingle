import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
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
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  int _currentPageIndex = 1;
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot>? _chatsStream;
  final Map<String, int> _unreadCounts = {};
  final List<StreamSubscription> _subscriptions = [];
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
          setState(() {
            _unreadCounts[chatId] = messages.docs.length;
          });
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

  Future<String> _getParticipantName(
      String chatId, List<dynamic> participants) async {
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

  Widget _buildNewMatchesList(List<QueryDocumentSnapshot> allChats) {
    final newMatches = allChats.where((chat) {
      final chatData = chat.data() as Map<String, dynamic>;
      return chatData['lastMessage'] == null;
    }).toList();

    if (newMatches.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 140, // Increased height to accommodate name
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'New Matches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: newMatches.length,
              itemBuilder: (context, index) {
                final chat = newMatches[index].data() as Map<String, dynamic>;
                final chatId = newMatches[index].id;
                final participants = List<String>.from(chat['participants'] ?? []);

                return FutureBuilder<String>(
                  future: _getParticipantName(chatId, participants),
                  builder: (context, nameSnapshot) {
                    final participantName = nameSnapshot.data ?? 'Loading...';
                    final otherParticipantId = participants.firstWhere(
                      (id) => id != _auth.currentUser?.uid,
                      orElse: () => '',
                    );

                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: {
                            'chatId': chatId,
                            'partnerId': otherParticipantId,
                          },
                        );
                      },
                      child: Container(
                        width: 85, // Slightly increased width
                        margin: const EdgeInsets.symmetric(horizontal: 6), // Increased spacing between items
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 70, // Slightly larger avatar
                              width: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF6C9BCF),
                                  width: 2,
                                ),
                              ),
                              child: FutureBuilder<String?>(
                                future: _getParticipantProfileImage(otherParticipantId),
                                builder: (context, imageSnapshot) {
                                  return CircleAvatar(
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: imageSnapshot.data != null
                                        ? MemoryImage(base64Decode(imageSnapshot.data!))
                                        : null,
                                    child: imageSnapshot.data == null
                                        ? const Icon(Icons.person, color: Colors.grey)
                                        : null,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8), // Increased spacing between image and text
                            Container(
                              width: 85, // Match parent width
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                participantName,
                                maxLines: 2, // Allow two lines for longer names
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Future<String?> _getParticipantProfileImage(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return userDoc.data()?['profileImage'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Chat',
      ),
      backgroundColor: Colors.white, // Changed to white to match search field
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.blue),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style:
                              TextStyle(color: Colors.red[300], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      strokeWidth: 3,
                    ),
                  );
                }

                final chats = snapshot.data?.docs ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start matching to begin chatting!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildNewMatchesList(chats),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount:
                            chats.length + 1, // +1 for potential "no results" message
                        itemBuilder: (context, index) {
                          if (index == chats.length) {
                            return FutureBuilder<int>(
                              future: Future.wait(
                                chats.map((chat) async {
                                  final chatData =
                                      chat.data() as Map<String, dynamic>;
                                  final participants = List<String>.from(
                                      chatData['participants'] ?? []);
                                  final name = await _getParticipantName(
                                      chat.id, participants);
                                  return _matchesSearch(name) ? 1 : 0;
                                }),
                              ).then((values) => values.reduce((a, b) => a + b)),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();

                                final visibleItems = snapshot.data ?? 0;
                                if (visibleItems == 0 && _searchQuery.isNotEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 40),
                                        Icon(
                                          Icons.search_off,
                                          size: 64,
                                          color: Colors.grey[300],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No results found for "$_searchQuery"',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          }

                          final chat = chats[index].data() as Map<String, dynamic>;
                          final chatId = chats[index].id;

                          final lastMessage = chat['lastMessage'] ?? '';
                          final lastMessageTime =
                              chat['lastMessageTime'] as Timestamp?;
                          final timeString = lastMessageTime != null
                              ? _formatTimestamp(lastMessageTime)
                              : '';
                          final participants =
                              List<String>.from(chat['participants'] ?? []);

                          final unreadCount = _unreadCounts[chatId] ?? 0;
                          final hasUnreadMessages = unreadCount > 0;

                          return FutureBuilder<String>(
                            future: _getParticipantName(chatId, participants),
                            builder: (context, nameSnapshot) {
                              final participantName =
                                  nameSnapshot.data ?? 'Loading...';

                              if (!_matchesSearch(participantName)) {
                                return const SizedBox.shrink();
                              }

                              final otherParticipantId = participants.firstWhere(
                                (id) => id != _auth.currentUser?.uid,
                                orElse: () => '',
                              );

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1),
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
                      ),
                    ),
                  ],
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

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
