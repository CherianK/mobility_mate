import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
  const MapHomePage({Key? key}) : super(key: key);

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();

  /// Holds the combined markers (toilets, trains, trams)
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    fetchAllLocations();
  }

  /// Fetch toilets, trains, and trams from separate endpoints,
  /// then create different markers for each dataset.
  Future<void> fetchAllLocations() async {
    try {
      // Fetch toilet data
      final toiletResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/toilet-location-points'),
      );

      // Fetch train data
      final trainResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/train-location-points'),
      );

      // Fetch tram data
      final tramResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/tram-location-points'),
      );

      if (toiletResponse.statusCode == 200 &&
          trainResponse.statusCode == 200 &&
          tramResponse.statusCode == 200) {
        final List<dynamic> toiletData = json.decode(toiletResponse.body);
        final List<dynamic> trainData = json.decode(trainResponse.body);
        final List<dynamic> tramData = json.decode(tramResponse.body);

        // Markers for toilets -> Red location pin
        final toiletMarkers = toiletData.map<Marker>((doc) {
          final lat = (doc['Location_Lat'] as num).toDouble();
          final lon = (doc['Location_Lon'] as num).toDouble();

          return Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_on,
              size: 36,
              color: Colors.red,
            ),
          );
        }).toList();

        // Markers for trains -> Blue train icon
        final trainMarkers = trainData.map<Marker>((doc) {
          final lat = (doc['Location_Lat'] as num).toDouble();
          final lon = (doc['Location_Lon'] as num).toDouble();

          return Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: const Icon(
              Icons.train,
              size: 36,
              color: Colors.blue,
            ),
          );
        }).toList();

        // Markers for trams -> Green tram icon
        final tramMarkers = tramData.map<Marker>((doc) {
          final lat = (doc['Location_Lat'] as num).toDouble();
          final lon = (doc['Location_Lon'] as num).toDouble();

          return Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: const Icon(
              Icons.tram,
              size: 36,
              color: Colors.green,
            ),
          );
        }).toList();

        setState(() {
          // Combine all markers into one list
          _markers = [
            ...toiletMarkers,
            ...trainMarkers,
            ...tramMarkers,
          ];
        });
      } else {
        debugPrint(
          'Failed to load data. Status codes: '
          'Toilets=${toiletResponse.statusCode}, '
          'Trains=${trainResponse.statusCode}, '
          'Trams=${tramResponse.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMap(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.star),
        onPressed: () {
          // Re-center the map on Melbourne
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
