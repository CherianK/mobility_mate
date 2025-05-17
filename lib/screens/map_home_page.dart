import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import '../models/marker_type.dart';
import '../widgets/search_bar.dart';
import '../widgets/location_bottom_sheet.dart';
import '../widgets/toilet_finder_bottom_sheet.dart';
import '../utils/location_helper.dart'; // 
import '../providers/theme_provider.dart';
import '../utils/tag_formatter.dart';


class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  late MapboxMap _mapboxMap;
  bool _isLoading = true;
  bool _isLocating = false;
  Timer? _zoomTimer;
  bool _mapReady = false;

  final Map<MarkerType, PointAnnotationManager> _annotationManagers = {};
  final Map<MarkerType, List<PointAnnotationOptions>> _markerOptions = {};
  final Map<MarkerType, List<Map<String, dynamic>>> _markerPayloads = {};
  final Map<MarkerType, List<PointAnnotation>> _activeMarkers = {};
final Map<String, Map<String, dynamic>> _markerData = {};
  /// Keeps track of the bottom‑sheet that is currently displayed
  Future<void>? _activeSheet;

  static const _baseUrl = 'https://mobility-mate.onrender.com';

  // Default Melbourne center (will update later if user location fetched)
  final Point _initialCameraCenter = Point(coordinates: Position(144.9631, -37.8136));

  @override
  void initState() {
    super.initState();
  }

  Future<void> _onMapInitialized(MapboxMap map) async {
    _mapboxMap = map;
    await _initAllTypes();
    _startZoomListener();
    
    // Quietly try to get user location, fallback to Melbourne if not available
    final position = await LocationHelper.getCurrentLocation();
    if (position != null) {
      // Enable the location component with pulsing effect before centering
      await _mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: Colors.blue.value,
          pulsingMaxRadius: 50.0,
        ),
      );
      
      await _mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      debugPrint(' Initial centering on user location: ${position.latitude}, ${position.longitude}');
    } else {
      debugPrint(' Using Melbourne center for initial load');
    }
    
    setState(() {
      _mapReady = true;
      _isLoading = false;
    });
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location services are disabled. Please enable location services in your device settings.',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () async {
                await geo.Geolocator.openLocationSettings();
              },
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location permission denied. Please enable location permissions to use this feature.',
                style: TextStyle(color: Colors.white),
              ),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () async {
                  await geo.Geolocator.openAppSettings();
                },
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permissions are permanently denied. Please enable them in app settings.',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () async {
                await geo.Geolocator.openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      
      // Enable the location component with pulsing effect
      await _mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: Colors.blue.value,
          pulsingMaxRadius: 50.0,
        ),
      );

      // Center the map on the user's location
      await _mapboxMap.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );

      debugPrint(' Centered on user location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint(' Error getting location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to get your location. Please try again.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  @override
  void dispose() {
    _zoomTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    // Update map style when theme changes
    if (_mapReady) {
      _updateMapStyle(isDark);
    }
    
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('map'),
            styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
            cameraOptions: CameraOptions(
              center: _initialCameraCenter,
              zoom: 13.0,
            ),
            onMapCreated: _onMapInitialized,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_mapReady) ...[
            // Floating search bar with theme toggle
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: SearchBarWidget(mapboxMap: _mapboxMap),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        final themeProvider = context.read<ThemeProvider>();
                        final newMode = themeProvider.themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                        themeProvider.setThemeMode(newMode);
                      },
                      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    ),
                  ),
                ],
              ),
            ),
            // Map controls
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 80,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'location',
                    onPressed: _isLocating ? null : _goToCurrentLocation,
                    child: _isLocating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'toilet_finder',
                    onPressed: () => _showToiletFinderBottomSheet(context),
                    tooltip: 'Find Nearest Toilets',
                    child: const Icon(Icons.wc),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'zoom_in',
                    onPressed: () async {
                      final zoom = await _mapboxMap.getCameraState().then((s) => s.zoom);
                      await _mapboxMap.flyTo(
                        CameraOptions(zoom: zoom + 1),
                        MapAnimationOptions(duration: 300),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'zoom_out',
                    onPressed: () async {
                      final zoom = await _mapboxMap.getCameraState().then((s) => s.zoom);
                      await _mapboxMap.flyTo(
                        CameraOptions(zoom: zoom - 1),
                        MapAnimationOptions(duration: 300),
                      );
                    },
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _initAllTypes() async {
    // Create a single click listener that will handle all marker types
    bool isProcessingClick = false;

    for (var type in MarkerType.values) {
      final currentType = type; // capture value for callbacks
      final mgr = await _mapboxMap.annotations.createPointAnnotationManager();
      _annotationManagers[type] = mgr;
      _activeMarkers[type] = [];

      await _fetchType(type);

      mgr.addOnPointAnnotationClickListener(
        PointAnnotationClickListener(onClicked: (annotation) {
          // If we're already processing a click, ignore this one
          if (isProcessingClick) {
            return;
          }
          
          final data = _markerData[annotation.id];
          if (data != null) {
            isProcessingClick = true;
            _showBottomSheet(annotation.id, currentType).then((_) {
              isProcessingClick = false;
            });
          }
        }),
      );
    }

    final z = await _mapboxMap.getCameraState().then((s) => s.zoom);
    await _updateVisibility(z);
  }

  Future<void> _fetchType(MarkerType type) async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/${type.endpoint}'));
      if (resp.statusCode != 200) {
        debugPrint(' ${type.name} API error ${resp.statusCode}');
        return;
      }

      final List<dynamic> list = json.decode(resp.body);
      debugPrint(' ${list.length} ${type.name}s fetched');

      _markerPayloads[type] = list.cast<Map<String, dynamic>>();

      _markerOptions[type] = [
        for (var item in list)
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(
              (item['Location_Lon'] as num).toDouble(),
              (item['Location_Lat'] as num).toDouble(),
            )),
            iconImage: type.iconName,
            iconSize: type.size,
            iconColor: type.color.toARGB32(),
          )
      ];
    } catch (e) {
      debugPrint(' Error fetching ${type.name}: $e');
    }
  }

  void _startZoomListener() {
    _zoomTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final z = await _mapboxMap.getCameraState().then((s) => s.zoom);
      await _updateVisibility(z);
    });
  }

  Future<void> _updateVisibility(double zoom) async {
    for (var type in MarkerType.values) {
      final mgr = _annotationManagers[type]!;
      final opts = _markerOptions[type]!;
      final payloads = _markerPayloads[type]!;

      if (type.isVisibleAtZoom(zoom)) {
        if (_activeMarkers[type]!.isEmpty) {
          final created = await mgr.createMulti(opts);
          final List<PointAnnotation> nonNull = <PointAnnotation>[];
          for (var i = 0; i < created.length; i++) {
            final ann = created[i];
            if (ann != null) {
              nonNull.add(ann);
              // Store both the payload data and the marker type
              _markerData[ann.id] = {
                ...payloads[i],
                'marker_type': type,
              };
            }
          }
          _activeMarkers[type] = nonNull;
          debugPrint(' Show ${type.name} markers at zoom $zoom');
        }
      } else {
        if (_activeMarkers[type]!.isNotEmpty) {
          await mgr.deleteAll();
          _activeMarkers[type] = [];
          debugPrint(' Hide ${type.name} markers at zoom $zoom');
        }
      }
    }
  }

  Future<void> _showBottomSheet(String id, MarkerType type) async {
    // If a sheet is already open, dismiss it and wait until it is gone
    if (_activeSheet != null) {
      Navigator.of(context).pop();
      await _activeSheet;
    }

    if (!mounted) return;

    final data = _markerData[id]!;
    final markerType = data['marker_type'] as MarkerType;
    String title;
    if (markerType == MarkerType.toilet) {
      title = markerType.displayName;
    } else {
      // Try to get the name from Tags['name'], Tags['Name'], Metadata['name'], or Metadata['Name']
      final tags = data['Tags'] as Map<String, dynamic>?;
      final metadata = data['Metadata'] as Map<String, dynamic>?;
      String? name =
        (tags?['name'] ?? tags?['Name'] ?? metadata?['name'] ?? metadata?['Name'])?.toString().trim();
      // Map MarkerType to expected string for formatter
      String markerTypeString;
      switch (markerType) {
        case MarkerType.train:
          markerTypeString = 'trains';
          break;
        case MarkerType.tram:
          markerTypeString = 'trams';
          break;
        case MarkerType.hospital:
          markerTypeString = 'medical';
          break;
        default:
          markerTypeString = markerType.name;
      }
      title = formatMarkerDisplayName(
        name: name,
        markerType: markerTypeString,
      ) ?? markerType.displayName;
    }

    final sheetFuture = showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LocationBottomSheet(
        data: data,
        title: title,
        iconGetter: markerType.iconGetter,
        onClose: () => Navigator.of(sheetCtx).maybePop(),
      ),
    );
    
    _activeSheet = sheetFuture;
    await sheetFuture;
    _activeSheet = null;
  }

  Future<void> _updateMapStyle(bool isDark) async {
    try {
      await _mapboxMap.style.setStyleURI(isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS);
      // Re-add markers after style change
      final zoom = await _mapboxMap.getCameraState().then((s) => s.zoom);
      await _updateVisibility(zoom);
    } catch (e) {
      debugPrint('Error updating map style: $e');
    }
  }

  Future<void> _showToiletFinderBottomSheet(BuildContext context) async {
    // If a sheet is already open, dismiss it and wait until it is gone
    if (_activeSheet != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).maybePop();
      }
      await _activeSheet;
    }

    if (!mounted) return;

    // Get current user location
    geo.Position? userPosition = await LocationHelper.getCurrentLocation();
    if (userPosition == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. This feature is available when your location services are turned on. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get all toilet markers data
    List<Map<String, dynamic>> allToilets = [];
    if (_markerPayloads.containsKey(MarkerType.toilet)) {
      final toiletPayloads = _markerPayloads[MarkerType.toilet]!;
      
      // Calculate distance for each toilet from current user position
      for (var toilet in toiletPayloads) {
        final tags = toilet['Tags'] as Map<String, dynamic>? ?? {};
        
        // Continue with existing code to calculate distance
        final toiletLat = (toilet['Location_Lat'] as num).toDouble();
        final toiletLon = (toilet['Location_Lon'] as num).toDouble();
        
        // Calculate distance in kilometers
        final distanceInMeters = geo.Geolocator.distanceBetween(
          userPosition.latitude, 
          userPosition.longitude, 
          toiletLat, 
          toiletLon
        );
        
        allToilets.add({
          ...toilet,
          'distance': distanceInMeters / 1000, // Convert to kilometers
        });
      }
      
      // Sort toilets by distance (nearest first)
      allToilets.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );
      
      // Filter for wheelchair accessible toilets
      List<Map<String, dynamic>> accessibleToilets = allToilets.where((toilet) {
        final tags = toilet['Tags'] as Map<String, dynamic>? ?? {};
        final wheelchairValue = tags['Wheelchair']?.toString().toLowerCase() ?? '';
        return wheelchairValue == 'yes' || wheelchairValue == 'limited';
      }).toList();
      
      // If we found accessible toilets, use those, otherwise keep all toilets
      if (accessibleToilets.isNotEmpty) {
        allToilets = accessibleToilets;
      }
      
      // Take only the 3 nearest if there are more than 3
      if (allToilets.length > 3) {
        allToilets = allToilets.sublist(0, 3);
      }
    }

    Future<void> showToiletList() async {
      if (!mounted) return;
      
      try {
        // Set a flag to track if we're showing the sheet
        bool isShowingSheet = true;
        
        final result = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => ToiletFinderBottomSheet(
            userPosition: userPosition,
            nearbyToilets: allToilets,
          ),
        ).whenComplete(() {
          isShowingSheet = false;
        });
        
        // Only proceed if we're still mounted and the result is valid
        if (!mounted) return;
        
        // Handle the navigation result if a toilet was selected
        if (result != null && result['action'] == 'show_details') {
          await _showToiletLocationSheet(result['toilet_data'] as Map<String, dynamic>, showToiletList);
        }
      } catch (e) {
        debugPrint('Error in toilet finder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Only clear the active sheet if we're still mounted
        if (mounted) {
          _activeSheet = null;
        }
      }
    }
    
    // Show the toilet list initially
    await showToiletList();
  }
  
  // Helper method to show the location bottom sheet for a toilet
  Future<void> _showToiletLocationSheet(Map<String, dynamic> toiletData, Function showToiletListCallback) async {
    if (!mounted) return;
    
    // Add marker_type to the toilet data if not already present
    if (!toiletData.containsKey('marker_type')) {
      toiletData['marker_type'] = MarkerType.toilet;
    }
    
    // Generate a unique ID if not present
    final String toiletId = toiletData['id']?.toString() ?? 
                          'toilet_${DateTime.now().millisecondsSinceEpoch}';
    
    String title = MarkerType.toilet.displayName;
    
    // Try to get a more specific name if available
    final tags = toiletData['Tags'] as Map<String, dynamic>?;
    final metadata = toiletData['Metadata'] as Map<String, dynamic>?;
    String? name = (tags?['name'] ?? tags?['Name'] ?? 
                   metadata?['name'] ?? metadata?['Name'])?.toString().trim();
    
    if (name != null && name.isNotEmpty) {
      title = formatMarkerDisplayName(
        name: name,
        markerType: 'toilet',
      ) ?? title;
    }
    
    try {
      final sheetFuture = showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => LocationBottomSheet(
          data: toiletData,
          title: title,
          iconGetter: MarkerType.toilet.iconGetter,
          onClose: () {
            if (Navigator.of(sheetCtx).canPop()) {
              Navigator.of(sheetCtx).maybePop();
            }
          },
          showBackButton: true,
          onBack: () {
            // Close this sheet first
            if (Navigator.of(sheetCtx).canPop()) {
              Navigator.of(sheetCtx).pop();
              // Then reopen the toilet finder sheet if we're still mounted
              if (mounted) {
                showToiletListCallback();
              }
            }
          },
        ),
      );
      
      _activeSheet = sheetFuture;
      await sheetFuture;
      
      // Only clear the active sheet if we're still mounted
      if (mounted) {
        _activeSheet = null;
      }
    } catch (e) {
      debugPrint('Error showing toilet location sheet: $e');
      // Only clear the active sheet if we're still mounted
      if (mounted) {
        _activeSheet = null;
      }
    }
  }
}

/// Helper class for marker click
class PointAnnotationClickListener extends OnPointAnnotationClickListener {
  final bool Function(PointAnnotation) _onClick;
  PointAnnotationClickListener({required Function(PointAnnotation) onClicked})
      : _onClick = ((annotation) {
          onClicked(annotation);
          return true;
        });
  @override
  bool onPointAnnotationClick(PointAnnotation annotation) => _onClick(annotation);
}