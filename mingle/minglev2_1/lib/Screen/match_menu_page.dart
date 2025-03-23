import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/searching_page.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:minglev2_1/Services/navigation_services.dart';

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

  // Map activities to their respective icons
  final Map<String, IconData> activityIcons = {
    'Hiking': Icons.directions_walk,
    'Reading': Icons.menu_book,
    'Cooking': Icons.restaurant,
    'Traveling': Icons.flight_takeoff,
    'Gaming': Icons.videogame_asset,
    'Yoga': Icons.self_improvement,
    'Dancing': Icons.music_note,
    'Swimming': Icons.pool,
    'Cycling': Icons.directions_bike,
    'Running': Icons.directions_run,
    'Painting': Icons.palette,
    'Photography': Icons.camera_alt,
    'Eating': Icons.fastfood,
    'Karaoke': Icons.mic,
    'Shopping': Icons.shopping_cart,
    'Watching Movies': Icons.movie,
    'Gym': Icons.fitness_center,
    'Coffee': Icons.coffee,
  };

  final List<String> activityOptions = [
    'Hiking',
    'Reading',
    'Cooking',
    'Traveling',
    'Gaming',
    'Yoga',
    'Dancing',
    'Swimming',
    'Cycling',
    'Running',
    'Painting',
    'Photography',
    'Eating',
    'Karaoke',
    'Shopping',
    'Watching Movies',
    'Gym',
    'Coffee',
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Customize your preferences to find the perfect activity buddy.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
      bottomNavigationBar: CustomBottomNavBar(
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade100, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gender Section
              Text(
                'Select Gender',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedGender,
                    hint: Text(
                      'Choose gender',
                      style: TextStyle(color: Colors.black54),
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedGender = newValue;
                      });
                    },
                    items:
                        <String>[
                          'Male',
                          'Female',
                          'Other',
                        ].map<DropdownMenuItem<String>>((String value) {
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
                'Select Activities (up to 3)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children:
                      activityOptions.map((String activity) {
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                activityIcons[activity],
                                size: 20,
                                color:
                                    selectedActivities.contains(activity)
                                        ? Colors.white
                                        : Colors.black,
                              ),
                              SizedBox(width: 8),
                              Text(
                                activity,
                                style: TextStyle(
                                  color:
                                      selectedActivities.contains(activity)
                                          ? Colors.white
                                          : Colors.black,
                                ),
                              ),
                            ],
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
                          backgroundColor: Colors.grey[200],
                        );
                      }).toList(),
                ),
              ),
              SizedBox(height: 20),

              // DateTime Section
              Text(
                'Select Date and Time',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: InkWell(
                  onTap: () => _selectDateTime(context),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      selectedDateTime == null
                          ? 'Click to select a date and time'
                          : 'Selected Date and Time: ${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year} at ${selectedDateTime!.hour}:${selectedDateTime!.minute}',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Distance Section
              Text(
                'Set Distance (in km)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 20),
        child: ElevatedButton(
          onPressed: () {
            // add conditions if not all fields are selected
            if (selectedGender == null ||
                selectedActivities.isEmpty ||
                selectedDateTime == null) {
              DelightToastBar(
                autoDismiss: true,
                snackbarDuration: const Duration(seconds: 3),
                builder:
                    (context) => ToastCard(
                      leading: const Icon(
                        Icons.error,
                        size: 24,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Please select all fields',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
              ).show(context);
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => SearchingPage()),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            'Find Matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
