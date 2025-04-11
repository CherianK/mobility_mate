import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'splash_screen.dart';
import 'search_page.dart';

void main() => runApp(const MyApp());

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
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/map': (context) => const MapHomePage(),
      },
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

// -------------------- NEW ICON FUNCTIONS --------------------

// A. Icons for toilets
IconData _getToiletIcon(String key, dynamic value) {
  final String tagKey = key.toLowerCase();
  final String tagValue = value.toString().toLowerCase();

  // "fee"
  if (tagKey == 'fee' && tagValue == 'yes') return Icons.attach_money;
  if (tagKey == 'fee' && tagValue == 'no') return Icons.money_off;

  // "drinking water"
  if (tagKey == 'drinking water' && tagValue == 'yes') return Icons.water_drop;
  if (tagKey == 'drinking water' && tagValue == 'no') return Icons.no_drinks;  
  if (tagKey == 'drinking water' && tagValue == 'seasonal') return Icons.opacity; 

  if (tagKey == 'access' && tagValue == 'customers') return Icons.store;
  if (tagKey == 'access' && tagValue == 'no') return Icons.block;
  if (tagKey == 'access' && tagValue == 'permissive') return Icons.check_circle_outline;
  if (tagKey == 'access' && tagValue == 'permit') return Icons.verified;
  if (tagKey == 'access' && tagValue == 'private') return Icons.lock;
  if (tagKey == 'access' && tagValue == 'public') return Icons.public;
  if (tagKey == 'access' && tagValue == 'yes') return Icons.check_circle;
  
  if (tagKey == 'all gender' && tagValue == 'no') return Icons.block;
  if (tagKey == 'all gender' && tagValue == 'yes') return Icons.group;

  if (tagKey == 'baby feeding' && tagValue == 'room') return Icons.child_friendly;

  if (tagKey == 'changing table' && tagValue == 'no') return Icons.block;
  if (tagKey == 'changing table' && (tagValue == 'room' || tagValue == 'yes')) {
    return Icons.change_circle;
  }

  if (tagKey == 'composting' && tagValue == 'yes') return Icons.eco;

  if (tagKey == 'disposal' && tagValue == 'chemical') return Icons.science;
  if (tagKey == 'disposal' && tagValue == 'flush') return Icons.local_drink;
  if (tagKey == 'disposal' && tagValue == 'pitlatrine') return Icons.warning;

  if (tagKey == 'female' && tagValue == 'no') return Icons.block;
  if (tagKey == 'female' && tagValue == 'yes') return Icons.female;

  if (tagKey == 'hands drying' && tagValue == 'electric hand dryer') return Icons.air;
  if (tagKey == 'handwashing' && tagValue == 'no') return Icons.block;
  if (tagKey == 'handwashing' && tagValue == 'yes') return Icons.clean_hands;

  if (tagKey == 'indoor' && tagValue == 'yes') return Icons.home;

  if (tagKey == 'male' && tagValue == 'no') return Icons.block;
  if (tagKey == 'male' && tagValue == 'yes') return Icons.male;
  if (tagKey == 'menstrual products' && tagValue == 'no') return Icons.block;

  if (tagKey == 'parking_accessible' && tagValue == 'no') return Icons.block;
  if (tagKey == 'parking_accessible' && tagValue == 'yes') return Icons.local_parking;

  if (tagKey == 'portable' && tagValue == 'no') return Icons.block;
  if (tagKey == 'portable' && tagValue == 'yes') return Icons.wc;

  if (tagKey == 'position' && tagValue == 'inside') return Icons.meeting_room;
  if (tagKey == 'position' && tagValue == 'seated') return Icons.event_seat;
  if (tagKey == 'position' && tagValue == 'seated;urinal') return Icons.event_seat;
  if (tagKey == 'position' && tagValue == 'urinal') return Icons.wc;

  if (tagKey == 'shower' && tagValue == 'yes') return Icons.shower;
  if (tagKey == 'soap' && tagValue == 'yes') return Icons.local_laundry_service;

  if (tagKey == 'unisex' && tagValue == 'no') return Icons.block;
  if (tagKey == 'unisex' && tagValue == 'yes') return Icons.transgender;

  if (tagKey == 'wheelchair' && tagValue == 'designated') return Icons.accessible;
  if (tagKey == 'wheelchair' && tagValue == 'limited') return Icons.accessibility_new;
  if (tagKey == 'wheelchair' && tagValue == 'no') return Icons.block;
  if (tagKey == 'wheelchair' && tagValue == 'yes') return Icons.accessible;

  // Fallback default for toilets
  return Icons.info;
}

