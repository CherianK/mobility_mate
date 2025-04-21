import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/marker_type.dart';
import '../widgets/search_bar.dart';
import '../widgets/location_bottom_sheet.dart';

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  late MapboxMap _mapboxMap;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
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
            setState(() => _mapReady = true);
          },
        ),
        if (_mapReady) SearchBarWidget(mapboxMap: _mapboxMap),
      ]),
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