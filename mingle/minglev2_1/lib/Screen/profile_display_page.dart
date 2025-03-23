import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Services/database_services.dart';
import 'package:minglev2_1/Services/navigation_services.dart';

import '../Widget/bottom_navigation_bar.dart';

class ProfileDisplayPage extends ConsumerStatefulWidget {
  const ProfileDisplayPage({super.key});

  @override
  ConsumerState<ProfileDisplayPage> createState() => _ProfileDisplayPageState();
}

class _ProfileDisplayPageState extends ConsumerState<ProfileDisplayPage> {
  bool showBottomNavBar = true; // Controls visibility of the bottom nav bar
  int currentPageIndex = 2;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    // Fetch profile data when the page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).fetchProfile();
    });
  }


  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      bottomNavigationBar: showBottomNavBar
          ? CustomBottomNavBar(
              currentIndex: currentPageIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  currentPageIndex = index;
                });
                // Navigate to other pages based on the index
                if (index == 0) {
                  NavigationService().navigateToReplacement('/match');
                } else if (index == 1) {
                  NavigationService().navigateToReplacement('/search');
                } else if (index == 2) {
                  NavigationService().navigateToReplacement('/profile');
                }
              },
            )
          : null, // Hide the bottom nav bar
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header
              _buildProfileHeader(profile),
              const SizedBox(height: 20),

              // Profile Details
              _buildProfileDisplay(profile),
              const SizedBox(height: 20),

              // Edit Button
              ElevatedButton(
                onPressed: () {
                  NavigationService().navigateToReplacement('/editProfile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C9BCF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Edit",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF6C9BCF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white,
            backgroundImage:
                _imagePath != null ? FileImage(File(_imagePath!)) : null,
            child: _imagePath == null
                ? const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            profile['name'],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Age: ${profile['age']}",
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDisplay(Map<String, dynamic> profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreferenceDisplay("Gender", profile['gender']),
        const SizedBox(height: 16),
        _buildPreferenceDisplay("Interests", profile['interests']),
        const SizedBox(height: 16),
        _buildPreferenceDisplay("Preferences", profile['preferences']),
        const SizedBox(height: 16),
        _buildPreferenceDisplay(
            "Favourite Activities", profile['favourite activities']),
        const SizedBox(height: 16),
        _buildPreferenceDisplay("Alcoholic", profile['alcoholic']),
        const SizedBox(height: 16),
        _buildPreferenceDisplay("Smoking", profile['smoking']),
      ],
    );
  }

  Widget _buildPreferenceDisplay(String label, List<String> preferences) {
    if (preferences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: preferences.map((preference) {
                return Chip(
                  label: Text(
                    preference,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF333333),
                    ),
                  ),
                  backgroundColor: const Color(0xFFA8D1F0),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}