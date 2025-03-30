import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/custom_app_bar.dart';
import 'package:minglev2_1/services/request_matching_service.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:logging/logging.dart';

class SearchingPage extends StatefulWidget {
  final String selectedGender;
  final RangeValues ageRange;
  final double maxDistance;
  final bool isScheduledMatch;
  final List<Map<String, dynamic>>? schedules;
  final String selectedPlace;
  final String selectedCategory;

  const SearchingPage({
    super.key,
    required this.selectedGender,
    required this.ageRange,
    required this.maxDistance,
    required this.selectedPlace,
    required this.selectedCategory,
    this.isScheduledMatch = false,
    this.schedules,
  });

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage>
    with SingleTickerProviderStateMixin {
  int currentPageIndex = 0;
  late AnimationController _controller;
  late Animation<double> _animation;
  late RequestMatchingService _matchingService;
  bool _isSearching = true;
  String? _currentRequestId;
  Map<String, dynamic>? _matchedUser;
  bool _matchFound = false;
  final _logger = Logger('SearchingPage');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
    _matchingService = RequestMatchingService(context);

    _startMatching();
  }

  Future<void> _startMatching() async {
    try {
      // Create a request for the selected place
      await _matchingService.createRequest(
        place: widget.selectedPlace,
        category: widget.selectedCategory,
        gender: widget.selectedGender,
        ageRange: widget.ageRange,
        maxDistance: widget.maxDistance,
        scheduledTime: widget.isScheduledMatch && widget.schedules != null && widget.schedules!.isNotEmpty
            ? widget.schedules!.first['date'] as DateTime
            : null,
      );

      // Store the request ID
      _currentRequestId = _matchingService.currentRequestId;

      // Listen for matches
      _listenForMatches();
    } catch (e) {
      _logger.warning('Error in matching', e);
      if (mounted) {
        _showError();
      }
    }
  }

  void _listenForMatches() {
    // Set up a listener for match found events
    _matchingService.onMatchFound = (matchedUser) {
      if (mounted) {
        _onMatchFound(matchedUser);
      }
    };
  }

  void _onMatchFound(Map<String, dynamic> matchedUser) {
    if (!mounted) return;
    
    // Check if this match is for the current user
    if (matchedUser['chatId'] != null) {
      setState(() {
        _isSearching = false;
        _matchFound = true;
        _matchedUser = {
          'name': matchedUser['matchedUserName'] ?? 'Unknown',
          'age': matchedUser['matchedUserAge'] ?? 'Unknown',
          'distance': matchedUser['matchedUserDistance'] ?? '0',
          'gender': matchedUser['matchedUserGender'] ?? 'Unknown',
          'profileImage': matchedUser['matchedUserProfileImage'] ?? '',
          'chatId': matchedUser['chatId'],
        };
        _controller.stop(); // Stop the searching animation
      });
    }
  }

  void _startChat() {
    if (_matchedUser != null && _matchedUser!['chatId'] != null) {
      // Navigate to chat list page with the chat ID
      Navigator.pushReplacement(
        context,
        FadePageRoute(builder: (context) => const ChatListPage()),
      );
    }
  }

  void _showError() {
    if (!mounted) return;
    
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder: (context) => const ToastCard(
        leading: Icon(
          Icons.error,
          size: 24,
          color: Colors.red,
        ),
        title: Text(
          'An error occurred while searching for matches.',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ).show(context);
    
    // Navigate back to match menu after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          FadePageRoute(builder: (context) => const FindMatchPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // Cancel the request if it exists
    if (_currentRequestId != null) {
      _matchingService.cancelRequest(_currentRequestId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _matchFound ? 'Match Found!' : 'Searching...',
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_isSearching) ...[
              RotationTransition(
                turns: _animation,
                child: const Icon(Icons.search, size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              Text(
                'Looking for matches at ${widget.selectedPlace}...',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tips: The more distance you have, more likely you will found someone.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ] else if (_matchFound && _matchedUser != null) ...[
              const Icon(Icons.celebration, size: 50, color: Colors.green),
              const SizedBox(height: 20),
              Text(
                _matchedUser!['name'] as String,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '${_matchedUser!['age']} years old',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                '${_matchedUser!['distance']} km away',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _startChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'Start Chat',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (!_matchFound)
              ElevatedButton(
                onPressed: () async {
                  if (_currentRequestId != null) {
                    try {
                      // Store context before async gap
                      final currentContext = context;
                      await _matchingService.cancelRequest(_currentRequestId!);
                      
                      if (!mounted) return;
                      if (!currentContext.mounted) return;
                      
                      Navigator.pushReplacement(
                        currentContext,
                        FadePageRoute(builder: (context) => const FindMatchPage()),
                      );
                    } catch (e) {
                      _logger.warning('Error in canceling request', e);
                      if (!mounted) return;
                      _showError();
                    }
                  } else {
                    // Store context for the non-async path too
                    final currentContext = context;
                    if (!currentContext.mounted) return;
                    
                    Navigator.pushReplacement(
                      currentContext,
                      FadePageRoute(builder: (context) => const FindMatchPage()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              FadePageRoute(builder: (context) => const ChatListPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              FadePageRoute(builder: (context) => const ProfileDisplayPage()),
            );
          }
        },
      ),
    );
  }
}
