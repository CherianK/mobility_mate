import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobility-mate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const MapHomePage(),
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();

  /// Holds dynamically loaded markers from the backend
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    fetchToiletLocations(); // Fetch markers on widget load
  }

  /// Fetch all locations from Flask and convert them into Marker objects
  Future<void> fetchToiletLocations() async {
    try {

      debugPrint("Starting to fetch locations...");

      final response = await http.get(Uri.parse('https://mobility-mate.onrender.com/toilet-location-points'));


      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint("Data fetched successfully: $data");

      setState(() {
        _markers = data.map<Marker>((location) {
          // Update keys to match your MongoDB document structure
          final double lat = (location['Location_Lat'] as num).toDouble();
          final double lon = (location['Location_Lon'] as num).toDouble();
          //debugPrint("Creating marker for location: lat=$lat, lon=$lon");

          return Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: GestureDetector(
              child: const Icon(
                Icons.location_on,
                size: 36,
                color: Colors.red,
              ),
            ),
          );
        }).toList();
      });

      debugPrint("Markers created: ${_markers.length}");
    } else {
      debugPrint("Failed to load locations. Status code: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("Error fetching locations: $e");
  }
}

  

  /// Helper to build a label-value row
  Widget _buildPropertyRow(String label, dynamic value) {
    // If value is null, show "N/A"
    final displayValue = value ?? 'N/A';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('$displayValue'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMap(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.star),
        onPressed: () {
          // Recenter the map to Melbourne
          _mapController.move(LatLng(-37.8136, 144.9631), 13.0);
        },
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(-37.8136, 144.9631),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'cher0022@student.monash.edu',
        ),
        MarkerLayer(markers: _markers),
      ],
    );
  }
}
