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
  DateTime? selectedDateTime;
  String? selectedTimeRange;
  String? selectedPlaceCategory;
  String? selectedPlace;
  double distance = 1.0;

  final Map<String, List<String>> placeCategories = {
    "Outdoor_Nature": [
      "Parks",
      "Beaches",
      "Lakes",
      "Zoos",
      "Safari parks",
      "Amusement parks",
      "Water parks"
    ],
    "Arts_Culture_Historical_Sites": [
      "Museums",
      "Art galleries",
      "Historical landmarks",
      "Temple"
    ],
    "Entertainment_Recreation": [
      "Movie theaters",
      "Bowling alleys",
      "Escape rooms",
      "Gaming centers",
      "Live theaters",
      "Concert venues",
      "Karaoke bar",
      "Aquariums"
    ],
    "Dining_Cafes": [
      "Restaurants",
      "Cafés",
      "Coffee shops"
    ],
    "Nightlife_Bars": [
      "Bars",
      "Pubs"
    ],
    "Shopping": [
      "Shopping malls",
      "Markets"
    ]
  };

  final List<String> timeRanges = [
    "12am to 6am",
    "6am to 12pm",
    "12pm to 6pm", 
    "6pm to 12am"
  ];

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDateTime = picked;
      });
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
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
              'Find Your Place Partner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Customize your preferences to find the perfect place buddy.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
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
              _buildSectionTitle('Select Gender'),
              _buildCard(
                Container(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: InputDecoration(
                      hintText: 'Choose gender',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedGender = newValue;
                      });
                    },
                    items: <String>['Male', 'Female', 'Other']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),

              _buildSectionTitle('Select Date and Time Range'),
              _buildCard(
                Column(
                  children: [
                    InkWell(
                      onTap: () => _selectDateTime(context),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDateTime == null
                                  ? 'Click to select a date'
                                  : 'Date: ${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year}',
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_today, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: timeRanges.map((String range) {
                        return ChoiceChip(
                          label: Text(range),
                          selected: selectedTimeRange == range,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedTimeRange = selected ? range : null;
                            });
                          },
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: selectedTimeRange == range ? Colors.white : Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              _buildSectionTitle('Select Place Category'),
              _buildCard(
                Container(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: selectedPlaceCategory,
                    decoration: InputDecoration(
                      hintText: 'Choose place category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedPlaceCategory = newValue;
                        selectedPlace = null;
                      });
                    },
                    items: placeCategories.keys.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.replaceAll('_', ' ')),
                      );
                    }).toList(),
                  ),
                ),
              ),

              if (selectedPlaceCategory != null) ...[
                _buildSectionTitle('Select Place'),
                _buildCard(
                  Container(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: selectedPlace,
                      decoration: InputDecoration(
                        hintText: 'Choose place',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedPlace = newValue;
                        });
                      },
                      items: placeCategories[selectedPlaceCategory!]!
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              _buildSectionTitle('Set Distance'),
              _buildCard(
                Column(
                  children: [
                    Text(
                      '${distance.round()} km',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue,
                        thumbColor: Colors.blue,
                        overlayColor: Colors.blue.withAlpha(32),
                        valueIndicatorColor: Colors.blue,
                      ),
                      child: Slider(
                        value: distance,
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '${distance.round()} km',
                        onChanged: (double value) {
                          setState(() {
                            distance = value;
                          });
                        },
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
      floatingActionButton: Container(
        padding: EdgeInsets.symmetric(horizontal: 24),
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (selectedGender == null ||
                selectedDateTime == null ||
                selectedTimeRange == null ||
                selectedPlaceCategory == null ||
                selectedPlace == null) {
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 4,
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