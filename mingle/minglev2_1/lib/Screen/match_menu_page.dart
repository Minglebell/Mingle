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
import 'package:logging/logging.dart';

// Create a logger instance
final _logger = Logger('FindMatchPage');

class FindMatchPage extends StatefulWidget {
  const FindMatchPage({super.key});

  @override
  State<FindMatchPage> createState() => _FindMatchPageState();
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

  // genders
  final Map<String, IconData> genderIcons = {
    'Male': Icons.male,
    'Female': Icons.female,
    'Non-binary': Icons.transgender,
    'Transgender': Icons.transgender,
    'LGBTQ+': Icons.diversity_3,
    'Other': Icons.person_outline,
  };

  // places
  final Map<String, IconData> placeIcons = {
    // Outdoor_Nature
    "Parks": Icons.park,
    "Beaches": Icons.beach_access,
    "Lakes": Icons.water,
    "Zoos": Icons.pets,
    "Safari parks": Icons.forest,
    "Amusement parks": Icons.attractions,
    "Water parks": Icons.pool,

    // Arts_Culture_Historical_Sites
    "Museums": Icons.museum,
    "Art galleries": Icons.art_track,
    "Historical landmarks": Icons.account_balance,
    "Temples": Icons.temple_buddhist,

    // Entertainment_Recreation
    "Movie theaters": Icons.movie,
    "Bowling alleys": Icons.sports_cricket,
    "Escape rooms": Icons.vrpano,
    "Gaming centers": Icons.sports_esports,
    "Live theaters": Icons.theater_comedy,
    "Concert venues": Icons.music_note,
    "Karaoke bars": Icons.mic,
    "Aquariums": Icons.water,
    "Ice-skating rinks": Icons.ice_skating,

    // Dining_Cafes
    "Thai restaurants": Icons.restaurant,
    "Italian restaurants": Icons.restaurant,
    "Japanese restaurants": Icons.restaurant,
    "Chinese restaurants": Icons.restaurant,
    "Korean restaurants": Icons.restaurant,
    "Indian restaurants": Icons.restaurant,
    "Vegan restaurants": Icons.restaurant,
    "Buffet restaurants": Icons.restaurant_menu,
    "Seafood restaurants": Icons.set_meal,
    "Thai barbecue restaurants": Icons.outdoor_grill,
    "Korean barbecue restaurants": Icons.outdoor_grill,
    "Japanese barbecue restaurants": Icons.outdoor_grill,
    "Thai-style hot pot restaurants": Icons.soup_kitchen,
    "Chinese hot pot Restaurants": Icons.soup_kitchen,
    "Japanese hot pot restaurants": Icons.soup_kitchen,
    "Northeastern Thai restaurants": Icons.restaurant,
    "Steak restaurant": Icons.restaurant,
    "Sushi restaurant": Icons.set_meal,
    "Dessert cafes": Icons.icecream,
    "Coffee shops": Icons.coffee,

    // Nightlife_Bars
    "Bars": Icons.local_bar,
    "Cocktail bars": Icons.local_bar,
    "Pubs": Icons.sports_bar,
    "Wine bars": Icons.wine_bar,

    // Shopping
    "Shopping malls": Icons.shopping_cart,
    "Markets": Icons.storefront,
    "Night markets": Icons.nightlife,
    "Floating markets": Icons.directions_boat,
  };

  // Add this at the top of the class with other variables
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    // Start periodic check for expired schedules
    _scheduleCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
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
      
      // Load matching preferences (these will be null after a match)
      setState(() {
        selectedGender = prefs.getString('selectedGender');
        selectedCategory = prefs.getString('selectedCategory');
        selectedPlace = prefs.getString('selectedPlace');
        ageRange = RangeValues(
          prefs.getDouble('ageRangeStart') ?? 20.0,
          prefs.getDouble('ageRangeEnd') ?? 30.0,
        );
        distance = prefs.getDouble('distance') ?? 10.0;
      });

      // Load schedule settings (these will persist after matches)
      setState(() {
        isScheduledMatch = prefs.getBool('isScheduledMatch') ?? false;
      });

