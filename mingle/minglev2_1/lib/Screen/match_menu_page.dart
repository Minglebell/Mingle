import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/searching_page.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/custom_app_bar.dart';
import 'dart:convert';

class FindMatchPage extends StatefulWidget {
  const FindMatchPage({super.key});

  @override
  _FindMatchPageState createState() => _FindMatchPageState();
}

class _FindMatchPageState extends State<FindMatchPage> {
  int currentPageIndex = 0;
  String? selectedGender;
  String? selectedCategory;
  String? selectedPlace;
  bool isScheduledMatch = false;
  List<Map<String, dynamic>> schedules = [];
  RangeValues ageRange = const RangeValues(20, 30);
  double distance = 10.0;

  // Gender options from user_data
  final List<String> genderOptions = [
    "Male",
    "Female",
    "Non-binary",
    "Transgender",
    "LGBTQ+",
    "Other"
  ];

  // Time ranges for different parts of the day
  final Map<String, Map<String, dynamic>> timeRanges = {
    'Dawn (00:00-06:00)': {
      'start': 0,
      'end': 6,
      'icon': Icons.bedtime,
    },
    'Morning (06:00-12:00)': {
      'start': 6,
      'end': 12,
      'icon': Icons.wb_sunny,
    },
    'Afternoon (12:00-18:00)': {
      'start': 12,
      'end': 18,
      'icon': Icons.wb_twighlight,
    },
    'Evening (18:00-24:00)': {
      'start': 18,
      'end': 24,
      'icon': Icons.nights_stay,
    },
  };

  // Place categories data
  final Map<String, List<String>> placeData = {
    "Outdoor_Nature": [
      "Parks", "Beaches", "Lakes", "Zoos", "Safari parks",
      "Amusement parks", "Water parks",
    ],
    "Arts_Culture_Historical_Sites": [
      "Museums", "Art galleries", "Historical landmarks", "Temples",
    ],
    "Entertainment_Recreation": [
      "Movie theaters", "Bowling alleys", "Escape rooms", "Gaming centers",
      "Live theaters", "Concert venues", "Karaoke bars", "Aquariums",
      "Ice-skating rinks",
    ],
    "Dining_Cafes": [
      "Thai restaurants", "Italian restaurants", "Japanese restaurants",
      "Chinese restaurants", "Korean restaurants", "Indian restaurants",
      "Vegan restaurants", "Buffet restaurants", "Seafood restaurants",
      "Thai barbecue restaurants", "Korean barbecue restaurants",
      "Japanese barbecue restaurants", "Thai-style hot pot restaurants",
      "Chinese hot pot Restaurants", "Japanese hot pot restaurants",
      "Northeastern Thai restaurants", "Steak restaurant", "Sushi restaurant",
      "Dessert cafes", "Coffee shops"
    ],
    "Nightlife_Bars": [
      "Bars", "Cocktail bars", "Pubs", "Wine bars",
    ],
    "Shopping": [
      "Shopping malls", "Markets", "Night markets", "Floating markets",
    ],
  };

  // Map categories to their respective icons
  final Map<String, IconData> categoryIcons = {
    'Outdoor_Nature': Icons.nature_people,
    'Arts_Culture_Historical_Sites': Icons.museum,
    'Entertainment_Recreation': Icons.sports_esports,
    'Dining_Cafes': Icons.restaurant,
    'Nightlife_Bars': Icons.local_bar,
    'Shopping': Icons.shopping_bag,
  };

  // Add new variables for schedule details dialog
  bool _showScheduleDetails = false;

  // Function to check if schedule already exists
  bool _isScheduleExists(DateTime date, String timeRange) {
    return schedules.any((schedule) =>
        schedule['date'].year == date.year &&
        schedule['date'].month == date.month &&
        schedule['date'].day == date.day &&
        schedule['timeRange'] == timeRange);
  }