// B. Icons for trains
IconData _getTrainIcon(String key, dynamic value) {
  final String tagKey = key.toLowerCase();
  final String tagValue = value.toString().toLowerCase();

  if (tagKey == 'passenger_information_display' && tagValue == 'yes') return Icons.info;
  if (tagKey == 'passenger_information_display' && tagValue == 'no') return Icons.info_outline;

  if (tagKey == 'lit' && tagValue == 'yes') return Icons.light_mode;
  if (tagKey == 'lit' && tagValue == 'no') return Icons.lightbulb_outline;

  if (tagKey == 'shelter' && tagValue == 'yes') return Icons.house;
  if (tagKey == 'shelter' && tagValue == 'no') return Icons.house_siding;

  if (tagKey == 'bench' && tagValue == 'yes') return Icons.weekend;
  if (tagKey == 'bench' && tagValue == 'no') return Icons.event_busy;

  if (tagKey == 'bus' && tagValue == 'yes') return Icons.directions_bus;

  if (tagKey == 'tactile_paving' && tagValue == 'yes') return Icons.gesture;
  if (tagKey == 'tactile_paving' && tagValue == 'no') return Icons.block;

  if (tagKey == 'wheelchair' && tagValue == 'yes') return Icons.accessible;
  if (tagKey == 'wheelchair' && tagValue == 'no') return Icons.accessible_forward;
  if (tagKey == 'wheelchair' && tagValue == 'limited') return Icons.accessibility;

  if (tagKey == 'covered' && tagValue == 'yes') return Icons.umbrella;

  if (tagKey == 'bin' && tagValue == 'yes') return Icons.delete;
  if (tagKey == 'bin' && tagValue == 'no') return Icons.delete_outline;

  if (tagKey == 'shelter_type' && tagValue == 'public_transport') return Icons.commute;

  if (tagKey == 'disabled_toilets' && tagValue == 'no') return Icons.wc;

  if (tagKey == 'departures_board' && tagValue == 'realtime') return Icons.update;
  if (tagKey == 'departures_board' && tagValue == 'timetable') return Icons.schedule;

  // Fallback
  return Icons.info;
}

// C. Icons for trams
IconData _getTramIcon(String key, dynamic value) {
  final String tagKey = key.toLowerCase();
  final String tagValue = value.toString().toLowerCase();

  if (tagKey == 'passenger_information_display' && tagValue == 'yes') return Icons.info;
  if (tagKey == 'passenger_information_display' && tagValue == 'no') return Icons.info_outline;

  if (tagKey == 'lit' && tagValue == 'yes') return Icons.light_mode;
  if (tagKey == 'lit' && tagValue == 'no') return Icons.lightbulb_outline;

  if (tagKey == 'shelter' && tagValue == 'yes') return Icons.house;
  if (tagKey == 'shelter' && tagValue == 'no') return Icons.house_siding;

  if (tagKey == 'bench' && tagValue == 'yes') return Icons.weekend;
  if (tagKey == 'bench' && tagValue == 'no') return Icons.event_busy;

  if (tagKey == 'bus' && tagValue == 'yes') return Icons.directions_bus;

  if (tagKey == 'tactile_paving' && tagValue == 'yes') return Icons.gesture;
  if (tagKey == 'tactile_paving' && tagValue == 'no') return Icons.block;

  if (tagKey == 'wheelchair' && tagValue == 'yes') return Icons.accessible;
  if (tagKey == 'wheelchair' && tagValue == 'no') return Icons.accessible_forward;
  if (tagKey == 'wheelchair' && tagValue == 'limited') return Icons.accessibility;

  if (tagKey == 'covered' && tagValue == 'yes') return Icons.umbrella;

  if (tagKey == 'bin' && tagValue == 'yes') return Icons.delete;
  if (tagKey == 'bin' && tagValue == 'no') return Icons.delete_outline;

  if (tagKey == 'shelter_type' && tagValue == 'public_transport') return Icons.commute;

  if (tagKey == 'disabled_toilets' && tagValue == 'no') return Icons.wc;

  if (tagKey == 'departures_board' && tagValue == 'realtime') return Icons.update;
  if (tagKey == 'departures_board' && tagValue == 'timetable') return Icons.schedule;

  // Fallback
  return Icons.info;
}

