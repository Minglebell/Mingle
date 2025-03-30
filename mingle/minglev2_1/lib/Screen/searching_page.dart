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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
        scheduledTime: widget.isScheduledMatch &&
                widget.schedules != null &&
                widget.schedules!.isNotEmpty
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
      // Clear SharedPreferences only after a successful match
      _clearPreferences();

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

  Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Only clear matching preferences, keep schedules
    await prefs.remove('selectedGender');
    await prefs.remove('selectedCategory');
    await prefs.remove('selectedPlace');
    await prefs.remove('ageRangeStart');
    await prefs.remove('ageRangeEnd');
    await prefs.remove('distance');
  }

  void _startChat() async {
    if (_matchedUser != null && _matchedUser!['chatId'] != null) {
      // Navigate to chat list page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          FadePageRoute(builder: (context) => const ChatListPage()),
        );
      }
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isSearching) ...[
                // Searching Animation and Info
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      RotationTransition(
                        turns: _animation,
                        child: const Icon(
                          Icons.search,
                          size: 64,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Looking for matches at ${widget.selectedPlace}...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tip: Increasing your distance range improves your chances of finding a match!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_matchFound && _matchedUser != null) ...[
                // Match Found UI
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.celebration,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 24),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            _matchedUser!['profileImage'].isNotEmpty
                                ? MemoryImage(
                                    base64Decode(_matchedUser!['profileImage']))
                                : null,
                        child: _matchedUser!['profileImage'].isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _matchedUser!['name'] as String,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInfoChip(
                            Icons.cake,
                            '${_matchedUser!['age']} years',
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.location_on,
                            '${_matchedUser!['distance']} km',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _startChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Start Chat',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (!_matchFound)
                ElevatedButton(
                  onPressed: () async {
                    if (_currentRequestId != null) {
                      try {
                        final currentContext = context;
                        await _matchingService
                            .cancelRequest(_currentRequestId!);

                        if (!mounted) return;
                        if (!currentContext.mounted) return;

                        Navigator.pushReplacement(
                          currentContext,
                          FadePageRoute(
                              builder: (context) => const FindMatchPage()),
                        );
                      } catch (e) {
                        _logger.warning('Error in canceling request', e);
                        if (!mounted) return;
                        _showError();
                      }
                    } else {
                      final currentContext = context;
                      if (!currentContext.mounted) return;

                      Navigator.pushReplacement(
                        currentContext,
                        FadePageRoute(
                            builder: (context) => const FindMatchPage()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close),
                      SizedBox(width: 8),
                      Text(
                        'Cancel Search',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