      // Load saved schedules
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
      } else {
        setState(() {
          schedules = [];
        });
      }
    } catch (e) {
      _logger.warning('Error loading saved settings', e);
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
      _logger.warning('Error saving settings', e);
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
        if (!context.mounted) return;
        // Store context before async operation
        final currentContext = context;
        if (!currentContext.mounted) return;
        
        // Cancel the request in Firestore
        final matchingService = RequestMatchingService(currentContext);
        await matchingService.cancelRequest(schedule['requestId']);

        if (!context.mounted) return;
        setState(() {
          schedules.remove(schedule);
        });
        
        // Show notification that schedule was cancelled
        if (!currentContext.mounted) return;
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
        ).show(currentContext);
      } catch (e) {
        _logger.warning('Error cancelling expired schedule', e);
      }
    }
    
    if (expiredSchedules.isNotEmpty && mounted) {
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

  // addSchedule function
  Future<void> _addSchedule(BuildContext context) async {
    
    if (schedules.length >= 5) {
      if (!context.mounted) return;
      DelightToastBar(
        autoDismiss: true,
        snackbarDuration: const Duration(seconds: 3),
        builder: (context) => const ToastCard(
          leading: Icon(
            Icons.warning,
            size: 24,
            color: Colors.orange,
          ),
          title: Text(
            'Maximum 5 schedules allowed',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ).show(context);
      return;
    }

    if (selectedCategory == null || selectedPlace == null || selectedGender == null) {
      if (!context.mounted) return;
      DelightToastBar(
        autoDismiss: true,
        snackbarDuration: const Duration(seconds: 3),
        builder: (context) => const ToastCard(
          leading: Icon(
            Icons.error,
            size: 24,
            color: Colors.red,
          ),
          title: Text(
            'Please select category, place, and gender before adding schedule',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ).show(context);
      return;
    }

    if (!context.mounted) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null && context.mounted) {
      String? selectedTime;
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Select Time Range'),
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
                      ? const Text('Time range already passed', style: TextStyle(color: Colors.red))
                      : exists 
                        ? const Text('Schedule already exists', style: TextStyle(color: Colors.orange))
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

      if (selectedTime != null && context.mounted) {
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
          builder: (context) => const ToastCard(
            leading: Icon(
              Icons.check_circle,
              size: 24,
              color: Colors.green,
            ),
            title: Text(
              'Schedule added successfully',
              style: TextStyle(
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
          _logger.warning('Error creating request for schedule', e);
          if (!context.mounted) return;
          DelightToastBar(
            autoDismiss: true,
            snackbarDuration: const Duration(seconds: 3),
            builder: (context) =>const  ToastCard(
              leading: Icon(
                Icons.error,
                size: 24,
                color: Colors.red,
              ),
              title: Text(
                'Failed to create matching request. Please try again.',
                style: TextStyle(
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
              const SizedBox(width: 8),
              const Text('Schedule Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(
                    '${schedule['date'].day}/${schedule['date'].month}/${schedule['date'].year}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time Range'),
                  subtitle: Text(schedule['timeRange'] ?? ''),
                ),
                ListTile(
                  leading: Icon(categoryIcons[schedule['category']] ?? Icons.category),
                  title: const Text('Category'),
                  subtitle: Text(_formatCategory(schedule['category'])),
                ),
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Place'),
                  subtitle: Text(schedule['place'] ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Preferred Gender'),
                  subtitle: Text(schedule['gender'] ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Age Range'),
                  subtitle: Text('${schedule['ageRange']?['start']?.round() ?? 20} - ${schedule['ageRange']?['end']?.round() ?? 30} years'),
                ),
                ListTile(
                  leading: const Icon(Icons.social_distance),
                  title: const Text('Distance'),
                  subtitle: Text('${(schedule['distance'] ?? 10).round()} km'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Modify the handleSuccessfulMatch method
  void handleSuccessfulMatch(String requestId) {
    setState(() {
      // Remove the schedule with matching requestId
      schedules.removeWhere((schedule) => schedule['requestId'] == requestId);
    });
    _saveSettings();
    
    // Close any open dialogs
    if (navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).popUntil((route) => route.isFirst);
    }
  }

  // Add this method to reset the UI
  void resetScheduleUI() {
    setState(() {
      schedules = [];
    });
    _saveSettings();
  }

  // Modify the _showCompactScheduleDetails method to include a reset button
  void _showCompactScheduleDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Schedules',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (schedules.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Reset All Schedules'),
                                    content: const Text('Are you sure you want to reset all schedules?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          resetScheduleUI();
                                          Navigator.of(context).pop(); // Close confirmation dialog
                                          Navigator.of(context).pop(); // Close schedule details dialog
                                        },
                                        child: const Text('Reset', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        Text(
                          '${schedules.length}/5',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: schedules.isEmpty
                    ? const Center(
                        child: Text(
                          'No active schedules',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          final schedule = schedules[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: Icon(
                                timeRanges[schedule['timeRange']]?['icon'] ?? Icons.schedule,
                                color: Colors.blue,
                              ),
                              title: Text(
                                '${schedule['date'].day}/${schedule['date'].month}/${schedule['date'].year}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(schedule['timeRange'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      try {
                                        if (schedule['requestId'] != null) {
                                          final matchingService = RequestMatchingService(context);
                                          await matchingService.cancelRequest(schedule['requestId']);
                                        }
                                        
                                        setState(() {
                                          schedules.removeAt(index);
                                        });
                                        
                                        await _saveSettings();

                                        // Close the dialog immediately after deletion
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();

                                        // Show success message
                                        DelightToastBar(
                                          autoDismiss: true,
                                          snackbarDuration: const Duration(seconds: 3),
                                          builder: (context) => const ToastCard(
                                            leading: Icon(
                                              Icons.check_circle,
                                              size: 24,
                                              color: Colors.green,
                                            ),
                                            title: Text(
                                              'Schedule deleted successfully',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ).show(context);

                                        // If no schedules left, rebuild the main screen and close any open dialogs
                                        if (schedules.isEmpty) {
                                          setState(() {});
                                          if (context.mounted) {
                                            Navigator.of(context).popUntil((route) => route.isFirst);
                                          }
                                        }
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        DelightToastBar(
                                          autoDismiss: true,
                                          snackbarDuration: const Duration(seconds: 3),
                                          builder: (context) => const ToastCard(
                                            leading: Icon(
                                              Icons.error,
                                              size: 24,
                                              color: Colors.red,
                                            ),
                                            title: Text(
                                              'Failed to delete schedule',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ).show(context);
                                      }
                                    },
                                  ),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow(
                                        Icons.category,
                                        'Category',
                                        _formatCategory(schedule['category']),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.place,
                                        'Place',
                                        schedule['place'] ?? '',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.person,
                                        'Preferred Gender',
                                        schedule['gender'] ?? '',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.person_outline,
                                        'Age Range',
                                        '${schedule['ageRange']?['start']?.round() ?? 20} - ${schedule['ageRange']?['end']?.round() ?? 30} years',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.social_distance,
                                        'Distance',
                                        '${(schedule['distance'] ?? 10).round()} km',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add this new helper method
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: navigatorKey,
      appBar: const CustomAppBar(
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Select Category'),
                  const SizedBox(height: 12),
                  _buildCategorySelection(),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Select Place'),
                  const SizedBox(height: 12),
                  if (selectedCategory != null && placeData[selectedCategory] != null)
                    _buildPlaceChips(placeData[selectedCategory]!),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Select Gender'),
                  const SizedBox(height: 12),
                  _buildGenderSelection(),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Age Range'),
                  const SizedBox(height: 8),
                  _buildAgeRangeSlider(),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('Distance'),
                  const SizedBox(height: 8),
                  _buildDistanceSlider(),
                  
                  const SizedBox(height: 24),
                  _buildScheduleSection(),
                  
                  // Add padding at the bottom to prevent content from being hidden behind the floating button
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Add floating schedule count widget
          if (schedules.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _showCompactScheduleDetails(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${schedules.length}/5',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildMatchButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildCategorySelection() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,  // Center column contents
            mainAxisAlignment: MainAxisAlignment.center,   // Center vertically
            children: [
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,  // Center the title text
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: placeData.keys.map((String category) {
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcons[category] ?? Icons.category,
                          size: 20,
                          color: selectedCategory == category ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.replaceAll('_', ' '),
                          style: TextStyle(
                            color: selectedCategory == category ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    selected: selectedCategory == category,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedCategory = selected ? category : null;
                        selectedPlace = null;
                      });
                      _saveSettings();
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.grey.shade200,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceChips(List<String> places) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Place',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: places.map((String place) {
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          placeIcons[place] ?? Icons.place,
                          size: 20,
                          color: selectedPlace == place ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          place,
                          style: TextStyle(
                            color: selectedPlace == place ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    selected: selectedPlace == place,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedPlace = selected ? place : null;
                      });
                      _saveSettings();
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.grey.shade200,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Gender Preference',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: genderOptions.map((String gender) {
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          genderIcons[gender] ?? Icons.person,
                          size: 20,
                          color: selectedGender == gender ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          gender,
                          style: TextStyle(
                            color: selectedGender == gender ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    selected: selectedGender == gender,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedGender = selected ? gender : null;
                      });
                      _saveSettings();
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.grey.shade200,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeRangeSlider() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              '${ageRange.start.round()} - ${ageRange.end.round()} years',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
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
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceSlider() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              '${distance.round()} km',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Slider(
              value: distance,
              min: 1,
              max: 20,
              divisions: 19,
              label: distance.round().toString(),
              onChanged: (double value) {
                setState(() {
                  distance = value;
                });
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scheduled Matches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schedules.isNotEmpty)
                  Text(
                    '${schedules.length}/5',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _addSchedule(context),
                icon: const Icon(Icons.add, color: Colors.blue),
                label: const Text(
                  'Add Schedule',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchButton(BuildContext context) {
    bool isValid = selectedCategory != null &&
        selectedPlace != null &&
        selectedGender != null;

    return ElevatedButton(
      onPressed: isValid ? () {
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
      } : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text(
        'Matching',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}


