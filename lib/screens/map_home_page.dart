import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/marker_type.dart';
import '../widgets/search_bar.dart';
import '../widgets/location_bottom_sheet.dart';
import '../utils/location_helper.dart'; // 

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
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('map'),
            styleUri: MapboxStyles.MAPBOX_STREETS,
            cameraOptions: CameraOptions(
              center: _initialCameraCenter,
              zoom: 13.0,
            ),
            onMapCreated: _onMapInitialized,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_mapReady) ...[
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: SearchBarWidget(mapboxMap: _mapboxMap),
            ),
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
    final sheetFuture = showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LocationBottomSheet(
        data: data,
        title: markerType.displayName,
        iconGetter: markerType.iconGetter,
        onClose: () => Navigator.of(sheetCtx).maybePop(),
      ),
    );
    
    _activeSheet = sheetFuture;
    await sheetFuture;
    _activeSheet = null;
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