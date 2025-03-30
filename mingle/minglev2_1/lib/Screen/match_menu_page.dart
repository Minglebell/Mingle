import 'package:flutter/material.dart';
import '../Widget/bottom_navigation_bar.dart';
import 'package:minglev2_1/Screen/searching_page.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:minglev2_1/Widget/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:minglev2_1/Services/request_matching_service.dart';
import 'dart:async';

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
  Timer? _scheduleCheckTimer;

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

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    // Start periodic check for expired schedules
    _scheduleCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkAndCancelExpiredSchedules();
    });
  }

  @override
  void dispose() {
    _scheduleCheckTimer?.cancel();
    super.dispose();
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load gender
      setState(() {
        selectedGender = prefs.getString('selectedGender');
      });

      // Load category
      setState(() {
        selectedCategory = prefs.getString('selectedCategory');
      });

      // Load place
      setState(() {
        selectedPlace = prefs.getString('selectedPlace');
      });

      // Load scheduled match setting
      setState(() {
        isScheduledMatch = prefs.getBool('isScheduledMatch') ?? false;
      });

      // Load age range
      final savedAgeRangeStart = prefs.getDouble('ageRangeStart') ?? 20.0;
      final savedAgeRangeEnd = prefs.getDouble('ageRangeEnd') ?? 30.0;
      setState(() {
        ageRange = RangeValues(savedAgeRangeStart, savedAgeRangeEnd);
      });

      // Load distance
      setState(() {
        distance = prefs.getDouble('distance') ?? 10.0;
      });

      // Load schedules
      final savedSchedulesJson = prefs.getString('schedules');
      if (savedSchedulesJson != null) {
        final List<dynamic> savedSchedules = json.decode(savedSchedulesJson);
        setState(() {
          schedules = savedSchedules.map((schedule) {
            final Map<String, dynamic> scheduleMap = Map<String, dynamic>.from(schedule);
            scheduleMap['date'] = DateTime.parse(scheduleMap['date']);
            return scheduleMap;
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading saved settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save gender
      if (selectedGender != null) {
        await prefs.setString('selectedGender', selectedGender!);
      }

      // Save category
      if (selectedCategory != null) {
        await prefs.setString('selectedCategory', selectedCategory!);
      }

      // Save place
      if (selectedPlace != null) {
        await prefs.setString('selectedPlace', selectedPlace!);
      }

      // Save scheduled match setting
      await prefs.setBool('isScheduledMatch', isScheduledMatch);

      // Save age range
      await prefs.setDouble('ageRangeStart', ageRange.start);
      await prefs.setDouble('ageRangeEnd', ageRange.end);

      // Save distance
      await prefs.setDouble('distance', distance);

      // Save schedules
      if (schedules.isNotEmpty) {
        final schedulesJson = json.encode(schedules.map((schedule) {
          final Map<String, dynamic> scheduleMap = Map<String, dynamic>.from(schedule);
          scheduleMap['date'] = (schedule['date'] as DateTime).toIso8601String();
          return scheduleMap;
        }).toList());
        await prefs.setString('schedules', schedulesJson);
      }
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  // Function to check if a schedule has passed its start time
  bool _isScheduleExpired(Map<String, dynamic> schedule) {
    if (schedule['date'] == null || schedule['timeRange'] == null) return false;
    
    final DateTime scheduleDate = schedule['date'] as DateTime;
    final String timeRange = schedule['timeRange'] as String;
    final int startHour = timeRanges[timeRange]!['start'] as int;
    
    // Create DateTime for schedule start time
    final DateTime scheduleStartTime = DateTime(
      scheduleDate.year,
      scheduleDate.month,
      scheduleDate.day,
      startHour,
    );
    
    return DateTime.now().isAfter(scheduleStartTime);
  }

  // Function to check and cancel expired schedules
  Future<void> _checkAndCancelExpiredSchedules() async {
    final List<Map<String, dynamic>> expiredSchedules = schedules.where(_isScheduleExpired).toList();
    
    for (var schedule in expiredSchedules) {
      try {
        // Cancel the request in Firestore
        final matchingService = RequestMatchingService(context);
        await matchingService.cancelRequest(schedule['requestId']);

        setState(() {
          schedules.remove(schedule);
        });
        
        // Show notification that schedule was cancelled
        DelightToastBar(
          autoDismiss: true,
          snackbarDuration: const Duration(seconds: 3),
          builder: (context) => ToastCard(
            leading: const Icon(
              Icons.info,
              size: 24,
              color: Colors.orange,
            ),
            title: Text(
              'Schedule for ${schedule['date'].day}/${schedule['date'].month}/${schedule['date'].year} ${schedule['timeRange']} has been cancelled as the time has passed',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ).show(context);
      } catch (e) {
        print('Error cancelling expired schedule: $e');
      }
    }
    
    if (expiredSchedules.isNotEmpty) {
      await _saveSettings();
    }
  }

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
        // Create a new schedule
        final newSchedule = {
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
        };

        setState(() {
          schedules.add(newSchedule);
        });

        // Show success message immediately
        DelightToastBar(
          autoDismiss: true,
          snackbarDuration: const Duration(seconds: 3),
          builder: (context) => ToastCard(
            leading: const Icon(
              Icons.check_circle,
              size: 24,
              color: Colors.green,
            ),
            title: Text(
              'Schedule added successfully',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ).show(context);

        // Create a request for this schedule in the background
        try {
          final matchingService = RequestMatchingService(context);
          await matchingService.createRequest(
            place: selectedPlace!,
            category: selectedCategory!,
            gender: selectedGender!,
            ageRange: ageRange,
            maxDistance: distance,
            scheduledTime: picked,
            timeRange: selectedTime,
          );

          // Store the request ID in the schedule
          newSchedule['requestId'] = matchingService.currentRequestId;
        } catch (e) {
          print('Error creating request for schedule: $e');
          // Show error message
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
                'Failed to create matching request. Please try again.',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ).show(context);
        }

        await _saveSettings(); // Save settings after adding schedule
      }
    }
  }

  void _removeSchedule(int index) {
    setState(() {
      schedules.removeAt(index);
    });
    _saveSettings(); // Save settings after removing schedule
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ');
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
                        _saveSettings(); // Save settings after category change
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
                          _saveSettings(); // Save settings after place change
                        },
                        selectedColor: Colors.blue,
                        backgroundColor: Colors.grey[200],
                      );
                    }).toList(),
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
                      _saveSettings(); // Save settings after gender change
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
                      max: 80,
                      divisions: 60,
                      labels: RangeLabels(
                        ageRange.start.round().toString(),
                        ageRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          ageRange = values;
                        });
                        _saveSettings(); // Save settings after age range change
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
                        _saveSettings(); // Save settings after distance change
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),

              // Schedule Section (moved to bottom)
              SizedBox(height: 20),
              Text(
                'Schedule',
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
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (schedules.isNotEmpty)
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
                                trailing: IconButton(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  onPressed: () async {
                                    try {
                                      // Cancel the request in Firestore
                                      final matchingService = RequestMatchingService(context);
                                      await matchingService.cancelRequest(schedule['requestId']);

                                      setState(() {
                                        schedules.remove(schedule);
                                      });
                                      _saveSettings();
                                      Navigator.of(context).pop();
                                      DelightToastBar(
                                        autoDismiss: true,
                                        snackbarDuration: const Duration(seconds: 3),
                                        builder: (context) => ToastCard(
                                          leading: const Icon(
                                            Icons.check_circle,
                                            size: 24,
                                            color: Colors.green,
                                          ),
                                          title: Text(
                                            'Schedule removed successfully',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ).show(context);
                                    } catch (e) {
                                      print('Error canceling schedule: $e');
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
                                            'Failed to remove schedule. Please try again.',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ).show(context);
                                    }
                                  },
                                ),
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

                if (isValid) {
                  Navigator.pushReplacement(
                    context,
                    FadePageRoute(
                      builder: (context) => SearchingPage(
                        selectedGender: selectedGender!,
                        ageRange: ageRange,
                        maxDistance: distance,
                        selectedPlace: selectedPlace ?? 'Any',
                        selectedCategory: selectedCategory ?? 'Any',
                        isScheduledMatch: false,
                        schedules: null,
                      ),
                    ),
                  );
                } else {
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


