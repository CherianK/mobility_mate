import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> allLocations = [];      // Was allStations
  List<Map<String, dynamic>> filteredLocations = []; // Was filteredStations

  @override
  void initState() {
    super.initState();
    loadLocationData(); // renamed method
  }

  /// Loads suburb or station data from JSON file
  Future<void> loadLocationData() async {
    final String jsonString =
        await rootBundle.loadString('assets/suburb_stations.json');
    final List<dynamic> data = json.decode(jsonString);
    setState(() {
      allLocations = data.cast<Map<String, dynamic>>();
    });
  }

  /// Filters location list based on search query
  void _filterLocations(String query) {
    final filtered = allLocations.where((location) {
      final name = location['Name'].toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredLocations = filtered;
    });
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
            child: ListView.builder(
              itemCount: filteredLocations.length,
              itemBuilder: (context, index) {
                final location = filteredLocations[index];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(location['Name']),
                  onTap: () {
                    Navigator.pop(context, {
                      'lat': location['Latitude'],
                      'lon': location['Longitude'],
                      'name': location['Name'],
                    });
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
