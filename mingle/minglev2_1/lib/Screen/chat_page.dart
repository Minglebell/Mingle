import 'package:flutter/material.dart';
import 'dart:async';
import 'package:minglev2_1/Services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:google_place/google_place.dart';


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
  final googlePlace = GooglePlace('AIzaSyAlT7miIyYC-63raU7bT0lxoyUekhTI11o'); 
  final Map<String, List<SearchResult>> _placesCache = {};
  final Duration _cacheDuration = const Duration(hours: 1);
  final Map<String, DateTime> _cacheTimestamps = {};

  @override
  void initState() {
    super.initState();
    _loadChatPersonImage();
    _messagesStream = _chatService.getChatStream(widget.chatId);
    _setupMessagesListener();
    _setupChatListener();
    _markMessagesAsRead();
    _fetchMatchDetails();
    _chatService.updateActiveUsers(
        widget.chatId, _auth.currentUser?.uid ?? '', true);
  }

  Future<void> _loadChatPersonImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.partnerId)
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          _chatPersonImage = doc.data()?['profileImage'] as String?;
        });
      }
    } catch (e) {
      _logger.severe('Error loading chat person image: $e');
    }
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

  void _showPlaceRecommendations() async {
    final category = _matchDetails['category'] ?? '';
    final place = _matchDetails['place'] ?? '';
    
    _logger.info('Category: $category, Place: $place'); // Debug log

    if (category.isEmpty || place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category and place information not available'),
        ),
      );
      return;
    }

    // Show loading indicator with debug info
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Searching for $category in $place...'),
            ],
          ),
        );
      },
    );

    try {
      final places = await _getRecommendedPlacesWithCache(category, place);
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      if (places.isEmpty) {
        _logger.warning('No places found for query: $category in $place');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No places found for $category in $place. Try adjusting your search terms.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75, 
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
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
                          Text(
                            'Places near $place',
                            style: const TextStyle(
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
                    Expanded(
                      child: FutureBuilder<List<SearchResult>>(
                        future: _getRecommendedPlacesWithCache(category, place),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            _logger.severe('FutureBuilder error: ${snapshot.error}');
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, 
                                       size: 48, 
                                       color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading places\n${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final places = snapshot.data ?? [];
                          
                          if (places.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, 
                                       size: 48, 
                                       color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No places found for\n$category in $place',
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
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: places.length,
                            itemBuilder: (context, index) {
                              final place = places[index];
                              return Container(
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
                                    if (place.photos?.isNotEmpty ?? false)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              'https://maps.googleapis.com/maps/api/place/photo?maxwidth=100&photo_reference=${place.photos![0].photoReference}&key=AIzaSyAlT7miIyYC-63raU7bT0lxoyUekhTI11o',
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F1FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.place,
                                          color: Color(0xFF6C9BCF),
                                          size: 30,
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            place.name ?? 'Unnamed Place',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (place.formattedAddress != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              place.formattedAddress!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (place.rating != null) ...[
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
                                                  place.rating.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      _logger.severe('Error showing recommendations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding places: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<List<SearchResult>> _getRecommendedPlacesWithCache(String category, String place) async {
    final cacheKey = '$category:$place';
    final now = DateTime.now();

    // Check if we have valid cached results
    if (_placesCache.containsKey(cacheKey) &&
        _cacheTimestamps[cacheKey] != null &&
        now.difference(_cacheTimestamps[cacheKey]!) < _cacheDuration) {
      return _placesCache[cacheKey]!;
    }

    // Fetch new results
    final results = await _getRecommendedPlaces(category, place);
    
    // Cache the results
    _placesCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = now;

    return results;
  }

  Future<List<SearchResult>> _getRecommendedPlaces(String category, String place) async {
    try {
      String googlePlaceType = _mapCategoryToGoogleType(category);
      _logger.info('Searching for $googlePlaceType places in $place');

      // First, get coordinates for the place
      final locationResult = await googlePlace.search.getTextSearch(place);
      if (locationResult?.results == null || locationResult!.results!.isEmpty) {
        _logger.warning('Location not found: $place');
        return [];
      }

      final location = locationResult.results![0].geometry?.location;
      if (location == null) {
        _logger.warning('No coordinates found for: $place');
        return [];
      }

      _logger.info('Found coordinates: ${location.lat}, ${location.lng}');

      // Search for places with simplified parameters first
      final result = await googlePlace.search.getNearBySearch(
        Location(lat: location.lat, lng: location.lng),
        5000, // 5km radius
        type: googlePlaceType,
        // Removed other filters temporarily for testing
      );

      _logger.info('Search status: ${result?.status}');
      _logger.info('Results found: ${result?.results?.length ?? 0}');

      if (result?.status == 'OK' && result?.results != null) {
        // Don't filter results yet, just return them all for testing
        return result!.results!;
      }

      _logger.warning('No results found. Status: ${result?.status}');
      return [];
    } catch (e, stackTrace) {
      _logger.severe('Error fetching places: $e');
      _logger.severe('Stack trace: $stackTrace');
      return [];
    }
  }

  String _mapCategoryToGoogleType(String category) {
    // Map your categories to Google Places API types
    switch (category.toLowerCase()) {
      case 'bars':
      case 'karaoke bars':
        return 'bar';  // Make sure 'bar' is the exact type from Google Places API
      case 'parks':
        return 'park';
      case 'beaches':
        return 'natural_feature';
      case 'lakes':
        return 'natural_feature';
      case 'zoos':
        return 'zoo';
      case 'safari parks':
        return 'zoo';
      case 'amusement parks':
        return 'amusement_park';
      case 'water parks':
        return 'amusement_park';
      case 'museums':
        return 'museum';
      case 'art galleries':
        return 'art_gallery';
      case 'historical landmarks':
        return 'tourist_attraction';
      case 'temples':
        return 'place_of_worship';
      case 'movie theaters':
        return 'movie_theater';
      case 'bowling alleys':
        return 'bowling_alley';
      case 'gaming centers':
        return 'amusement_center';
      case 'live theaters':
        return 'theater';
      case 'concert venues':
        return 'stadium';
      case 'aquariums':
        return 'aquarium';
      case 'ice-skating rinks':
        return 'stadium';
      default:
        return 'point_of_interest';
    }
  }



  void _sharePlace(SearchResult place) {
    final message = "How about we check out ${place.name}? "
        "It's located at ${place.formattedAddress}"
        "${place.rating != null ? "\nRating: ${place.rating} ⭐" : ""}";
  
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
