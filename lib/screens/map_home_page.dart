import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../utils/icon_utils.dart';
import '../utils/tag_formatter.dart';
import '../widgets/location_bottom_sheet.dart';
import '../widgets/search_bar.dart';
import 'search_page.dart';

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();

  List<Marker> _markers = [];
  double _currentZoom = 15.0;

  Map<String, dynamic>? _selectedToilet;
  Map<String, dynamic>? _selectedTrain;
  Map<String, dynamic>? _selectedTram;
  Map<String, dynamic>? _selectedHospital;

  bool _isBottomSheetVisible = false;

  @override
  void initState() {
    super.initState();
    fetchAllLocations();

    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd) {
        setState(() {
          _currentZoom = _mapController.camera.zoom;
        });
      }
    });
  }

  Future<void> fetchAllLocations() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://mobility-mate.onrender.com/toilet-location-points')),
        http.get(Uri.parse('https://mobility-mate.onrender.com/train-location-points')),
        http.get(Uri.parse('https://mobility-mate.onrender.com/tram-location-points')),
        http.get(Uri.parse('https://mobility-mate.onrender.com/medical-location-points')),
      ]);

      if (responses.every((res) => res.statusCode == 200)) {
        final toiletData = json.decode(responses[0].body);
        final trainData = json.decode(responses[1].body);
        final tramData = json.decode(responses[2].body);
        final medicalData = json.decode(responses[3].body);

        final toiletMarkers = _generateMarkers(toiletData, Icons.wc, 'toilet');
        final trainMarkers = _generateMarkers(trainData, Icons.train, 'train');
        final tramMarkers = _generateMarkers(tramData, Icons.tram, 'tram');
        final medicalMarkers = _generateMarkers(medicalData, Icons.local_hospital, 'hospital');

        setState(() {
          _markers = [
            ...toiletMarkers,
            ...trainMarkers,
            ...tramMarkers,
            ...medicalMarkers,
          ];
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  List<Marker> _generateMarkers(List<dynamic> data, IconData icon, String type) {
    return data.map<Marker>((doc) {
      final lat = (doc['Location_Lat'] as num).toDouble();
      final lon = (doc['Location_Lon'] as num).toDouble();

      return Marker(
        point: LatLng(lat, lon),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            _mapController.moveAndRotate(LatLng(lat, lon), _currentZoom, 0.0);
            _popupController.hideAllPopups();
            setState(() {
              _selectedToilet = null;
              _selectedTrain = null;
              _selectedTram = null;
              _selectedHospital = null;

              switch (type) {
                case 'toilet':
                  _selectedToilet = {'Tags': doc['Tags'] ?? {}};
                  break;
                case 'train':
                  _selectedTrain = {'Tags': doc['Tags'] ?? {}};
                  break;
                case 'tram':
                  _selectedTram = {'Tags': doc['Tags'] ?? {}};
                  break;
                case 'hospital':
                  _selectedHospital = {'Tags': doc['Tags'] ?? {}};
                  break;
              }

              _isBottomSheetVisible = true;
            });
          },
          child: Icon(
            icon,
            size: 42,
            color: type == 'toilet'
                ? const Color.fromRGBO(255, 0, 0, 1)
                : type == 'train'
                    ? const Color.fromRGBO(25, 0, 255, 1)
                    : type == 'tram'
                        ? const Color.fromRGBO(255, 94, 0, 1)
                        : const Color.fromRGBO(128, 0, 128, 1),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          SearchBarWidget(mapController: _mapController),
          if (_isBottomSheetVisible)
            LocationBottomSheet(
              toilet: _selectedToilet,
              train: _selectedTrain,
              tram: _selectedTram,
              hospital: _selectedHospital,
              onClose: () => setState(() => _isBottomSheetVisible = false),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Center the map on Melbourne',
        child: const Icon(Icons.location_city),
        onPressed: () {
          setState(() => _isBottomSheetVisible = false);
          _popupController.hideAllPopups();
          _mapController.moveAndRotate(LatLng(-37.8136, 144.9631), 14.5, 0.0);
        },
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(-37.8136, 144.9631),
        initialZoom: 14.5,
        onTap: (_, __) {
          _popupController.hideAllPopups();
          setState(() => _isBottomSheetVisible = false);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'cher0022@student.monash.edu',
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            disableClusteringAtZoom: 16,
            maxClusterRadius: 60,
            size: const Size(30, 30),
            markers: _markers,
            polygonOptions: const PolygonOptions(
              borderColor: Colors.blueAccent,
              color: Colors.black12,
              borderStrokeWidth: 3,
            ),
            builder: (context, markers) {
              return Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  markers.length.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
