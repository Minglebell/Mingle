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
  List<String> selectedChips = [];

  final List<String> genders = ['Male', 'Female', 'Any genders'];
  final List<String> categories = ['Sports', 'Music', 'Food', 'Technology'];
  final List<String> interests = ['Football', 'Guitar', 'Sushi', 'Coding'];
  final List<String> chips = ['Badminton', 'Basketball', 'Thai Food'];

  bool isChipSelected(String label) => selectedChips.contains(label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Match your interest',
          style: TextStyle(
              fontFamily: 'Itim', fontSize: 26, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(  // Fix dropdown overlapping issue
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Select Gender'),
              _buildDropdown(genders, selectedGender, (value) {
                setState(() => selectedGender = value);
              }),
              const SizedBox(height: 20),

              _buildSectionTitle('Select Category'),
              _buildDropdown(categories, selectedCategory, (value) {
                setState(() => selectedCategory = value);
              }),
              const SizedBox(height: 20),

              _buildSectionTitle('Select Interest'),
              _buildDropdown(interests, selectedInterest, (value) {
                setState(() => selectedInterest = value);
              }),
              const SizedBox(height: 20),

              _buildSectionTitle('Age Range'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelText: 'Min Age',
                        filled: true,
                        fillColor: Colors.white,  // Fixed background color
                      ),
                      onChanged: (value) {
                        double? age = double.tryParse(value);
                        if (age != null && age >= 18 && age <= 100) {
                          setState(() => minAge = age);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelText: 'Max Age',
                        filled: true,
                        fillColor: Colors.white,  // Fixed background color
                      ),
                      onChanged: (value) {
                        double? age = double.tryParse(value);
                        if (age != null && age >= 18 && age <= 100) {
                          setState(() => maxAge = age);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('Select Interests'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: chips.map((chip) => _buildChip(chip)).toList(),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle start button press
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFB6AE), // Changed button color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontFamily: 'Itim', fontWeight: FontWeight.bold),
      ),
    );
  }

    Widget _buildDropdown(List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      value: selectedValue,
      hint: const Text('Select', style: TextStyle(fontSize: 18, fontFamily: 'Itim')),
      
      // Ensures selected item stays in the dropdown box
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((String item) {
          return Text(
            item,
            style: const TextStyle(fontSize: 18, fontFamily: 'Itim'),
          );
        }).toList();
      },

      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 18, fontFamily: 'Itim')),
        );
      }).toList(),

      onChanged: onChanged,
      isExpanded: true, // Ensures text is not cut off
    );
  }

  Widget _buildChip(String label) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 16, fontFamily: 'Itim')),
      selected: isChipSelected(label),
      onSelected: (selected) {
        setState(() {
          selected ? selectedChips.add(label) : selectedChips.remove(label);
        });
      },
      selectedColor: Color(0xFFFFB6AE),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
