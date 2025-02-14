import 'package:flutter/material.dart';
import 'package:mingle/Widget/bottom_navigation_bar.dart';

class MatchInterestPage extends StatelessWidget {
  const MatchInterestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 228, 225),
      appBar: AppBar(
        title: const Text(
          'Match your interest',
          style: TextStyle(
              fontFamily: 'Itim', fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 228, 225),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select an option',
              style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Itim',
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDropdown('Categories'),
            const SizedBox(height: 16),
            _buildDropdown('Interests'),
            const SizedBox(height: 16),
            const Text(
              'Age Range',
              style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Itim',
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '18',
                  style: TextStyle(fontSize: 18, fontFamily: 'Itim'),
                ),
                Expanded(
                  child: Slider(
                    value: 21.5, // Example value
                    min: 18,
                    max: 25,
                    onChanged: (value) {
                      // Handle slider change
                    },
                  ),
                ),
                const Text(
                  '25',
                  style: TextStyle(fontSize: 18, fontFamily: 'Itim'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Distance',
              style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Itim',
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '20 km',
              style: TextStyle(fontSize: 18, fontFamily: 'Itim'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _buildChip('Badminton'),
                _buildChip('Basketball'),
                _buildChip('Thai Food'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Handle start button press
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Itim',
                      fontSize: 24),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildDropdown(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontFamily: 'Itim'),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontFamily: 'Itim'),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 194, 187),
    );
  }
}
