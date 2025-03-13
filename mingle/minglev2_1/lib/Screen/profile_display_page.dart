import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/match_menu_page.dart';
import 'package:minglev2_1/Services/profile_provider.dart';
import 'package:minglev2_1/Screen/profile_edit_page.dart';

import '../Widget/bottom_navigation_bar.dart';

class ProfileDisplayPage extends ConsumerStatefulWidget {
  const ProfileDisplayPage({super.key});

  @override
  ConsumerState<ProfileDisplayPage> createState() => _ProfileDisplayPageState();
}

class _ProfileDisplayPageState extends ConsumerState<ProfileDisplayPage> {
  bool showBottomNavBar = true; // Controls visibility of the bottom nav bar
  int currentPageIndex = 2;

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
      bottomNavigationBar:
          showBottomNavBar
              ? CustomBottomNavBar(
                currentIndex: currentPageIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    currentPageIndex = index;
                  });
                  // Navigate to other pages based on the index
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => FindMatchPage()),
                    );
                  } else if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => ChatListPage()),
                    );
                  } else if (index == 2) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileDisplayPage(),
                      ),
                    );
                  }
                },
              )
              : null, // Hide the bottom nav bar
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileHeader(profile),
                    const SizedBox(height: 20),
                    _buildProfileDisplay(profile),
                    const SizedBox(height: 20),

                    // Edit Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileEditPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C9BCF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        "Edit",
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 80,
            backgroundColor: const Color(0xFF6C9BCF),
            // You can add a background image here if needed
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFA8D1F0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Name",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Center(
                      child: Text(
                        profile['name'],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Age",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Center(
                      child: Text(
                        profile['age'].toString(),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDisplay(Map<String, dynamic> profile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreferenceDisplay("Gender", profile['gender']),
          _buildPreferenceDisplay("Favourite food", profile['favourite food']),
          _buildPreferenceDisplay("Allergies", profile['allergies']),
        ],
      ),
    );
  }

  Widget _buildPreferenceDisplay(String label, List<String> preferences) {
    if (preferences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 15.0,
            runSpacing: 15.0,
            crossAxisAlignment: WrapCrossAlignment.start,
            children:
                preferences.map((preference) {
                  return Chip(
                    label: Text(
                      preference,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF333333),
                      ),
                    ),
                    backgroundColor: const Color(0xFF6C9BCF),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}