// D. Icons for medical
IconData _getHospitalIcon(String key, dynamic value) {
  final String tagKey = key.toLowerCase();
  final String tagValue = value.toString().toLowerCase();

  // Healthcare types
  if (tagKey == 'healthcare' && tagValue == 'hospital') return Icons.local_hospital;
  if (tagKey == 'healthcare' && tagValue == 'clinic') return Icons.local_hospital;
  if (tagKey == 'healthcare' && tagValue == 'doctor') return Icons.medical_services;
  if (tagKey == 'healthcare' && tagValue == 'pharmacy') return Icons.local_pharmacy;
  if (tagKey == 'healthcare' && tagValue == 'physiotherapist') return Icons.accessibility_new;
  if (tagKey == 'healthcare' && tagValue == 'dentist') return Icons.medical_information;
  if (tagKey == 'healthcare' && tagValue == 'alternative') return Icons.spa;
  if (tagKey == 'healthcare' && tagValue == 'blood_donation') return Icons.bloodtype;
  if (tagKey == 'healthcare' && tagValue == 'optometrist') return Icons.visibility;
  if (tagKey == 'healthcare' && tagValue == 'psychotherapist') return Icons.psychology;
  if (tagKey == 'healthcare' && tagValue == 'audiologist') return Icons.hearing;
  if (tagKey == 'healthcare' && tagValue == 'laboratory') return Icons.biotech;
  if (tagKey == 'healthcare' && tagValue == 'sample_collection') return Icons.science;

  // Wheelchair access
  if (tagKey == 'wheelchair' && tagValue == 'yes') return Icons.accessible;
  if (tagKey == 'wheelchair' && tagValue == 'no') return Icons.block;
  if (tagKey == 'wheelchair' && tagValue == 'limited') return Icons.accessible_forward;
  if (tagKey == 'wheelchair' && tagValue == 'designated') return Icons.accessibility;

  // Amenity types
  if (tagKey == 'amenity' && tagValue == 'clinic') return Icons.local_hospital;
  if (tagKey == 'amenity' && tagValue == 'pharmacy') return Icons.local_pharmacy;
  if (tagKey == 'amenity' && tagValue == 'doctors') return Icons.medical_services;
  if (tagKey == 'amenity' && tagValue == 'dentist') return Icons.medical_information;
  if (tagKey == 'amenity' && tagValue == 'hospital') return Icons.local_hospital;

  // Other metadata
  if (tagKey == 'opening_hours') return Icons.access_time;
  if (tagKey == 'phone') return Icons.phone;
  if (tagKey == 'website') return Icons.language;
  if (tagKey == 'name') return Icons.label;
  if (tagKey == 'brand') return Icons.store;
  if (tagKey == 'operator') return Icons.account_circle;

  // Default icon
  return Icons.info;
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();
  
  /// Holds the combined markers (toilets, trains, trams)
  List<Marker> _markers = [];
  
  /// Current zoom level of the map
  double _currentZoom = 15.0;
  
  /// Currently selected toilet, train, or tram data
  Map<String, dynamic>? _selectedToilet;
  Map<String, dynamic>? _selectedTrain;
  Map<String, dynamic>? _selectedTram;
  Map<String, dynamic>? _selectedHospital;

  /// Bottom sheet visibility
  bool _isBottomSheetVisible = false;

  @override
  void initState() {
    super.initState();
    fetchAllLocations();
    
    // Add listener for map movement to track zoom level
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
      // Fetch from endpoints
      final toiletResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/toilet-location-points'),
      );
      final trainResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/train-location-points'),
      );
      final tramResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/tram-location-points'),
      );
      final medicalResponse = await http.get(
        Uri.parse('https://mobility-mate.onrender.com/medical-location-points'),
      );

      if (toiletResponse.statusCode == 200 &&
          trainResponse.statusCode == 200 &&
          tramResponse.statusCode == 200 &&
          medicalResponse.statusCode == 200) {
        final List<dynamic> toiletData = json.decode(toiletResponse.body);
        final List<dynamic> trainData = json.decode(trainResponse.body);
        final List<dynamic> tramData = json.decode(tramResponse.body);
        final List<dynamic> medicalData = json.decode(medicalResponse.body);

        // Create markers for toilets
        final toiletMarkers = toiletData.map<Marker>((doc) {
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
                  // Clear other selections
                  _selectedTrain = null;
                  _selectedTram = null;
                  _selectedHospital = null;
                  // Set toilet data
                  _selectedToilet = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
              },
              child: const Icon(
                Icons.wc,
                size: 42,
                color: Color.fromRGBO(255, 0, 0, 1),
              ),
            ),
          );
        }).toList();

        // Markers for trains
        final trainMarkers = trainData.map<Marker>((doc) {
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
                  // Clear other selections
                  _selectedToilet = null;
                  _selectedTram = null;
                  _selectedHospital = null;
                  // Set train data
                  _selectedTrain = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
              },
              child: const Icon(
                Icons.train,
                size: 42,
                color: Color.fromRGBO(25, 0, 255, 1),
              ),
            ),
          );
        }).toList();

        // Markers for trams
        final tramMarkers = tramData.map<Marker>((doc) {
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
                  // Clear other selections
                  _selectedToilet = null;
                  _selectedTrain = null;
                  _selectedHospital = null;
                  // Set tram data
                  _selectedTram = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
              },
              child: const Icon(
                Icons.tram,
                size: 42,
                color: Color.fromRGBO(255, 94, 0, 1),
              ),
            ),
          );
        }).toList();

        // Markers for medical
        final medicalMarkers = medicalData.map<Marker>((doc) {
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
                  // Don't show bottom sheet for medical
                  _selectedToilet = null;
                  _selectedTrain = null;
                  _selectedTram = null;
                  _isBottomSheetVisible = false;
                  _selectedHospital = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
              },
              child: const Icon(
                Icons.local_hospital,
                size: 42,
                color: Color.fromRGBO(128, 0, 128, 1),
              ),
            ),
          );
        }).toList();

        setState(() {
          _markers = [
            ...toiletMarkers,
            ...trainMarkers,
            ...tramMarkers,
            ...medicalMarkers,
          ];
        });
      } else {
        debugPrint(
          'Failed to load data. Status codes: '
          'Toilets=${toiletResponse.statusCode}, '
          'Trains=${trainResponse.statusCode}, '
          'Trams=${tramResponse.statusCode}, '
          'Medical=${medicalResponse.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  /// Format tag string if you want to display them
  String formatTag(String key, dynamic value) {
    // Just an example
    List<String> words = key.split('_');
    String formattedKey = words
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
    String formattedValue = value.toString();
    if (formattedValue.isNotEmpty) {
      formattedValue =
          formattedValue[0].toUpperCase() + formattedValue.substring(1).toLowerCase();
    }
    return '$formattedKey: $formattedValue';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),

          // Floating search bar
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchPage()),
                );
                if (result != null && result is Map<String, dynamic>) {
                  final lat = result['lat'] as double;
                  final lon = result['lon'] as double;
                  _mapController.moveAndRotate(LatLng(lat, lon), 15.0, 0.0);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 1),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      "Search for a location...",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Draggable bottom sheet
          if (_isBottomSheetVisible)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // When the sheet is dragged near min (like ~20%),
                // hide if you want that behavior
                if (notification.extent <= 0.22) {
                  setState(() {
                    _isBottomSheetVisible = false;
                  });
                }
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.4,
                minChildSize: 0.2,
                maxChildSize: 0.85,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      //color: Color.fromARGB(255, 32, 32, 36),
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: _buildBottomSheetContent(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Center the map on Melbourne',
        child: const Icon(Icons.location_city),
        onPressed: () {
          setState(() {
            _isBottomSheetVisible = false;
          });
          _popupController.hideAllPopups();
          _mapController.moveAndRotate(LatLng(-37.8136, 144.9631), 15.5, 0.0);
        },
      ),
    );
  }

  // Add a helper function inside _MapHomePageState to build a hospital row:
  Widget hospitalRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(_getHospitalIcon(key, value), size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              formatTag(key, value),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(-37.8136, 144.9631),
        initialZoom: 15.5,
        onTap: (_, __) {
          _popupController.hideAllPopups();
          setState(() {
            _isBottomSheetVisible = false;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'cher0022@student.monash.edu',
        ),
        if (_currentZoom > 11 && _currentZoom < 16)
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              disableClusteringAtZoom: 16,
              maxClusterRadius: 150,
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

        // Show individual markers only for zoom >= 16
        if (_currentZoom >= 16)
          MarkerLayer(
            markers: _markers,
          )
      ],
    );
  }

  Widget _buildBottomSheetContent() {
    // 1) If a train is selected, show train icons
    if (_selectedTrain != null) {
      final doc = _selectedTrain!;
      final Map<String, dynamic> tags = doc['Tags'] ?? {};
      // Filter or show all
      final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
      final List<MapEntry<String, dynamic>> orderedTags = [];
      // Add the wheelchair tag first (if it exists)
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'wheelchair') {
          orderedTags.add(entry);
        }
      }
      // Then add the disabled_toilets tag (if it exists)
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'disabled_toilets') {
          orderedTags.add(entry);
        }
      }
      // Then add the rest (sorted by key, for example)
      final remaining = allTags.where((entry) => entry.key.toLowerCase() != 'wheelchair'
          && entry.key.toLowerCase() != 'disabled_toilets').toList();
      remaining.sort((a, b) => a.key.compareTo(b.key));
      orderedTags.addAll(remaining);

      // Filter out empty tags
      if (orderedTags.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No train information available'),
        );
      } else {
        final String trainTitle = (() {
          String t = 'Train Information';
          final nameKey = tags.keys.firstWhere(
            (key) => key.toLowerCase() == 'name',
            orElse: () => ''
          );
          if (nameKey.isNotEmpty && tags[nameKey].toString().trim().isNotEmpty) {
            t = tags[nameKey].toString();
          }
          return t;
        })();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                trainTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Grid of icons
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: orderedTags.length,
              itemBuilder: (context, index) {
                final entry = orderedTags[index];
                final key = entry.key;
                final value = entry.value;
                final icon = _getTrainIcon(key, value);

                return Card(
                  // color: const Color.fromRGBO(32, 33, 36, 1), // Dark background, comment out if not necessary
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon, 
                        size: 36,
                        // color: const Color(0xFFE8EAED)          // Light text/icon color
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatTag(key, value),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            // color: Color(0xFFE8EAED)            // Light text/icon color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }
    }

    // 2) If a hospital is selected, show hospital icons
    else if (_selectedHospital != null) {
      final Map<String, dynamic> tags = _selectedHospital!['Tags'] ?? {};
      
      // Define the fixed order keys
      final List<String> fixedKeys = [
        'wheelchair',
        'healthcare',
        'name',
        'amenity',
        'opening_hours',
        'phone',
        'website'
      ];
      
      List<Widget> rows = [];
      
      // Add fixed order rows if available in the tags
      for (String key in fixedKeys) {
        if (tags.containsKey(key)) {
          rows.add(hospitalRow(key, tags[key]));
        }
      }
      
      // Add the remaining keys (sorted alphabetically)
      final List<String> remainingKeys = tags.keys
          .where((k) => !fixedKeys.contains(k))
          .toList()
            ..sort();
      for (String key in remainingKeys) {
        rows.add(hospitalRow(key, tags[key]));
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Hospital Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...rows,
        ],
      );
    }

    // 3) If a tram is selected, show tram icons
    else if (_selectedTram != null) {
      final doc = _selectedTram!;
      final Map<String, dynamic> tags = doc['Tags'] ?? {};
      final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
      final List<MapEntry<String, dynamic>> orderedTags = [];

      // Add the wheelchair tag first (if it exists)
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'wheelchair') {
          orderedTags.add(entry);
        }
      }

      // Then add the disabled_toilets tag (if it exists)
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'disabled_toilets') {
          orderedTags.add(entry);
        }
      }

      // Then add the rest (sorted by key, for example)
      final remaining = allTags.where((entry) => entry.key.toLowerCase() != 'wheelchair'
          && entry.key.toLowerCase() != 'disabled_toilets').toList();
      remaining.sort((a, b) => a.key.compareTo(b.key));
      orderedTags.addAll(remaining);

      if (orderedTags.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No tram information available'),
        );
      } else {
        final String tramTitle = (() {
          String t = 'Tram Information';
          final nameKey = tags.keys.firstWhere(
            (key) => key.toLowerCase() == 'name',
            orElse: () => ''
          );
          if (nameKey.isNotEmpty && tags[nameKey].toString().trim().isNotEmpty) {
            t = tags[nameKey].toString();
          }
          return t;
        })();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                tramTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: orderedTags.length,
              itemBuilder: (context, index) {
                final entry = orderedTags[index];
                final key = entry.key;
                final value = entry.value;
                final icon = _getTramIcon(key, value);

                return Card(
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        formatTag(key, value),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }
    }

    // 4) If a toilet is selected, show toilet icons
    else if (_selectedToilet != null) {
      final Map<String, dynamic> tags = _selectedToilet!['Tags'] ?? {};
      final List<MapEntry<String, dynamic>> allTags = tags.entries.toList();
      final List<MapEntry<String, dynamic>> orderedTags = [];

      // Add the wheelchair tag first (if it exists)
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'wheelchair') {
          orderedTags.add(entry);
        }
      }

      // Next, add the access tag
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'access') {
          orderedTags.add(entry);
        }
      }

      // Next, add the parking_accessible tag
      for (var entry in allTags) {
        if (entry.key.toLowerCase() == 'parking_accessible') {
          orderedTags.add(entry);
        }
      }

      // Then add the remaining tags
      final remaining = allTags.where((entry) => entry.key.toLowerCase() != 'wheelchair'
          && entry.key.toLowerCase() != 'access'
          && entry.key.toLowerCase() != 'parking_accessible').toList();
      remaining.sort((a, b) => a.key.compareTo(b.key));
      orderedTags.addAll(remaining);

      if (orderedTags.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No accessibility information available'),
        );
      } else {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Accessibility Features',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: orderedTags.length,
              itemBuilder: (context, index) {
                final entry = orderedTags[index];
                final key = entry.key;
                final value = entry.value;
                final icon = _getToiletIcon(key, value);

                return Card(
                  elevation: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        formatTag(key, value),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }
    }

    // Otherwise
    return const Center(
      child: Text('No marker selected'),
    );
  }
}