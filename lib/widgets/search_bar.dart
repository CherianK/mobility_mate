import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../screens/search_page.dart';

class SearchBarWidget extends StatelessWidget {
  final MapboxMap? mapboxMap;
  final Function(String)? onSearch;
  final bool navigateToSearchPage;
  final String hintText;

  const SearchBarWidget({
    super.key, 
    this.mapboxMap,
    this.onSearch,
    this.navigateToSearchPage = true,
    this.hintText = "Search for a location...",
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: navigateToSearchPage ? () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchPage()),
        );

        if (result != null && result is Map<String, dynamic>) {
          final lat = result['lat'] as double;
          final lon = result['lon'] as double;
          debugPrint('Moving to location: lat=$lat, lon=$lon');

          if (mapboxMap != null) {
            try {
              // First update camera position
              await mapboxMap!.setCamera(
                CameraOptions(
                  center: Point(coordinates: Position(lon, lat)),
                  zoom: 15.0,
                ),
              );
              
              // Then add a temporary marker at the selected location
              final annotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
              await annotationManager.create(
                PointAnnotationOptions(
                  geometry: Point(coordinates: Position(lon, lat)),
                  iconImage: 'marker', 
                  iconSize: 5.0, 
                  iconColor: Colors.red.toARGB32(),
                ),
              );

              // Remove the marker after a few seconds
              await Future.delayed(const Duration(seconds: 12));
              await annotationManager.deleteAll();
            } catch (e) {
              debugPrint('Error handling location selection: $e');
            }
          }
        }
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: navigateToSearchPage
                ? Text(
                    hintText,
                    style: const TextStyle(color: Colors.black54),
                  )
                : TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}