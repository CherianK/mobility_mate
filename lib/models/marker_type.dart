import 'package:flutter/material.dart';
import '../utils/icon_utils.dart';

enum MarkerType {
  toilet(
    endpoint: 'toilet-location-points',
    iconName: 'toilet',
    color: Colors.blue,
    size: 1.5,
    minZoomLevel: 13.0,
    displayName: 'Toilet Accessibility',
    iconGetter: getToiletIcon,
  ),
  train(
    endpoint: 'train-location-points',
    iconName: 'rail',
    color: Colors.red,
    size: 1.5,
    minZoomLevel: 0.0,
    displayName: 'Train Information',
    iconGetter: getTrainIcon,
  ),
  tram(
    endpoint: 'tram-location-points',
    iconName: 'rail-light',
    color: Colors.green,
    size: 1.5,
    minZoomLevel: 0.0,
    displayName: 'Tram Information',
    iconGetter: getTramIcon,
  ),
  hospital(
    endpoint: 'medical-location-points',
    iconName: 'hospital',
    color: Colors.purple,
    size: 1.5,
    minZoomLevel: 0.0,
    displayName: 'Medical Information',
    iconGetter: getHospitalIcon,
  );

  final String endpoint;
  final String iconName;
  final Color color;
  final double size;
  final double minZoomLevel;
  final String displayName;
  final IconData Function(String, dynamic) iconGetter;

  const MarkerType({
    required this.endpoint,
    required this.iconName,
    required this.color,
    required this.size,
    required this.minZoomLevel,
    required this.displayName,
    required this.iconGetter,
  });

  bool isVisibleAtZoom(double zoom) => zoom >= minZoomLevel;
}