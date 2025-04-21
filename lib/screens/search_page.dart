import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/mapbox_config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

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

  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
    loadLocalData();
  }

  Future<void> loadLocalData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/suburb_stations.json');
      final List<dynamic> data = json.decode(jsonString);
      allLocations = data.cast<Map<String, dynamic>>();
      debugPrint('Loaded ${allLocations.length} local locations');
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
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

    // Search local data
    final filteredLocal = allLocations.where((location) {
      final name = location['Name'].toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).map((location) {
      return {
        'name': location['Name'],
        'lat': location['Latitude'],
        'lon': location['Longitude'],
        'isLocal': true,
      };
    }).toList();

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
          };
        }).toList();

        setState(() {
          mapboxResults = mapboxLocations;
          localResults = filteredLocal;
          isLoading = false;
        });
      } else {
        debugPrint('Mapbox API Error: ${response.statusCode}');
        setState(() {
          mapboxResults = [];
          localResults = filteredLocal;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        mapboxResults = [];
        localResults = filteredLocal;
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
      setState(() {
        recentSearches = decoded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (value == _controller.text) {
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
                      if (recentSearches.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Recent Searches',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ...recentSearches.map((location) {
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(location['name']),
                          onTap: () {
                            Navigator.pop(context, location);
                          },
                        );
                      }).toList()
                    ],
                  )
                : ListView(
                    children: [
                      if (localResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Stations & Suburbs',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...localResults.map((location) => ListTile(
                          leading: const Icon(Icons.train),
                          title: Text(location['name']),
                          onTap: () {
                            _addToRecentSearches(location);
                            Navigator.pop(context, location);
                          },
                        )).toList(),
                      ],
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
                          leading: const Icon(Icons.location_on),
                          title: Text(location['name']),
                          onTap: () {
                            _addToRecentSearches(location);
                            Navigator.pop(context, location);
                          },
                        )).toList(),
                      ],
                      if (localResults.isEmpty && mapboxResults.isEmpty)
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
