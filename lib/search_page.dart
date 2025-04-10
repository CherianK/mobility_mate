import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> allLocations = [];
  List<Map<String, dynamic>> filteredLocations = [];
  List<Map<String, dynamic>> recentSearches = [];

  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    loadLocationData();
    loadRecentSearches();
  }

  Future<void> loadLocationData() async {
    final String jsonString =
        await rootBundle.loadString('assets/suburb_stations.json');
    final List<dynamic> data = json.decode(jsonString);
    setState(() {
      allLocations = data.cast<Map<String, dynamic>>();
    });
  }

  void _filterLocations(String query) {
    final filtered = allLocations.where((location) {
      final name = location['Name'].toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredLocations = filtered;
    });
  }

  void _addToRecentSearches(Map<String, dynamic> location) async {
    recentSearches.removeWhere((loc) => loc['Name'] == location['Name']);
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
    final isSearching = _controller.text.isNotEmpty;

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
              onChanged: _filterLocations,
              decoration: InputDecoration(
                hintText: 'Search suburb or station...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: isSearching
                ? (filteredLocations.isEmpty
                    ? const Center(
                        child: Text(
                          'Location not found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLocations.length,
                        itemBuilder: (context, index) {
                          final location = filteredLocations[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(location['Name']),
                            onTap: () {
                              _addToRecentSearches(location);
                              Navigator.pop(context, {
                                'lat': location['Latitude'],
                                'lon': location['Longitude'],
                                'name': location['Name'],
                              });
                            },
                          );
                        },
                      ))
                : ListView(
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
                          title: Text(location['Name']),
                          onTap: () {
                            Navigator.pop(context, {
                              'lat': location['Latitude'],
                              'lon': location['Longitude'],
                              'name': location['Name'],
                            });
                          },
                        );
                      }).toList()
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