  // Function to check if time range is valid for current day
  bool _isValidTimeRange(DateTime date, String timeRange) {
    if (date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day) {
      int currentHour = DateTime.now().hour;
      int rangeStart = timeRanges[timeRange]!['start'] as int;
      return currentHour < rangeStart;
    }
    return true;
  }

  Future<void> _addSchedule(BuildContext context) async {
    if (schedules.length >= 5) {
      DelightToastBar(
        autoDismiss: true,
        snackbarDuration: const Duration(seconds: 3),
        builder: (context) => ToastCard(
          leading: const Icon(
            Icons.warning,
            size: 24,
            color: Colors.orange,
          ),
          title: Text(
            'Maximum 5 schedules allowed',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ).show(context);
      return;
    }

    // Check if required fields are selected before allowing schedule addition
    if (selectedCategory == null || selectedPlace == null || selectedGender == null) {
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
            'Please select category, place, and gender before adding schedule',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ).show(context);
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    
    if (picked != null) {
      String? selectedTime;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Select Time Range'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: timeRanges.entries.map((entry) {
                  bool isValid = _isValidTimeRange(picked, entry.key);
                  bool exists = _isScheduleExists(picked, entry.key);
                  
                  return ListTile(
                    leading: Icon(
                      entry.value['icon'],
                      color: (!isValid || exists) ? Colors.grey : Colors.blue,
                    ),
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        color: (!isValid || exists) ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: !isValid 
                      ? Text('Time range already passed', style: TextStyle(color: Colors.red))
                      : exists 
                        ? Text('Schedule already exists', style: TextStyle(color: Colors.orange))
                        : null,
                    enabled: isValid && !exists,
                    onTap: () {
                      selectedTime = entry.key;
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      );

      if (selectedTime != null && selectedCategory != null && selectedPlace != null && selectedGender != null) {
        setState(() {
          schedules.add({
            'date': picked,
            'timeRange': selectedTime,
            'category': selectedCategory,
            'place': selectedPlace,
            'gender': selectedGender,
            'ageRange': {
              'start': ageRange.start,
              'end': ageRange.end,
            },
            'distance': distance,
          });
        });
      }
    }
  }

  // Function to show schedule details
  void _showScheduleDetailsDialog(BuildContext context, Map<String, dynamic> schedule) {
    if (schedule['timeRange'] == null || schedule['category'] == null || 
        schedule['place'] == null || schedule['gender'] == null || 
        schedule['date'] == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(timeRanges[schedule['timeRange']]!['icon'], color: Colors.blue),
              SizedBox(width: 8),
              Text('Schedule Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text('Date'),
                  subtitle: Text(
                    '${schedule['date'].day}/${schedule['date'].month}/${schedule['date'].year}',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.access_time),
                  title: Text('Time Range'),
                  subtitle: Text(schedule['timeRange'] ?? ''),
                ),
                ListTile(
                  leading: Icon(categoryIcons[schedule['category']] ?? Icons.category),
                  title: Text('Category'),
                  subtitle: Text(_formatCategory(schedule['category'])),
                ),
                ListTile(
                  leading: Icon(Icons.place),
                  title: Text('Place'),
                  subtitle: Text(schedule['place'] ?? ''),
                ),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Preferred Gender'),
                  subtitle: Text(schedule['gender'] ?? ''),
                ),
                ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Age Range'),
                  subtitle: Text('${schedule['ageRange']?['start']?.round() ?? 20} - ${schedule['ageRange']?['end']?.round() ?? 30} years'),
                ),
                ListTile(
                  leading: Icon(Icons.social_distance),
                  title: Text('Distance'),
                  subtitle: Text('${(schedule['distance'] ?? 10).round()} km'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _removeSchedule(int index) {
    setState(() {
      schedules.removeAt(index);
    });
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Find Partner',
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
              // Category Section
              Text(
                'Select Category',
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
                  children: placeData.keys.map((String category) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcons[category] ?? Icons.place,
                            size: 20,
                            color: selectedCategory == category
                                ? Colors.white
                                : Colors.black,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatCategory(category),
                            style: TextStyle(
                              color: selectedCategory == category
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      selected: selectedCategory == category,
                      onSelected: (bool selected) {
                        setState(() {
                          selectedCategory = selected ? category : null;
                          selectedPlace = null; // Reset selected place when category changes
                        });
                      },
                      selectedColor: Colors.blue,
                      backgroundColor: Colors.grey[200],
                    );
                  }).toList(),
                ),
              ),
              if (selectedCategory != null) ...[
                SizedBox(height: 20),
                Text(
                  'Select Place',
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
                    children: placeData[selectedCategory]!.map((String place) {
                      return ChoiceChip(
                        label: Text(
                          place,
                          style: TextStyle(
                            color: selectedPlace == place
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        selected: selectedPlace == place,
                        onSelected: (bool selected) {
                          setState(() {
                            selectedPlace = selected ? place : null;
                          });
                        },
                        selectedColor: Colors.blue,
                        backgroundColor: Colors.grey[200],
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Schedule Section
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Switch(
                    value: isScheduledMatch,
                    onChanged: (bool value) {
                      setState(() {
                        isScheduledMatch = value;
                        if (!value) {
                          schedules.clear();
                        }
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              SizedBox(height: 10),
              if (isScheduledMatch) ...[
                Center(
                  child: Column(
                    children: [
                      // Schedule list
                      ...schedules.asMap().entries.map((entry) {
                        final index = entry.key;
                        final schedule = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(timeRanges[schedule['timeRange']]!['icon'], 
                                     color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  '${schedule['date'].day}/${schedule['date'].month}/${schedule['date'].year} - ${schedule['timeRange']}',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18),
                                  onPressed: () => _removeSchedule(index),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      // Add schedule button
                      if (schedules.length < 5)
                        TextButton.icon(
                          onPressed: () => _addSchedule(context),
                          icon: Icon(Icons.add, color: Colors.blue),
                          label: Text(
                            'Add Schedule',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Center(
                  child: Text(
                    'Real-time matching enabled',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              // Gender Section
              SizedBox(height: 20),
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
                    items: genderOptions
                        .map<DropdownMenuItem<String>>((String value) {
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

              // Age Range Section
              SizedBox(height: 20),
              Text(
                'Age Range',
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
                      '${ageRange.start.round()} - ${ageRange.end.round()} years',
                      style: TextStyle(fontSize: 16),
                    ),
                    RangeSlider(
                      values: ageRange,
                      min: 20,
                      max: 60,
                      divisions: 40,
                      labels: RangeLabels(
                        ageRange.start.round().toString(),
                        ageRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          ageRange = values;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),

              // Distance Section
              SizedBox(height: 20),
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
                      style: TextStyle(fontSize: 16),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isScheduledMatch && schedules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                heroTag: 'viewSchedules',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Your Schedules'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: schedules.map((schedule) {
                              if (schedule['timeRange'] == null || schedule['date'] == null) {
                                return Container();
                              }
                              return ListTile(
                                leading: Icon(timeRanges[schedule['timeRange']]!['icon']),
                                title: Text(
                                  '${schedule['date'].day}/${schedule['date'].month}/${schedule['date'].year}',
                                ),
                                subtitle: Text(schedule['timeRange']),
                                onTap: () => _showScheduleDetailsDialog(context, schedule),
                              );
                            }).toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Icon(Icons.schedule),
                backgroundColor: Colors.blue,
              ),
            ),
          Container(
            margin: EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: () {
                bool isValid = selectedCategory != null &&
                    selectedPlace != null &&
                    selectedGender != null;

                if (isScheduledMatch) {
                  isValid = isValid && schedules.isNotEmpty;
                }

                if (!isValid) {
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
                        'Please select all required fields',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ).show(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    FadePageRoute(builder: (context) => SearchingPage()),
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
        ],
      ),
    );
  }
}
