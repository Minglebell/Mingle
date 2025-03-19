import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/chat_list_page.dart';
import 'package:minglev2_1/Screen/profile_display_page.dart';
import 'package:minglev2_1/Screen/searching_page.dart';

class FindMatchPage extends StatefulWidget {
  const FindMatchPage({Key? key}) : super(key: key);

  @override
  _FindMatchPageState createState() => _FindMatchPageState();
}

class _FindMatchPageState extends State<FindMatchPage> {
  int currentPageIndex = 0;
  String? selectedGender;
  List<String> selectedActivities = [];
  DateTime? selectedDateTime;
  double distance = 1.0;

  final List<String> activityOptions = [
    'Hiking', 'Reading', 'Cooking', 'Traveling',
    'Gaming', 'Yoga', 'Dancing', 'Swimming',
    'Cycling', 'Running', 'Painting', 'Photography'
  ];

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          selectedDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Find Your Activity Partner',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            Text(
              'Customize your preferences to find the perfect activity buddy.',
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
              MaterialPageRoute(builder: (context) => ProfileDisplayPage()),
            );
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gender Section
            Text(
              'Gender',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center(
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
                  underline: Container(),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Activity Section
            Text(
              'Activities',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: activityOptions.map((String activity) {
                  return ChoiceChip(
                    label: Text(
                      activity,
                      style: TextStyle(
                        color: selectedActivities.contains(activity) ? Colors.white : Colors.black),
                      ),
                    selected: selectedActivities.contains(activity),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected && selectedActivities.length < 3) {
                          selectedActivities.add(activity);
                        } else {
                          selectedActivities.remove(activity);
                        }
                      });
                    },
                    selectedColor: Colors.blue,
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20),

            // DateTime Section
            Text(
              'Date and Time',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            Center(
              child: InkWell(
                onTap: () => _selectDateTime(context),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedDateTime == null ? 'Click to select a date and time' : 'Selected Date and Time: ${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year} at ${selectedDateTime!.hour}:${selectedDateTime!.minute}',
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
            Center(
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

