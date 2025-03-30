import 'package:flutter/material.dart';
import 'dart:async';
import 'package:minglev2_1/Services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:logging/logging.dart';
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
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final Logger _logger = Logger('ChatPage');
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
    // Mark user as active in this chat
    _chatService.updateActiveUsers(widget.chatId, _auth.currentUser?.uid ?? '', true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _scrollController.dispose();
    // Mark user as inactive in this chat
    _chatService.updateActiveUsers(widget.chatId, _auth.currentUser?.uid ?? '', false);
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

      if (hasUnreadMessages) {
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (_hasMarkedMessagesAsRead) {
      _logger.fine('Messages already marked as read');
      return;
    }

    try {
      await _chatService.markMessagesAsRead(widget.chatId);
      _hasMarkedMessagesAsRead = true;
      _logger.info('Successfully marked messages as read');
    } catch (e) {
      _logger.severe('Error marking messages as read: $e');
    }
  }

  Future<void> _fetchMatchDetails() async {
    try {
      _logger.info('Starting to fetch match details for chat ${widget.chatId}');
      final details = await _chatService.getMatchDetails(widget.chatId);
      _logger.fine('Received match details: $details');
      if (!mounted) return;
      
      setState(() {
        _matchDetails = details;
      });
      _logger.fine('Updated match details in state: $_matchDetails');
    } catch (e) {
      _logger.severe('Error fetching match details: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    
    final messageText = _messageController.text;
    _messageController.clear();

    try {
      await _chatService.sendMessage(widget.chatId, messageText);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _showMatchDetails() {
    _logger.fine('Showing match details dialog with data: $_matchDetails');
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Match Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_matchDetails['category'] != null && _matchDetails['category'].toString().isNotEmpty)
                Text(
                  'Category: ${_matchDetails['category']}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (_matchDetails['category'] != null && _matchDetails['category'].toString().isNotEmpty) const SizedBox(height: 8),
              if (_matchDetails['place'] != null && _matchDetails['place'].toString().isNotEmpty)
                Text(
                  'Place: ${_matchDetails['place']}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (_matchDetails['place'] != null && _matchDetails['place'].toString().isNotEmpty) const SizedBox(height: 8),
              if (_matchDetails['schedule'] != null) ...[
                const Text(
                  'Schedule:',
                  style:  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (_matchDetails['schedule'] is Timestamp)
                  Text(
                    'Date: ${(_matchDetails['schedule'] as Timestamp).toDate().day}/${(_matchDetails['schedule'] as Timestamp).toDate().month}/${(_matchDetails['schedule'] as Timestamp).toDate().year}',
                    style: const TextStyle(fontSize: 16),
                  )
                else if (_matchDetails['schedule'] is String && (_matchDetails['schedule'] as String).isNotEmpty)
                  Text(
                    'Date: ${_matchDetails['schedule']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (_matchDetails['timeRange'] != null && (_matchDetails['timeRange'] as String).isNotEmpty)
                  Text(
                    'Time: ${_matchDetails['timeRange']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 16),
              ],
              if (_matchDetails['matchDate'] != null && (_matchDetails['matchDate'] as String).isNotEmpty)
                Text(
                  'Match Date: ${_matchDetails['matchDate']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              if (_matchDetails.isEmpty || (_matchDetails['category'] == null && _matchDetails['place'] == null && _matchDetails['schedule'] == null && _matchDetails['matchDate'] == null))
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
                context: dialogContext,
                builder: (BuildContext confirmContext) {
                  return AlertDialog(
                    title: const Text('Confirm Unmatch'),
                    content: Text('Are you sure you want to unmatch with ${widget.chatPersonName}? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text(
                          'Unmatch',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm != true || !mounted) return;

              if (!dialogContext.mounted) return;

              // Store contexts before async gap
              final navigatorContext = Navigator.of(dialogContext);
              final scaffoldContext = ScaffoldMessenger.of(dialogContext);
              
              // Show loading dialog
              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                builder: (BuildContext loadingContext) {
                  return const PopScope(
                    canPop: false,
                    child: AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Unmatching...'),
                        ],
                      ),
                    ),
                  );
                },
              );

              try {
                await _chatService.unmatch(widget.chatId);
                if (!mounted) return;
                
                navigatorContext.pop(); // Close the loading dialog
                navigatorContext.pop(); // Close the match details dialog
                Navigator.of(context).pop(); // Go back to chat list
              } catch (e) {
                if (!mounted) return;
                
                navigatorContext.pop(); // Close the loading dialog
                scaffoldContext.showSnackBar(
                  const SnackBar(
                    content: Text('Unable to unmatch at this time. Please try again later.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Unmatch',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
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
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 2,
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
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.chatPersonName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    final userData = snapshot.data?.data() as Map<String, dynamic>?;
                    final profileImage = userData?['profileImage'];

                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImage != null
                          ? MemoryImage(base64Decode(profileImage))
                          : null,
                      child: profileImage == null
                          ? Text(
                              widget.chatPersonName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.blue,
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
                          color: Colors.white,
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
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white70,
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
                icon: const Icon(Icons.more_vert),
                onPressed: _showMatchDetails,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data?.docs ?? [];
                  final currentUserId = _auth.currentUser?.uid;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
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
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
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
                                      const SizedBox(height: 4),
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
                                  padding: const EdgeInsets.only(top: 4, right: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.done_all, size: 16, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Read',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
