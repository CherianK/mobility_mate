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
    fetchLocations(); // Fetch markers on widget load
  }

  /// Fetch all locations from Flask and convert them into Marker objects
  Future<void> fetchLocations() async {
    try {
      debugPrint("Starting to fetch locations...");

      // Replace 'localhost' with '10.0.2.2' if testing on Android emulator
      final response = await http.get(Uri.parse('http://127.0.0.1:5000/location-points'));
      debugPrint("Response: $response");
      debugPrint("HTTP request completed with status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint("Data fetched successfully: $data");

        setState(() {
          _markers = data.map<Marker>((location) {
            final double lat = location['lat'];
            final double lon = location['lon'];
            debugPrint("Creating marker for location: lat=$lat, lon=$lon");

            // 'properties' is optional; handle gracefully if it doesn't exist
            final Map<String, dynamic>? properties = location['properties'] as Map<String, dynamic>?;

            // For UI clarity, define the name or fallback to "Unknown"
            final String locationName = location['name'] ?? "Unknown Location";

            return Marker(
              point: LatLng(lat, lon),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                  // Add your onTap functionality here
                  debugPrint("Marker tapped at lat=$lat, lon=$lon");
                },
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
        initialCenter: LatLng(-38.76, 143.37),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'cher0022@student.monash.edu',
        ),
        MarkerLayer(markers: _markers),
      ],
    );
  }
}
