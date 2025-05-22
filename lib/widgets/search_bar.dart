import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../screens/search_page.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/marker_type.dart';
import '../widgets/location_bottom_sheet.dart';
import '../utils/tag_formatter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchBarWidget extends StatelessWidget {
  final MapboxMap mapboxMap;
  static const _baseUrl = 'https://mobility-mate.onrender.com';

  const SearchBarWidget({super.key, required this.mapboxMap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchPage()),
        );

        if (result != null && result is Map<String, dynamic>) {
          final lat = result['lat'] as double;
          final lon = result['lon'] as double;
          final type = result['type'] as String?;
          final centerOnly = result['centerOnly'] as bool? ?? false;

          try {
            // First update camera position
            await mapboxMap.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(lon, lat)),
                zoom: 15.0,
              ),
            );
            
            // Only show bottom sheet for trains, trams, or healthcare if centerOnly is false
            if (!centerOnly && (type == 'trains' || type == 'trams' || type == 'healthcare')) {
              await _showLocationBottomSheet(context, result);
            } else {
              // For suburbs or other types (or if centerOnly is true)
              if (type == 'suburb') {
                // Show success message for suburbs
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Centered to your Selected Suburb',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                // For Mapbox or other types, still show a temporary marker
                final annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                
                // Choose color based on type
                Color markerColor = Colors.purple; // Default for Mapbox
                
                await annotationManager.create(
                  PointAnnotationOptions(
                    geometry: Point(coordinates: Position(lon, lat)),
                    iconImage: 'marker', 
                    iconSize: 5.0, 
                    iconColor: markerColor.toARGB32(),
                  ),
                );

                // Remove the marker after a few seconds
                await Future.delayed(const Duration(seconds: 12));
                await annotationManager.deleteAll();
              }
            }
          } catch (e) {
            // Error handling
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: isDark ? Colors.white : Colors.blue.shade700,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              "Search for a location...",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showLocationBottomSheet(BuildContext context, Map<String, dynamic> location) async {
    final String locationType = location['type'] as String;
    final String name = location['name'] as String;
    final double lat = location['lat'] as double;
    final double lon = location['lon'] as double;
    
    // Determine the MarkerType based on the location type
    MarkerType markerType;
    String endpoint;
    switch (locationType) {
      case 'trains':
        markerType = MarkerType.train;
        endpoint = 'train-location-points';
        break;
      case 'trams':
        markerType = MarkerType.tram;
        endpoint = 'tram-location-points';
        break;
      case 'healthcare':
        markerType = MarkerType.hospital;
        endpoint = 'medical-location-points';
        break;
      default:
        return; // Don't show bottom sheet for other types
    }
    
    // Format the title the same way as in map_home_page.dart
    String markerTypeString;
    switch (markerType) {
      case MarkerType.train:
        markerTypeString = 'trains';
        break;
      case MarkerType.tram:
        markerTypeString = 'trams';
        break;
      case MarkerType.hospital:
        markerTypeString = 'healthcare';
        break;
      default:
        markerTypeString = markerType.name;
    }
    
    final title = formatMarkerDisplayName(
      name: name, 
      markerType: markerTypeString,
    ) ?? markerType.displayName;
    
    // Show a loading indicator
    final loadingDialog = _showLoadingDialog(context);
    
    try {
      // Fetch the complete data from the server for this location type
      Map<String, dynamic>? fullLocationData = await _fetchLocationData(endpoint, name, lat, lon);
      
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      if (fullLocationData == null) {
        // Create a basic data structure if we couldn't fetch full info
        fullLocationData = {
          'Location_Lat': lat,
          'Location_Lon': lon,
          'Location': {
            'type': 'Point',
            'coordinates': [lon, lat]
          },
          'Tags': {
            'name': name,
            'Name': name
          },
          'Metadata': {
            'name': name,
            'Name': name
          },
          'id': '${locationType}_${name.replaceAll(" ", "_").toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
          'type': locationType,
          'accessibility_type_name': locationType,
          'Images': [], // Empty images array
        };
      }
      
      // Explicitly set the marker_type as the MarkerType enum (not just as a string)
      // This is crucial for LocationBottomSheet to work correctly
      fullLocationData['marker_type'] = markerType;
      
      // At this point, fullLocationData is guaranteed to be non-null
      final Map<String, dynamic> locationData = fullLocationData;
      
      // Show the bottom sheet just like in map_home_page.dart
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => LocationBottomSheet(
          data: locationData,
          title: title,
          iconGetter: markerType.iconGetter,
          onClose: () {
            // Check if the context is still valid before popping
            if (Navigator.of(sheetCtx).canPop()) {
              Navigator.of(sheetCtx).maybePop();
            }
          },
        ),
      );
    } catch (e) {
      // Dismiss loading dialog if it's still shown
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading location details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show a loading dialog while fetching location data
  Future<void> _showLoadingDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading location details...'),
            ],
          ),
        );
      },
    );
  }
  
  // Fetch full location data from the server
  Future<Map<String, dynamic>?> _fetchLocationData(String endpoint, String name, double lat, double lon) async {
    try {
      // First try to fetch a list of all locations of this type
      final response = await http.get(Uri.parse('$_baseUrl/$endpoint'));
      
      if (response.statusCode == 200) {
        final List<dynamic> locations = json.decode(response.body);
        
        // Get accessibilityType based on endpoint
        String accessibilityType = endpoint == 'train-location-points' 
            ? 'trains'
            : endpoint == 'tram-location-points' 
                ? 'trams' 
                : 'healthcare';
        
        // Find closest location by coordinates only
        Map<String, dynamic>? bestMatch;
        double closestDistance = double.infinity;
        
        for (final location in locations) {
          // Skip if we can't get coordinates
          if (!location.containsKey('Location_Lat') || !location.containsKey('Location_Lon')) {
            continue;
          }
          
          final locationLat = (location['Location_Lat'] as num).toDouble();
          final locationLon = (location['Location_Lon'] as num).toDouble();
          
          // Calculate distance (simple Euclidean distance is sufficient for comparison)
          final double distance = 
              ((lat - locationLat) * (lat - locationLat)) + 
              ((lon - locationLon) * (lon - locationLon));
          
          // If this is closer than our current best match, update it
          if (distance < closestDistance) {
            closestDistance = distance;
            bestMatch = location;
          }
        }
        
        // Use a more lenient threshold (0.001 is about 100 meters)
        // It's more important to show some data than to be super precise
        if (bestMatch != null && closestDistance < 0.0001) {
          final locationName = bestMatch['Tags']?['name'] ?? bestMatch['Tags']?['Name'] ?? 
                             bestMatch['Metadata']?['name'] ?? bestMatch['Metadata']?['Name'];
          
          // Determine the MarkerType based on the endpoint
          final MarkerType marker_type = endpoint == 'train-location-points' 
              ? MarkerType.train
              : endpoint == 'tram-location-points'
                  ? MarkerType.tram
                  : MarkerType.hospital;
          
          // Create a clean copy of the location data and add the MarkerType directly
          final Map<String, dynamic> resultMap = {
            ...Map<String, dynamic>.from(bestMatch),
            'marker_type': marker_type, // Store the enum value directly
          };
          return resultMap;
        } else {
          // If we have a match but it's far, we'll still use it with a warning
          if (bestMatch != null) {
            final MarkerType marker_type = endpoint == 'train-location-points' 
                ? MarkerType.train
                : endpoint == 'tram-location-points'
                    ? MarkerType.tram
                    : MarkerType.hospital;
            
            final Map<String, dynamic> resultMap = {
              ...Map<String, dynamic>.from(bestMatch),
              'marker_type': marker_type,
            };
            return resultMap;
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}