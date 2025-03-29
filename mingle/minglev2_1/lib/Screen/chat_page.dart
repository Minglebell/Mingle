import 'package:flutter/material.dart';
import 'dart:async';
import 'package:minglev2_1/Services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'dart:convert';


class ChatPage extends StatefulWidget {
  final String chatPersonName;
  final String chatId;
  final String partnerId;

  const ChatPage({
    super.key, 
    required this.chatPersonName,
    required this.chatId,
    required this.partnerId,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  Stream<QuerySnapshot>? _messagesStream;
  StreamSubscription? _messagesSubscription;
  bool _hasMarkedMessagesAsRead = false;
  StreamSubscription? _chatSubscription;
  Map<String, dynamic> _matchDetails = {};

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getChatStream(widget.chatId);
    _setupMessagesListener();
    _setupChatListener();
    _markMessagesAsRead();
    _fetchMatchDetails();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupChatListener() {
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      final chatData = snapshot.data();
      if (chatData != null) {
        final hasUnreadMessages = chatData['hasUnreadMessages'] ?? false;
        if (hasUnreadMessages && !_hasMarkedMessagesAsRead) {
          _markMessagesAsRead();
        }
      }
    });
  }

  void _setupMessagesListener() {
    _messagesSubscription = _messagesStream?.listen((snapshot) {
      if (!mounted) return;
      
      // Check for new unread messages
      final hasUnreadMessages = snapshot.docs.any((doc) {
        final message = doc.data() as Map<String, dynamic>;
        return message['senderId'] != _auth.currentUser?.uid && 
               message['read'] == false;
      });

      if (hasUnreadMessages && !_hasMarkedMessagesAsRead) {
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (_hasMarkedMessagesAsRead) return;

    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Get all unread messages
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      if (messages.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      
      // Update all unread messages to read
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'read': true});
      }

      // Update chat document
      batch.update(
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId),
        {
          'hasUnreadMessages': false,
          'lastReadBy': {
            currentUserId: FieldValue.serverTimestamp(),
          },
        },
      );

      await batch.commit();
      _hasMarkedMessagesAsRead = true;
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _fetchMatchDetails() async {
    try {
      print('Debug: Starting to fetch match details for chat ${widget.chatId}');
      final details = await _chatService.getMatchDetails(widget.chatId);
      print('Debug: Received match details: $details');
      if (mounted) {
        setState(() {
          _matchDetails = details;
        });
        print('Debug: Updated match details in state: $_matchDetails');
      }
    } catch (e) {
      print('Error fetching match details: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return;

        // Update chat document to indicate unread messages
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'hasUnreadMessages': true,
          'lastMessage': _messageController.text,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

        // Send the message
        await _chatService.sendMessage(widget.chatId, _messageController.text);
        _messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _showMatchDetails() {
    print('Debug: Showing match details dialog with data: $_matchDetails');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Match Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_matchDetails['category']?.isNotEmpty ?? false) ...[
                Text(
                  'Category: ${_matchDetails['category']}',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
              ],
              if (_matchDetails['place']?.isNotEmpty ?? false) ...[
                Text(
                  'Place: ${_matchDetails['place']}',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
              ],
              if (_matchDetails['schedule']?.isNotEmpty ?? false) ...[
                Text(
                  'Schedule: ${_matchDetails['schedule']}',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
              ],
              if (_matchDetails['matchDate']?.isNotEmpty ?? false)
                Text(
                  'Match Date: ${_matchDetails['matchDate']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              if (_matchDetails.values.every((value) => value.isEmpty))
                Text(
                  'No match details available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Show confirmation dialog
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Unmatch'),
                    content: const Text('Are you sure you want to unmatch with this person? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Unmatch'),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                try {
                  await _chatService.unmatch(widget.chatId);
                  if (context.mounted) {
                    Navigator.pop(context); // Close match details dialog
                    Navigator.pop(context); // Close chat page
                    NavigationService().navigateToReplacement('/chatList');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to unmatch: $e')),
                    );
                  }
                }
              }
            },
            child: Text(
              'Unmatch',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile() {
    NavigationService().navigateToProfile(widget.partnerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _navigateToProfile,
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(widget.partnerId).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          widget.chatPersonName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    final userData = snapshot.data?.data() as Map<String, dynamic>?;
                    final profileImage = userData?['profileImage'];

                    return CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: profileImage != null
                          ? MemoryImage(base64Decode(profileImage))
                          : null,
                      child: profileImage == null
                          ? Text(
                              widget.chatPersonName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _navigateToProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chatPersonName,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _showMatchDetails,
                color: Colors.black87,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
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

                final messages = snapshot.data?.docs ?? [];
                final currentUserId = _auth.currentUser?.uid;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUserId;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final timeString = timestamp != null 
                        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                        : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(isMe ? 20 : 0),
                                bottomRight: Radius.circular(isMe ? 0 : 20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['text'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                                if (timeString.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isMe && message['read'] == true && index == 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Read',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Write your message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.blue),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String name, String distance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                distance,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}