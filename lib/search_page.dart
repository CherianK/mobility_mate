// lib/search_page.dart
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<String> allLocations = [
    'Melbourne',
    'Richmond',
    'Brunswick',
    'Carlton',
    'Docklands',
    'Footscray',
    'Southbank'
  ]; // dummy list for now

  List<String> filteredLocations = [];

  void _filterLocations(String query) {
    final filtered = allLocations
        .where((loc) => loc.toLowerCase().contains(query.toLowerCase()))
        .toList();
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
                hintText: 'Enter location name...',
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
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(filteredLocations[index]),
                  onTap: () {
                    // later: send selected location back to map
                    Navigator.pop(context, filteredLocations[index]);
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
