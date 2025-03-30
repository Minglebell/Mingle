import 'dart:convert';
import 'package:delightful_toast/delight_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Services/database_services.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'dart:math' as math;

class ProfileDisplayPage extends ConsumerStatefulWidget {
  final String? userId; // Optional - if null, show current user's profile
  final bool showBottomNav; // Whether to show bottom navigation
  const ProfileDisplayPage({super.key, this.userId, this.showBottomNav = true});

  @override
  ConsumerState<ProfileDisplayPage> createState() => _ProfileDisplayPageState();
}

class _ProfileDisplayPageState extends ConsumerState<ProfileDisplayPage>
    with SingleTickerProviderStateMixin {
  final _logger = Logger('ProfileDisplayPage');
  bool showBottomNavBar = true;
  int currentPageIndex = 2;
  String? _imageUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  double? _distance;
  double? _userRating;
  bool _isRatingSubmitting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Increased duration for smoother animation
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut, // Smoother curve
    );

    // Fetch profile data and image when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfileData();
      await _loadProfileImage();
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
      _calculateDistance();
      _loadUserRating(); // Add this line
    });
  }

  Future<void> _loadProfileData() async {
    try {
      final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (doc.exists) {
          setState(() {
            _userProfile = doc.data();
          });
        }
      }
    } catch (e) {
      _logger.warning('Error loading profile data: $e');
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Get from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        final data = doc.data();
        if (data != null && data['profileImage'] != null) {
          setState(() {
            _imageUrl = data['profileImage'];
          });
        }
      }
    } catch (e) {
      _logger.warning('Error loading profile image: $e');
    }
  }

  Future<void> _calculateDistance() async {
    if (widget.userId == null) return; // Don't calculate for own profile

    try {
      // Get current user's location
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      
      // Get partner's location
      final partnerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final currentUserData = currentUserDoc.data();
      final partnerData = partnerDoc.data();

      if (currentUserData != null && 
          partnerData != null && 
          currentUserData['location'] != null && 
          partnerData['location'] != null) {
        
        final currentLocation = currentUserData['location'] as Map<String, dynamic>;
        final partnerLocation = partnerData['location'] as Map<String, dynamic>;

        final distance = _calculateDistanceBetween(
          currentLocation['latitude'] as double,
          currentLocation['longitude'] as double,
          partnerLocation['latitude'] as double,
          partnerLocation['longitude'] as double,
        );

        setState(() {
          _distance = distance;
        });
      }
    } catch (e) {
      _logger.warning('Error calculating distance: $e');
    }
  }

  double _calculateDistanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  // Add this new method to load existing rating
  Future<void> _loadUserRating() async {
    if (widget.userId == null) return; 
    
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final ratingDoc = await FirebaseFirestore.instance
          .collection('ratings')
          .doc('${currentUserId}_${widget.userId}')
          .get();

      if (ratingDoc.exists) {
        setState(() {
          _userRating = ratingDoc.data()?['rating']?.toDouble();
        });
      }
    } catch (e) {
      _logger.warning('Error loading user rating: $e');
    }
  }

  // Add this new method to save rating
  Future<void> _saveRating(double rating) async {
    if (widget.userId == null) return;
    
    setState(() {
      _isRatingSubmitting = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Save the rating
      await FirebaseFirestore.instance
          .collection('ratings')
          .doc('${currentUserId}_${widget.userId}')
          .set({
        'fromUserId': currentUserId,
        'toUserId': widget.userId,
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the average rating in the user's profile
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('toUserId', isEqualTo: widget.userId)
          .get();

      double totalRating = 0;
      int ratingCount = ratingsSnapshot.docs.length;

      for (var doc in ratingsSnapshot.docs) {
        totalRating += doc.data()['rating'];
      }

      double averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;

      // Use set with merge to handle both new and existing users
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
        'averageRating': averageRating,
        'ratingCount': ratingCount,
      }, SetOptions(merge: true)); // This will merge with existing data

      setState(() {
        _userRating = rating;
      });

      if (mounted) {
        DelightToastBar(
          autoDismiss: true,
          snackbarDuration: const Duration(seconds: 3),
          builder: (context) => const Card(
            child: ListTile(
              leading: Icon(
                Icons.check_circle,
                size: 24,
                color: Colors.green,
              ),
              title: Text(
                'Rating saved successfully',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ).show(context);
      }
    } catch (e) {
      _logger.severe('Error saving rating: $e');
      if (mounted) {
        DelightToastBar(
          autoDismiss: true,
          snackbarDuration: const Duration(seconds: 3),
          builder: (context) => Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.error,
                size: 24,
                color: Colors.red,
              ),
              title: Text(
                'Failed to save rating: $e',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ).show(context);
      }
    } finally {
      setState(() {
        _isRatingSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _userProfile ?? ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      bottomNavigationBar: widget.showBottomNav
          ? CustomBottomNavBar(
              currentIndex: currentPageIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  currentPageIndex = index;
                });
                if (index == 0) {
                  NavigationService().navigateToReplacement('/match');
                } else if (index == 1) {
                  NavigationService().navigateToReplacement('/chatList');
                } else if (index == 2) {
                  NavigationService().navigateToReplacement('/profile');
                }
              },
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C9BCF)),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(), // Smoother scrolling
                slivers: [
                  SliverAppBar(
                    expandedHeight: 450.0, // Slightly increased for better spacing
                    floating: false,
                    pinned: true,
                    stretch: true, // Enable stretching
                    backgroundColor: const Color(0xFF6C9BCF),
                    flexibleSpace: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double percentage = ((constraints.maxHeight - kToolbarHeight) /
                            (450.0 - kToolbarHeight))
                            .clamp(0.0, 1.0);
                        return FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF6C9BCF),
                                  Color(0xFF4A90E2),
                                ],
                              ),
                            ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: percentage,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 60 * percentage),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha((51 * percentage).toInt()),
                                          blurRadius: 15 * percentage,
                                          offset: Offset(0, 5 * percentage),
                                        ),
                                      ],
                                    ),
                                    child: Hero(
                                      tag: 'profile-${widget.userId ?? "current"}',
                                      child: CircleAvatar(
                                        radius: 75 * percentage,
                                        backgroundColor: Colors.white,
                                        backgroundImage: _imageUrl != null
                                            ? MemoryImage(base64Decode(_imageUrl!))
                                            : null,
                                        child: _imageUrl == null
                                            ? Icon(
                                                Icons.person,
                                                size: 75 * percentage,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: TextStyle(
                                      fontFamily: 'Itim',
                                      fontSize: 28 * percentage,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    child: Text(profile['name'] ?? 'No Name'),
                                  ),
                                  const SizedBox(height: 16),
                                  // Info Cards with animated container
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16 * percentage,
                                      vertical: 8 * percentage,
                                    ),
                                    child: Column(
                                      children: [
                                        // Gender and Age Row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if ((profile['gender'] as List<dynamic>?)?.isNotEmpty ?? false)
                                              Expanded(
                                                child: _buildInfoCard(
                                                  "Gender: ${(profile['gender'] as List<dynamic>).first}",
                                                  percentage,
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            if (profile['age']?.isNotEmpty ?? false)
                                              Expanded(
                                                child: _buildInfoCard(
                                                  "Age: ${profile['age']}",
                                                  percentage,
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Distance Card
                                        if (_distance != null && widget.userId != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: _buildInfoCard(
                                              "Distance: ${_distance!.toStringAsFixed(1)} km",
                                              percentage,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Add Rating Widget if viewing another user's profile
                          if (widget.userId != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              margin: const EdgeInsets.only(bottom: 16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withAlpha(25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Color(0xFF6C9BCF),
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Rate this User",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (index) {
                                      return GestureDetector(
                                        onTap: _isRatingSubmitting
                                            ? null
                                            : () => _saveRating(index + 1),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Icon(
                                            _userRating != null &&
                                                    _userRating! > index
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 40,
                                            color: const Color(0xFF6C9BCF),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  if (_isRatingSubmitting) ...[
                                    const SizedBox(height: 16),
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            margin: const EdgeInsets.only(bottom: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withAlpha(25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.edit_note,
                                      color: Color(0xFF6C9BCF),
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Bio",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  profile['bio']?.isNotEmpty == true
                                      ? profile['bio'] as String
                                      : "This user hasn't written a bio yet.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: profile['bio']?.isNotEmpty == true
                                        ? const Color(0xFF666666)
                                        : Colors.grey,
                                    height: 1.5,
                                    fontStyle: profile['bio']?.isNotEmpty == true
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildProfileDisplay(profile),
                          const SizedBox(height: 24),
                          if (widget.userId == null) Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C9BCF), Color(0xFF4A90E2)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C9BCF).withAlpha(76),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                NavigationService().navigateToReplacement('/editProfile');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Edit Profile",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (widget.userId == null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE74C3C),
                                    Color(0xFFC0392B)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFFE74C3C).withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Show confirmation dialog
                                  final bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Confirm Logout'),
                                        content: const Text(
                                            'Are you sure you want to logout?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Logout'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    // Clear shared preferences and navigate to login
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.clear();
                                    if (context.mounted) {
                                      NavigationService()
                                          .navigateToReplacement('/');
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Logout",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String text, double percentage) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: 16 * percentage,
        vertical: 8 * percentage,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((51 * percentage).toInt()),
        borderRadius: BorderRadius.circular(20 * percentage),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          fontSize: 18 * percentage,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
        child: Text(text),
      ),
    );
  }

  Widget _buildProfileDisplay(Map<String, dynamic> profile) {
    final List<String> preferenceSections = [
      "Religion",
      "Budget level",
      "Education level",
      "Relationship Status",
      "Smoking",
      "Alcoholic",
      "Allergies",
      "Physical Activity level",
      "Transportation",
      "Pet",
      "Personality",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: preferenceSections.map((section) {
        final preferences =
            (profile[section.toLowerCase()] as List<dynamic>?) ?? [];
        return Column(
          children: [
            _buildPreferenceDisplay(section, List<String>.from(preferences)),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPreferenceDisplay(String label, List<String> preferences) {
    if (preferences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForLabel(label),
                color: const Color(0xFF6C9BCF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: preferences.map((preference) {
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C9BCF), Color(0xFF4A90E2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  preference,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'gender':
        return Icons.person;
      case 'religion':
        return Icons.church;
      case 'budget level':
        return Icons.attach_money;
      case 'education level':
        return Icons.school;
      case 'relationship status':
        return Icons.favorite;
      case 'smoking':
        return Icons.smoking_rooms;
      case 'alcoholic':
        return Icons.local_bar;
      case 'allergies':
        return Icons.health_and_safety;
      case 'physical activity level':
        return Icons.fitness_center;
      case 'transportation':
        return Icons.directions_car;
      case 'pet':
        return Icons.pets;
      case 'personality':
        return Icons.psychology;
      default:
        return Icons.label;
    }
  }
}
