import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> mapboxResults = [];
  List<Map<String, dynamic>> localResults = [];
  List<Map<String, dynamic>> recentSearches = [];
  List<Map<String, dynamic>> allLocations = [];
  bool isLoading = false;
  // Track active searches to cancel them if needed
  bool _isMounted = true;

  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
    loadLocalData();
  }
  
  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> loadLocalData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/suburb_stations.json');
      final List<dynamic> data = json.decode(jsonString);
      if (!_isMounted) return;
      allLocations = data.cast<Map<String, dynamic>>();
      debugPrint('Loaded ${allLocations.length} local locations');
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  Future<void> searchLocations(String query) async {
    if (!_isMounted) return;
    
    if (query.isEmpty) {
      if (!_isMounted) return;
      setState(() {
        mapboxResults = [];
        localResults = [];
        isLoading = false;
      });
      return;
    }

    if (!_isMounted) return;
    setState(() {
      isLoading = true;
    });

    // Search local data and separate by type
    final trainTramResults = <Map<String, dynamic>>[];
    final suburbResults = <Map<String, dynamic>>[];
    final healthcareResults = <Map<String, dynamic>>[];
    
    allLocations.where((location) {
      final name = location['Name'].toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).forEach((location) {
      if (!_isMounted) return;
      final type = location['Accessibility_Type_Name']?.toString().toLowerCase() ?? '';
      final resultMap = {
        'name': location['Name'],
        'lat': location['Latitude'],
        'lon': location['Longitude'],
        'isLocal': true,
        'type': type,
      };
      
      if (type == 'trains' || type == 'trams') {
        trainTramResults.add(resultMap);
      } else if (type == 'suburb') {
        suburbResults.add(resultMap);
      } else if (type == 'healthcare') {
        healthcareResults.add(resultMap);
      }
    });
    
    if (!_isMounted) return;

    // Search Mapbox
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json'
        '?access_token=${MapboxConfig.accessToken}'
        '&country=au'
        '&types=address,place,poi'
        '&limit=5' // Reduced limit to show both local and Mapbox results
      );

      final response = await http.get(url);
      
      // Check if widget is still mounted after async operation
      if (!_isMounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        final mapboxLocations = features.map((feature) {
          final coordinates = feature['center'] as List;
          final lat = coordinates[1] as double;
          final lon = coordinates[0] as double;
          return {
            'name': feature['place_name'],
            'lat': lat,
            'lon': lon,
            'isLocal': false,
            'type': 'mapbox',
          };
        }).toList();

        // One final mounted check before setState
        if (!_isMounted) return;
        setState(() {
          mapboxResults = mapboxLocations;
          // Include all local results (trains, trams, healthcare, and suburbs)
          localResults = [...trainTramResults, ...suburbResults, ...healthcareResults];
          isLoading = false;
        });
      } else {
        debugPrint('Mapbox API Error: ${response.statusCode}');
        if (!_isMounted) return;
        setState(() {
          mapboxResults = [];
          // Include all local results (trains, trams, healthcare, and suburbs)
          localResults = [...trainTramResults, ...suburbResults, ...healthcareResults];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (!_isMounted) return;
      setState(() {
        mapboxResults = [];
        // Include all local results (trains, trams, healthcare, and suburbs)
        localResults = [...trainTramResults, ...suburbResults, ...healthcareResults];
        isLoading = false;
      });
    }
  }

  void _addToRecentSearches(Map<String, dynamic> location) async {
    recentSearches.removeWhere((loc) => loc['name'] == location['name']);
    recentSearches.insert(0, location);
    if (recentSearches.length > 5) {
      recentSearches = recentSearches.sublist(0, 5);
    }
    await saveRecentSearches();
  }

  Future<void> saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded =
        recentSearches.map((loc) => json.encode(loc)).toList();
    await prefs.setStringList(_recentKey, encoded);
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encoded = prefs.getStringList(_recentKey);
    if (encoded != null) {
      final List<Map<String, dynamic>> decoded = encoded
          .map((e) => Map<String, dynamic>.from(json.decode(e)))
          .toList();
      if (!_isMounted) return;
      setState(() {
        recentSearches = decoded;
      });
    }
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
    if (!_isMounted) return;
    setState(() {
      recentSearches = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Separate local results by type for UI display
    final trainTramResults = localResults.where((loc) => 
      loc['type'] == 'trains' || loc['type'] == 'trams').toList();
    final healthcareResults = localResults.where((loc) => 
      loc['type'] == 'healthcare').toList();
    final suburbResults = localResults.where((loc) => 
      loc['type'] == 'suburb').toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Locations'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (value) {
                // Cancel any previous delayed searches to prevent race conditions
                Future.delayed(const Duration(milliseconds: 300), () {
                  // Verify the widget is still mounted and the text hasn't changed
                  if (_isMounted && value == _controller.text) {
                    searchLocations(value);
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _controller.text.isEmpty
                ? ListView(
                    children: [
                      if (recentSearches.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Searches',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Clear All'),
                                onPressed: () {
                                  clearRecentSearches();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...recentSearches.map((location) {
                          // Determine the icon based on the location type
                          Widget leadingIcon;
                          if (location['type'] == 'trains') {
                            leadingIcon = const Icon(Icons.train, color: Colors.blue);
                          } else if (location['type'] == 'trams') {
                            leadingIcon = const Icon(Icons.tram, color: Colors.green);
                          } else if (location['type'] == 'healthcare') {
                            leadingIcon = const Icon(Icons.local_hospital, color: Colors.red);
                          } else if (location['type'] == 'suburb') {
                            leadingIcon = const Icon(Icons.location_city, color: Colors.orange);
                          } else {
                            leadingIcon = const Icon(Icons.history);
                          }
                          
                          return ListTile(
                            leading: leadingIcon,
                            title: Text(location['name']),
                            onTap: () {
                              Navigator.pop(context, location);
                            },
                          );
                        })
                      ],
                    ],
                  )
                : ListView(
                    children: [
                      // 1. Display Train and Tram stations first
                      if (trainTramResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Train & Tram Stations',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...trainTramResults.map((location) => ListTile(
                          leading: Icon(
                            location['type'] == 'trains' ? Icons.train : Icons.tram,
                            color: location['type'] == 'trains' ? Colors.blue : Colors.green,
                          ),
                          title: Text(location['name']),
                          onTap: () {
                            // For trains and trams, add to recent searches and pop with location data
                            // This will trigger bottom sheet with info + center to location
                            _addToRecentSearches(location);
                            Navigator.pop(context, location);
                          },
                        )),
                      ],
                      
                      // 2. Display Healthcare Facilities second
                      if (healthcareResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Healthcare Facilities',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...healthcareResults.map((location) => ListTile(
                          leading: const Icon(Icons.local_hospital, color: Colors.red),
                          title: Text(location['name']),
                          onTap: () {
                            // For healthcare, add to recent searches and pop with location data
                            // This will trigger bottom sheet with info + center to location
                            _addToRecentSearches(location);
                            Navigator.pop(context, location);
                          },
                        )),
                      ],
                      
                      // 3. Display Suburbs third
                      if (suburbResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Suburbs',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...suburbResults.map((location) => ListTile(
                          leading: const Icon(Icons.location_city, color: Colors.orange),
                          title: Text(location['name']),
                          onTap: () {
                            // For suburbs, add to recent searches and pop with location data
                            // Include a flag to indicate this should only center the map without bottom sheet
                            final locationWithFlag = {
                              ...location,
                              'centerOnly': true, // Flag to indicate only center to location, no bottom sheet
                            };
                            _addToRecentSearches(locationWithFlag);
                            Navigator.pop(context, locationWithFlag);
                          },
                        )),
                      ],
                      
                      // 4. Display Mapbox results last
                      if (mapboxResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Other Locations',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...mapboxResults.map((location) => ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: Text(location['name']),
                          onTap: () {
                            // For Mapbox results, add to recent searches and pop with location data
                            // Include a flag to indicate this should only center the map without bottom sheet
                            final locationWithFlag = {
                              ...location,
                              'centerOnly': true, // Flag to indicate only center to location, no bottom sheet
                            };
                            _addToRecentSearches(locationWithFlag);
                            Navigator.pop(context, locationWithFlag);
                          },
                        )),
                      ],
                      
                      if (trainTramResults.isEmpty && healthcareResults.isEmpty && 
                          suburbResults.isEmpty && mapboxResults.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No results found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
