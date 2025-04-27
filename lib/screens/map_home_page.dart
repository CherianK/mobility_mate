import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/marker_type.dart';
import '../widgets/search_bar.dart';
import '../widgets/location_bottom_sheet.dart';
import '../config/theme.dart';

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  late MapboxMap _mapboxMap;
  bool _isLoading = true;
  bool _isLocating = false;

  final Map<MarkerType, PointAnnotationManager> _annotationManagers = {};
  final Map<MarkerType, List<PointAnnotationOptions>> _markerOptions = {};
  final Map<MarkerType, List<Map<String, dynamic>>> _markerPayloads = {};
  final Map<MarkerType, List<PointAnnotation>> _activeMarkers = {};
  final Map<String, Map<String, dynamic>> _markerData = {};

  Timer? _zoomTimer;
  bool _mapReady = false;

  static const _baseUrl = 'https://mobility-mate.onrender.com';

  @override
  void dispose() {
    _zoomTimer?.cancel();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      // Get the current camera state
      final cameraState = await _mapboxMap.getCameraState();
      final currentCenter = cameraState.center;
      
      // Fly to the current location with animation
      await _mapboxMap.flyTo(
        CameraOptions(
          center: currentCenter,
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      setState(() => _isLocating = false);
    }
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
              center: Point(coordinates: Position(144.9631, -37.8136)),
              zoom: 13.0,
            ),
            onMapCreated: (map) async {
              _mapboxMap = map;
              await _initAllTypes();
              _startZoomListener();
              setState(() {
                _mapReady = true;
                _isLoading = false;
              });
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
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
                      final currentZoom = await _mapboxMap.getCameraState().then((s) => s.zoom);
                      await _mapboxMap.flyTo(
                        CameraOptions(zoom: currentZoom + 1),
                        MapAnimationOptions(duration: 300),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'zoom_out',
                    onPressed: () async {
                      final currentZoom = await _mapboxMap.getCameraState().then((s) => s.zoom);
                      await _mapboxMap.flyTo(
                        CameraOptions(zoom: currentZoom - 1),
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
    for (var type in MarkerType.values) {
      final mgr = await _mapboxMap.annotations.createPointAnnotationManager();
      _annotationManagers[type] = mgr;
      _activeMarkers[type] = [];

      await _fetchType(type);

      mgr.addOnPointAnnotationClickListener(
        PointAnnotationClickListener(onClicked: (annotation) {
          final data = _markerData[annotation.id];
          if (data != null) {
            _showBottomSheet(annotation.id, type);
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
        debugPrint('❌ ${type.name} API error ${resp.statusCode}');
        return;
      }

      final List<dynamic> list = json.decode(resp.body);
      debugPrint('✅ ${list.length} ${type.name}s fetched');

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
            iconColor: type.color.value,
          )
      ];
    } catch (e) {
      debugPrint('❌ Error fetching ${type.name}: $e');
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
              _markerData[ann.id] = payloads[i];
            }
          }
          _activeMarkers[type] = nonNull;
          debugPrint('🟢 Show ${type.name} at zoom $zoom');
        }
      } else {
        if (_activeMarkers[type]!.isNotEmpty) {
          await mgr.deleteAll();
          _activeMarkers[type] = [];
          debugPrint('🔴 Hide ${type.name} at zoom $zoom');
        }
      }
    }
  }

  void _showBottomSheet(String id, MarkerType type) {
    final data = _markerData[id]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationBottomSheet(
        data: data,
        title: type.displayName,
        iconGetter: type.iconGetter,
        onClose: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

/// Pigeon listener adapter
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