import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Screen/found_page.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/custom_app_bar.dart';
import 'package:minglev2_1/services/request_matching_service.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:logging/logging.dart';

final _logger = Logger('SearchingPage');

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
  final bool _isSearching = true;
  String? _currentRequestId;
  Map<String, dynamic>? _matchedUser;

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
    } on Exception catch (e) {
      _logger.severe('Error in matching: $e');
      if (mounted) {
        _showError();
      }
    }
  }

  void _listenForMatches() {
    // The matching service will handle the match creation and navigation
    // through the _handleMatch callback
  }

  void _showNoMatchesFound() {
    if (!mounted) return;
    
    BuildContext? contextRef = context;
    if (!contextRef.mounted) return;

    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder: (context) => const ToastCard(
        leading: Icon(
          Icons.info,
          size: 24,
          color: Colors.orange,
        ),
        title: Text(
          'No matches found. Try adjusting your preferences.',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ).show(contextRef);

    // Navigate back to match menu after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (!contextRef.mounted) return;
      
      Navigator.pushReplacement(
        contextRef,
        FadePageRoute(builder: (context) => const FindMatchPage()),
      );
    });
  }

  void _showError() {
    if (!mounted) return;
    
    BuildContext? contextRef = context;
    if (!contextRef.mounted) return;

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
    ).show(contextRef);

    // Navigate back to match menu after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (!contextRef.mounted) return;
      
      Navigator.pushReplacement(
        contextRef,
        FadePageRoute(builder: (context) => const FindMatchPage()),
      );
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
      appBar: const CustomAppBar(
        title: 'Searching...',
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
            ] else if (_matchedUser != null) ...[
              const  Icon(Icons.celebration, size: 50, color: Colors.green),
              const SizedBox(height: 20),
              Text(
                _matchedUser!['name'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '${_matchedUser!['age']} years old',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                '${_matchedUser!['distance'].toStringAsFixed(1)} km away',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_currentRequestId != null) {
                  try {
                    final contextRef = context;
                    await _matchingService.cancelRequest(_currentRequestId!);
                    if (mounted && contextRef.mounted) {
                      Navigator.pushReplacement(
                        contextRef,
                        FadePageRoute(builder: (context) => const FindMatchPage()),
                      );
                    }
                  } catch (e) {
                    _logger.severe('Error canceling request: $e');
                    if (mounted) {
                      _showError();
                    }
                  }
                } else {
                  Navigator.pushReplacement(
                    context,
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

