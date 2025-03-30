import 'package:flutter/material.dart';
import 'dart:async';
import 'package:minglev2_1/Services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';


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
  final ImagePicker _imagePicker = ImagePicker();
  String? _chatPersonImage;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getChatStream(widget.chatId);
    _setupMessagesListener();
    _setupChatListener();
    _markMessagesAsRead();
    _fetchMatchDetails();
    _chatService.updateActiveUsers(
        widget.chatId, _auth.currentUser?.uid ?? '', true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _scrollController.dispose();
    _chatService.updateActiveUsers(
        widget.chatId, _auth.currentUser?.uid ?? '', false);
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
              if (_matchDetails['category'] != null &&
                  _matchDetails['category'].toString().isNotEmpty)
                Text(
                  'Category: ${_matchDetails['category']}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (_matchDetails['category'] != null &&
                  _matchDetails['category'].toString().isNotEmpty)
                const SizedBox(height: 8),
              if (_matchDetails['place'] != null &&
                  _matchDetails['place'].toString().isNotEmpty)
                Text(
                  'Place: ${_matchDetails['place']}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (_matchDetails['place'] != null &&
                  _matchDetails['place'].toString().isNotEmpty)
                const SizedBox(height: 8),
              if (_matchDetails['schedule'] != null) ...[
                const Text(
                  'Schedule:',
                  style: TextStyle(
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
                else if (_matchDetails['schedule'] is String &&
                    (_matchDetails['schedule'] as String).isNotEmpty)
                  Text(
                    'Date: ${_matchDetails['schedule']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (_matchDetails['timeRange'] != null &&
                    (_matchDetails['timeRange'] as String).isNotEmpty)
                  Text(
                    'Time: ${_matchDetails['timeRange']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 16),
              ],
              if (_matchDetails['matchDate'] != null &&
                  (_matchDetails['matchDate'] as String).isNotEmpty)
                Text(
                  'Match Date: ${_matchDetails['matchDate']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              if (_matchDetails.isEmpty ||
                  (_matchDetails['category'] == null &&
                      _matchDetails['place'] == null &&
                      _matchDetails['schedule'] == null &&
                      _matchDetails['matchDate'] == null))
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
                    content: Text(
                        'Are you sure you want to unmatch with ${widget.chatPersonName}? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
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
                    content: Text(
                        'Unable to unmatch at this time. Please try again later.'),
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

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedImage != null && mounted) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const PopScope(
              canPop: false,
              child: AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Sending image...'),
                  ],
                ),
              ),
            );
          },
        );

        try {
          await _chatService.sendImageMessage(widget.chatId, pickedImage);
          if (!mounted) return;
          Navigator.pop(context); // Dismiss loading dialog
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send image: $e')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showFullScreenImage(String base64Image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                base64Decode(base64Image),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaceRecommendations() {
    final category = _matchDetails['category'] ?? '';
    final place = _matchDetails['place'] ?? '';
  
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFEEEEEE),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recommended Places',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category.isNotEmpty) ...[
                          Text(
                            'Based on your match category: $category',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6C9BCF),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ..._getRecommendedPlaces(category).map((place) => 
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F1FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(place['type']),
                                    color: const Color(0xFF6C9BCF),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        place['name'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        place['description'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 16,
                                            color: Colors.amber[400],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            place['rating'].toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            place['distance'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  color: const Color(0xFF6C9BCF),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _sharePlace(place);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getRecommendedPlaces(String category) {
    // This is a mock data function - in a real app, this would fetch from an API
    switch (category.toLowerCase()) {
      case 'coffee':
        return [
          {
            'name': 'Starbucks Reserve',
            'type': 'cafe',
            'description': 'Premium coffee experience with unique blends',
            'rating': 4.5,
            'distance': '0.8 km',
          },
          {
            'name': 'Local Coffee House',
            'type': 'cafe',
            'description': 'Cozy atmosphere with artisanal coffee',
            'rating': 4.7,
            'distance': '1.2 km',
          },
        ];
      case 'dining':
        return [
          {
            'name': 'The Garden Restaurant',
            'type': 'restaurant',
            'description': 'Fine dining with outdoor seating',
            'rating': 4.8,
            'distance': '1.5 km',
          },
          {
            'name': 'Urban Kitchen',
            'type': 'restaurant',
            'description': 'Modern fusion cuisine in heart of city',
            'rating': 4.6,
            'distance': '2.0 km',
          },
        ];
      case 'activity':
        return [
          {
            'name': 'City Adventure Park',
            'type': 'activity',
            'description': 'Outdoor activities and adventure sports',
            'rating': 4.4,
            'distance': '3.2 km',
          },
          {
            'name': 'Art Workshop Studio',
            'type': 'activity',
            'description': 'Creative workshops and classes',
            'rating': 4.3,
            'distance': '1.8 km',
          },
        ];
      default:
        return [
          {
            'name': 'Central Park',
            'type': 'park',
            'description': 'Beautiful park with walking trails',
            'rating': 4.6,
            'distance': '1.0 km',
          },
          {
            'name': 'City Mall',
            'type': 'shopping',
            'description': 'Shopping and entertainment complex',
            'rating': 4.4,
            'distance': '2.5 km',
          },
        ];
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cafe':
        return Icons.coffee;
      case 'restaurant':
        return Icons.restaurant;
      case 'activity':
        return Icons.sports_basketball;
      case 'park':
        return Icons.park;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.place;
    }
  }

  void _sharePlace(Map<String, dynamic> place) {
    final message = "How about we check out ${place['name']}? "
        "It's ${place['description']} and it's only ${place['distance']} away. "
        "Rating: ${place['rating']} ⭐";
  
    _messageController.text = message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: _chatPersonImage != null
                    ? MemoryImage(base64Decode(_chatPersonImage!))
                    : null,
                child: _chatPersonImage == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.chatPersonName,
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.place, color: Colors.blue),
            onPressed: _showPlaceRecommendations,
            tooltip: 'Show recommended places',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.blue),
            onPressed: _showMatchDetails,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50], // Light grey background for better contrast
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _messagesStream,
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF6C9BCF)),
                      ),
                    );
                  }

                  final messages = snapshot.data?.docs ?? [];
                  final currentUserId = _auth.currentUser?.uid;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet\nStart the conversation!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index]
                          .data() as Map<String, dynamic>;
                      final isMe = message['senderId'] == currentUserId;
                      final timestamp = message['timestamp'] as Timestamp?;
                      final timeString = timestamp != null
                          ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                          : '';

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: EdgeInsets.only(
                            bottom: 8,
                            left: isMe ? 50 : 0,
                            right: isMe ? 0 : 50,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF6C9BCF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(13),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (message['type'] == 'image')
                                        GestureDetector(
                                          onTap: () => _showFullScreenImage(
                                              message['image']),
                                          child: Container(
                                            constraints: BoxConstraints(
                                              maxHeight: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.3,
                                            ),
                                            child: Image.memory(
                                              base64Decode(message['image']),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            message['text'] ?? '',
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 4, left: 4, right: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      timeString,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        message['read'] == true
                                            ? Icons.done_all
                                            : Icons.done,
                                        size: 16,
                                        color: message['read'] == true
                                            ? const Color(0xFF6C9BCF)
                                            : Colors.grey[600],
                                      ),
                                    ],
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
                    color: Colors.black.withAlpha(13),
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library),
                    onPressed: _pickAndSendImage,
                    color: const Color(0xFF6C9BCF),
                    tooltip: 'Send image',
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    color: const Color(0xFF6C9BCF),
                    tooltip: 'Send message',
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
