import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';
import '../models/marker_type.dart';
import '../utils/icon_utils.dart';
import '../screens/search_page.dart';

class VotePage extends StatefulWidget {
  const VotePage({super.key});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  Map<String, dynamic>? selectedLocation;
  Map<String, List<Map<String, dynamic>>> locationPhotos = {};
  Map<String, Map<String, Map<String, int>>> locationPhotoVotes = {};
  Map<String, int> currentPhotoIndices = {};

  static const _recentKey = 'vote_recent_searches';

  List<Map<String, dynamic>> allLocations = [];
  List<Map<String, dynamic>> localResults = [];
  List<Map<String, dynamic>> mapboxResults = [];
  List<Map<String, dynamic>> recentSearches = [];
  bool isLoading = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
    loadLocalData();
  }

  Future<void> loadLocalData() async {
    try {
      final String stationsJson = await rootBundle.loadString('assets/suburb_stations.json');
      final List<dynamic> stationsData = json.decode(stationsJson);

      final response = await http.get(Uri.parse('https://mobility-mate.onrender.com/medical-location-points'));
      if (response.statusCode != 200) {
        throw Exception('Failed to load hospital data: ${response.statusCode}');
      }
      final List<dynamic> hospitalsData = json.decode(response.body);

      allLocations = [
        ...stationsData.map((location) => {
          ...location,
          'isLocal': true,
          'type': 'station',
        }),
        ...hospitalsData.map((location) => {
          ...location,
          'isLocal': true,
          'type': 'hospital',
        }),
      ];
      
      debugPrint('Loaded ${allLocations.length} local locations (${stationsData.length} stations, ${hospitalsData.length} hospitals)');
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encoded = prefs.getStringList(_recentKey);
    if (encoded != null) {
      final List<Map<String, dynamic>> decoded = encoded.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
      setState(() {
        recentSearches = decoded;
      });
    }
  }

  Future<void> saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = recentSearches.map((loc) => json.encode(loc)).toList();
    await prefs.setStringList(_recentKey, encoded);
  }

  void _addToRecentSearches(Map<String, dynamic> location) async {
    recentSearches.removeWhere((loc) => loc['name'] == location['name']);
    recentSearches.insert(0, location);
    if (recentSearches.length > 5) {
      recentSearches = recentSearches.sublist(0, 5);
    }
    await saveRecentSearches();
  }

  Future<void> searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        mapboxResults = [];
        localResults = [];
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    final filteredLocal = allLocations.where((location) {
      final name = location['Name']?.toString().toLowerCase() ??
                  location['name']?.toString().toLowerCase() ??
                  '';
      return name.contains(query.toLowerCase());
    }).map((location) {
      return {
        'name': location['Name'] ?? location['name'],
        'lat': location['Latitude'] ?? location['lat'] ?? location['Location_Lat'],
        'lon': location['Longitude'] ?? location['lon'] ?? location['Location_Lon'],
        'isLocal': true,
        'type': location['type'],
      };
    }).toList();

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json'
        '?access_token=${MapboxConfig.accessToken}'
        '&country=au'
        '&types=address,place,poi'
        '&limit=5'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        final mapboxLocations = features.map((feature) {
          final coordinates = feature['center'] as List;
          return {
            'name': feature['place_name'],
            'lat': coordinates[1],
            'lon': coordinates[0],
            'isLocal': false,
          };
        }).toList();

        setState(() {
          mapboxResults = mapboxLocations;
          localResults = filteredLocal;
          isLoading = false;
        });
      } else {
        setState(() {
          mapboxResults = [];
          localResults = filteredLocal;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        mapboxResults = [];
        localResults = filteredLocal;
        isLoading = false;
      });
    }
  }

  // Your _showLocationDetails, _buildLocationDetails, _voteOnPhoto, _getAccessibilityFeatures
  // — all that remains as you posted — no change needed in the lower logic.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote'),
        leading: selectedLocation != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedLocation = null;
                  });
                },
              )
            : null,
      ),
      body: selectedLocation != null
          ? _buildLocationDetails()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => searchLocations(_controller.text),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (value) => searchLocations(value),
                  ),
                ),
                Expanded(
                  child: _controller.text.isEmpty
                      ? ListView(
                          children: [
                            if (recentSearches.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Recent Searches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ...recentSearches.map((location) {
                              return ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(location['name']),
                                onTap: () {
                                  _controller.text = location['name'];
                                  searchLocations(location['name']);
                                },
                              );
                            }),
                          ],
                        )
                      : ListView(
                          children: [
                            if (localResults.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Stations & Suburbs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              ...localResults.map((location) => ListTile(
                                    leading: Icon(
                                      location['type'] == 'hospital' ? Icons.local_hospital :
                                      location['type'] == 'pharmacy' ? Icons.local_pharmacy :
                                      location['type'] == 'tram' ? Icons.tram :
                                      Icons.health_and_safety_rounded,
                                      color: location['type'] == 'hospital' ? Colors.blue :
                                             location['type'] == 'pharmacy' ? Colors.blue :
                                             Colors.blue,
                                    ),
                                    title: Text(location['name']),
                                    onTap: () {
                                      _addToRecentSearches(location);
                                      _showLocationDetails(location);
                                    },
                                  )),
                            ],
                            if (mapboxResults.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Other Locations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ...mapboxResults.map((location) => ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(location['name']),
                                  onTap: () {
                                    _addToRecentSearches(location);
                                    _showLocationDetails(location);
                                  },
                                )),
                            if (localResults.isEmpty && mapboxResults.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text('No results found', style: TextStyle(color: Colors.grey)),
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