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
  _SearchingPageState createState() => _SearchingPageState();
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
      print('Error in matching: $e');
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
    
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder: (context) => ToastCard(
        leading: const Icon(
          Icons.info,
          size: 24,
          color: Colors.orange,
        ),
        title: Text(
          'No matches found. Try adjusting your preferences.',
          style: const TextStyle(
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
          FadePageRoute(builder: (context) => FindMatchPage()),
        );
      }
    });
  }

  void _showError() {
    if (!mounted) return;
    
    DelightToastBar(
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 3),
      builder: (context) => ToastCard(
        leading: const Icon(
          Icons.error,
          size: 24,
          color: Colors.red,
        ),
        title: Text(
          'An error occurred while searching for matches.',
          style: const TextStyle(
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
          FadePageRoute(builder: (context) => FindMatchPage()),
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
        title: 'Searching...',
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_isSearching) ...[
              RotationTransition(
                turns: _animation,
                child: Icon(Icons.search, size: 50, color: Colors.blue),
              ),
              SizedBox(height: 20),
              Text(
                'Looking for matches at ${widget.selectedPlace}...',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Tips: The more distance you have, more likely you will found someone.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ] else if (_matchedUser != null) ...[
              Icon(Icons.celebration, size: 50, color: Colors.green),
              SizedBox(height: 20),
              Text(
                _matchedUser!['name'],
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '${_matchedUser!['age']} years old',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '${_matchedUser!['distance'].toStringAsFixed(1)} km away',
                style: TextStyle(fontSize: 16),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_currentRequestId != null) {
                  try {
                    await _matchingService.cancelRequest(_currentRequestId!);
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        FadePageRoute(builder: (context) => FindMatchPage()),
                      );
                    }
                  } catch (e) {
                    print('Error canceling request: $e');
                    if (mounted) {
                      _showError();
                    }
                  }
                } else {
                  Navigator.pushReplacement(
                    context,
                    FadePageRoute(builder: (context) => FindMatchPage()),
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
              child: Text(
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
              FadePageRoute(builder: (context) => ChatListPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              FadePageRoute(builder: (context) => ProfileDisplayPage()),
            );
          }
        },
      ),
    );
  }
}