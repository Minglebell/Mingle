import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_customization_page.dart';
import 'package:minglev2_1/Screen/searching_page.dart';

class FindMatchPage extends StatefulWidget {
  const FindMatchPage({Key? key}) : super(key: key);

  @override
  _FindMatchPageState createState() => _FindMatchPageState();
}

class _FindMatchPageState extends State<FindMatchPage> {
  int currentPageIndex = 0;
  String? selectedGender;
  List<String> selectedFoods = [];
  TimeOfDay? selectedTime;
  double distance = 5.0;

  final List<String> foodOptions = [
    'Sushi', 'Pizza', 'Burger', 'Noodle',
    'Curry', 'Taco', 'Sandwich', 'Salad',
    'Soup', 'Steak', 'Fried Chicken', 'Ice Cream'
  ];

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find Your Match',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            Text(
              'Customize your preferences to find the specific partner.',
              style: TextStyle(fontSize: 16, color: Colors.black),
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
              MaterialPageRoute(builder: (context) => ChatListPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProfileEditPage()),
            );
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align headers to the start
          children: [
            // Gender Section
            Text(
              'Gender',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center( // Center the dropdown box
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: selectedGender,
                  hint: Text(
                    'Choose gender',
                    style: TextStyle(color: Colors.black),
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedGender = newValue;
                    });
                  },
                  items: <String>['Male', 'Female', 'Other'].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(color: Colors.black),
                      ),
                    );
                  }).toList(),
                  underline: Container(), // Remove the default underline
                ),
              ),
            ),
            SizedBox(height: 20),

            // Food Section
            Text(
              'Food',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center( // Center the food chips
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: foodOptions.map((String food) {
                  return ChoiceChip(
                    label: Text(
                      food,
                      style: TextStyle(
                        color: selectedFoods.contains(food) ? Colors.white : Colors.black),
                      ),
                    selected: selectedFoods.contains(food),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected && selectedFoods.length < 3) {
                          selectedFoods.add(food);
                        } else {
                          selectedFoods.remove(food);
                        }
                      });
                    },
                    selectedColor: Colors.blue,
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20),

            // Time Section
            Text(
              'Time',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center( // Center the time picker box
              child: InkWell(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedTime == null ? 'Click to select a time schedule' : 'Selected Time: ${selectedTime!.format(context)}',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Distance Section
            Text(
              'Distance',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center( // Center the slider
              child: Column(
                children: [
                  Text(
                    '${distance.round()} km',
                    style: TextStyle(fontSize: 22, color: Colors.black),
                  ),
                  Slider(
                    value: distance,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    onChanged: (double value) {
                      setState(() {
                        distance = value;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton(
        onPressed: () {
           Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => SearchingPage()),
            );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        ),
        child: Text(
          'Find Matches',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}