import 'package:flutter/material.dart';
import 'package:mingle/Widget/bottom_navigation_bar.dart';

class MatchInterestPage extends StatefulWidget {
  const MatchInterestPage({super.key});

  @override
  _MatchInterestPageState createState() => _MatchInterestPageState();
}

class _MatchInterestPageState extends State<MatchInterestPage> {
  String? selectedGender;
  String? selectedCategory;
  String? selectedInterest;
  double minAge = 18;
  double maxAge = 25;
  bool isChipSelected(String label) => selectedChips.contains(label);
  List<String> selectedChips = [];

  final List<String> genders = ['Male', 'Female', 'Any genders'];
  final List<String> categories = ['Sports', 'Music', 'Food', 'Technology'];
  final List<String> interests = ['Football', 'Guitar', 'Sushi', 'Coding'];
  final List<String> chips = ['Badminton', 'Basketball', 'Thai Food'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Match your interest',
          style: TextStyle(
              fontFamily: 'Itim', fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFF0F4F8),
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
                  fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDropdown('Genders', genders, selectedGender, (value) {
              setState(() => selectedGender = value);
            }),
            const SizedBox(height: 16),
            _buildDropdown('Categories', categories, selectedCategory, (value) {
              setState(() => selectedCategory = value);
            }),
            const SizedBox(height: 16),
            _buildDropdown('Interests', interests, selectedInterest, (value) {
              setState(() => selectedInterest = value);
            }),
            const SizedBox(height: 16),
            const Text(
              'Age Range',
              style: TextStyle(
                  fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Min Age',
                    ),
                    onChanged: (value) {
                      setState(() => minAge = double.tryParse(value) ?? 18);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Max Age',
                    ),
                    onChanged: (value) {
                      setState(() => maxAge = double.tryParse(value) ?? 25);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Interests',
              style: TextStyle(
                  fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: chips.map((chip) => _buildChip(chip)).toList(),
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
                      color: Colors.white, fontFamily: 'Itim', fontSize: 24),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildDropdown(
      String label, List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      value: selectedValue,
      hint: Text(label, style: const TextStyle(fontSize: 18, fontFamily: 'Itim')),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 18, fontFamily: 'Itim')),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildChip(String label) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 16, fontFamily: 'Itim')),
      selected: isChipSelected(label),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            selectedChips.add(label);
          } else {
            selectedChips.remove(label);
          }
        });
      },
      selectedColor: Color(0xFFA8D1F0),
    );
  }
}
