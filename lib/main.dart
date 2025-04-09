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
  const MapHomePage({Key? key}) : super(key: key);

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();
  
  /// Holds the combined markers (toilets, trains, trams)
  List<Marker> _markers = [];
  
  /// Current zoom level of the map
  double _currentZoom = 15.0;
  
  /// Currently selected toilet data
  Map<String, dynamic>? _selectedToilet;
  Map<String, dynamic>? _selectedTrain;
  Map<String, dynamic>? _selectedTram;
  
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
            child: GestureDetector(
              onTap: () {
                _mapController.moveAndRotate(LatLng(lat, lon), _currentZoom, 0.0);
                _popupController.hideAllPopups();
                setState(() {
                  _selectedTrain = null;
                  _selectedTram = null;

                  _selectedToilet = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
                debugPrint('Toilet marker tapped, showing bottom sheet');
              },
              child: const Icon(
                Icons.wc,
                size: 42,
                color: Color.fromRGBO(255, 0, 0, 1),
              ),
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
            child: GestureDetector(
              onTap: () {
                _mapController.moveAndRotate(LatLng(lat, lon), _currentZoom, 0.0);
                _popupController.hideAllPopups();
                setState(() {
                  _selectedToilet = null;
                  _selectedTram = null;                  
                  
                  _selectedTrain = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
                debugPrint('Train marker tapped, showing bottom sheet');
              },
              child: const Icon(
                Icons.train,
                size: 42,
                color: Color.fromRGBO(25, 0, 255, 1),
              ),
            )
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
            child: GestureDetector(
              onTap: () {
                _mapController.moveAndRotate(LatLng(lat, lon), _currentZoom, 0.0);
                _popupController.hideAllPopups();
                setState(() {
                  _selectedToilet = null;
                  _selectedTrain = null;

                  _selectedTram = {
                    'Tags': doc['Tags'] ?? {},
                  };
                  _isBottomSheetVisible = true;
                });
                debugPrint('Tram marker tapped, showing bottom sheet');
              },
              child: const Icon(
                Icons.tram,
                size: 42,
                color: Color.fromRGBO(255, 94, 0, 1),
              ),
            )
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

  /// Get the appropriate icon for a given tag key-value pair
  IconData _getIconForTag(String key, dynamic value) {
    // Convert key and value to lowercase for case-insensitive matching
    final String tagKey = key.toLowerCase();
    final String tagValue = value.toString().toLowerCase();
    
    // Check for specific key-value pairs and return appropriate icon
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
    if (tagKey == 'changing table' && (tagValue == 'room' || tagValue == 'yes')) return Icons.change_circle;
    if (tagKey == 'composting' && tagValue == 'yes') return Icons.eco;
    if (tagKey == 'disposal' && tagValue == 'chemical') return Icons.science;
    if (tagKey == 'disposal' && tagValue == 'flush') return Icons.local_drink;
    if (tagKey == 'disposal' && tagValue == 'pitlatrine') return Icons.warning;
    if (tagKey == 'drinking water' && tagValue == 'no') return Icons.block;
    if (tagKey == 'drinking water' && tagValue == 'seasonal') return Icons.opacity;
    if (tagKey == 'drinking water' && tagValue == 'yes') return Icons.water_drop;
    if (tagKey == 'fee' && tagValue == 'no') return Icons.money_off;
    if (tagKey == 'fee' && tagValue == 'yes') return Icons.attach_money;
    if (tagKey == 'female' && tagValue == 'no') return Icons.block;
    if (tagKey == 'female' && tagValue == 'yes') return Icons.female;
    if (tagKey == 'hands drying' && tagValue == 'electric hand dryer') return Icons.air;
    if (tagKey == 'handwashing' && tagValue == 'no') return Icons.block;
    if (tagKey == 'handwashing' && tagValue == 'yes') return Icons.clean_hands;
    if (tagKey == 'indoor' && tagValue == 'yes') return Icons.home;
    if (tagKey == 'male' && tagValue == 'no') return Icons.block;
    if (tagKey == 'male' && tagValue == 'yes') return Icons.male;
    if (tagKey == 'menstrual products' && tagValue == 'no') return Icons.block;
    if (tagKey == 'parkingaccessible' && tagValue == 'no') return Icons.block;
    if (tagKey == 'parkingaccessible' && tagValue == 'yes') return Icons.local_parking;
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
    
    // Default icon if no match is found
    return Icons.info;
  }

  /// Process tags from the toilet data
  List<MapEntry<String, dynamic>> _processTags(Map<String, dynamic>? tags) {
    if (tags == null) return [];
    
    // Create a list of tag entries to display
    final List<MapEntry<String, dynamic>> tagEntries = tags.entries.toList();
    
    // Filter out any tags that don't match our icon set
    final List<MapEntry<String, dynamic>> filteredTags = tagEntries.where((entry) {
      final String key = entry.key.toLowerCase();
      final String value = entry.value.toString().toLowerCase();
      
      // Check if this key-value pair has a matching icon
      return _getIconForTag(key, value) != Icons.info;
    }).toList();
    
    return filteredTags;
  }

/// Returns a neatly formatted string for a given tag key and value.
/// It replaces underscores in the key with spaces and capitalizes each word.
/// It also capitalizes the value if appropriate.
String formatTag(String key, dynamic value) {
  // Replace underscores with spaces, and capitalize each word in the key.
  List<String> words = key.split('_');
  String formattedKey = words
      .map((word) => word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '')
      .join(' ');

  // Format the value as a string.
  String formattedValue = value.toString();
  if (formattedValue.isNotEmpty) {
    // Capitalize first letter and make the rest lowercase.
    formattedValue =
        formattedValue[0].toUpperCase() + formattedValue.substring(1).toLowerCase();
  }

  return '$formattedKey: $formattedValue';
}

  /// Build the bottom sheet content
  Widget _buildBottomSheetContent() {
  // If a train is selected
    if (_selectedTrain != null) {
      final doc = _selectedTrain!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Draggable handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Train Information', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Display lat/lon or anything else from doc
            // Text('Latitude: ${doc['Location_Lat']}'),
            // Text('Longitude: ${doc['Location_Lon']}'),

            // Possibly also show tags
            if (doc['Tags'] != null && doc['Tags'] is Map) ...[
              const SizedBox(height: 8),
              Text('Tags:'),
              Builder(
                builder: (context) {
                  final tagMap = doc['Tags'] as Map<String, dynamic>;
                  final tagString = tagMap.entries
                      .map((entry) => formatTag(entry.key, entry.value))
                      .join('\n');
                  return Text(tagString);
                },
              )
            ],
          ],
        ),
      );
    }
    // If a tram is selected
    else if (_selectedTram != null) {
      final doc = _selectedTram!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Draggable handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Tram Information', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Text('Latitude: ${doc['Location_Lat']}'),
            // Text('Longitude: ${doc['Location_Lon']}'),

            if (doc['Tags'] != null && doc['Tags'] is Map) ...[
              const SizedBox(height: 8),
              Text('Tags:'),
              Builder(
                builder: (context) {
                  final tagMap = doc['Tags'] as Map<String, dynamic>;
                  final tagString = tagMap.entries
                      .map((entry) => formatTag(entry.key, entry.value))
                      .join('\n');
                  return Text(tagString);
                },
              )
            ],
          ],
        ),
      );
    }
    // Otherwise, if a toilet is selected, show the existing toilet content
    else if (_selectedToilet != null) {
      final Map<String, dynamic> tags = _selectedToilet!['Tags'] ?? {};
      final List<MapEntry<String, dynamic>> filteredTags = _processTags(tags);

      if (filteredTags.isEmpty) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No accessibility information available'),
            ),
          ],
        );
      } else {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
              child: Text(
                'Accessibility Features',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredTags.length,
                itemBuilder: (context, index) {
                  final entry = filteredTags[index];
                  final String key = entry.key;
                  final String value = entry.value.toString();
                  final IconData icon = _getIconForTag(key, value);

                  return Card(
                    elevation: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 36),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            '$key: $value',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    } else {
      // If nothing is selected
      return const Center(
        child: Text('No marker selected'),
      );
    }
  }
  
  // Widget _buildBottomSheetContent() {
  //   if (_selectedToilet == null) {
  //     return const Center(child: Text('No toilet selected'));
  //   }

  //   // Extract tags from the selected toilet
  //   final Map<String, dynamic> tags = _selectedToilet!['Tags'] ?? {};
    
  //   // Process the tags
  //   final List<MapEntry<String, dynamic>> filteredTags = _processTags(tags);

  //   return Column(
  //     mainAxisSize: MainAxisSize.min,
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       //Handle bar for dragging
  //       Center(
  //         child: Container(
  //           margin: const EdgeInsets.only(top: 10, bottom: 2),
  //           width: 40,
  //           height: 4,
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             borderRadius: BorderRadius.circular(2),
  //           ),
  //         ),
  //       ),
        
  //       // const Divider(),
        
  //       //Accessibility features
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
  //         child: Text(
  //           'Accessibility Features',
  //           style: Theme.of(context).textTheme.titleMedium,
  //         ),
  //       ),
        
  //       // Grid of accessibility features
  //       if (filteredTags.isEmpty)
  //         const Padding(
  //           padding: EdgeInsets.all(16.0),
  //           child: Text('No accessibility information available'),
  //         )
  //       else
  //         Flexible(
  //           fit: FlexFit.loose,
  //           child: GridView.builder(
  //             shrinkWrap: true,
  //             physics: const NeverScrollableScrollPhysics(),
  //             padding: const EdgeInsets.all(16.0),
  //             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //               crossAxisCount: 3,
  //               childAspectRatio: 1,
  //               crossAxisSpacing: 16,
  //               mainAxisSpacing: 16,
  //             ),
  //             itemCount: filteredTags.length,
  //             itemBuilder: (context, index) {
  //               final entry = filteredTags[index];
  //               final String key = entry.key;
  //               final String value = entry.value.toString();
  //               final IconData icon = _getIconForTag(key, value);
                
  //               return Card(
  //                 elevation: 2,
  //                 child: Column(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(icon, size: 36),
  //                     const SizedBox(height: 8),
  //                     Padding(
  //                       padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //                       child: Text(
  //                         '$key: $value',
  //                         textAlign: TextAlign.center,
  //                         style: const TextStyle(fontSize: 12),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //     ],
  //   );
  // }

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

                debugPrint("Centering map to: $lat, $lon");
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
                    color: Colors.black.withOpacity(0.1),
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

        // Bottom sheet
        if (_isBottomSheetVisible)
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              // When dragged fully down (extent near the minimum), hide the sheet.
              if (notification.extent <= 0.22) {
                setState(() {
                  _isBottomSheetVisible = false;
                });
              }
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.4, // Starts at 40% of screen height
              minChildSize: 0.2,     // Allows collapsing
              maxChildSize: 0.85,    // Allows pulling up to 85% of screen
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
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
                      // Handle bar
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
                      // Scrollable content
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
      child: const Icon(Icons.star),
      onPressed: () {
        _mapController.moveAndRotate(LatLng(-37.8136, 144.9631), 13.0, 0.0);
      },
    ),
  );
}


  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(-37.8136, 144.9631),
        initialZoom: 15.0,
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
          //urlTemplate: "http://tile.stamen.com/toner-lite/{z}/{x}/{y}.png", 
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'cher0022@student.monash.edu',
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            disableClusteringAtZoom: 16,
            maxClusterRadius: 60  ,
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
