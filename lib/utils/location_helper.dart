import 'package:geolocator/geolocator.dart';

class LocationHelper {
  // Static variables to handle concurrent permission requests
  static bool _isRequestingPermission = false;
  static Future<LocationPermission>? _permissionRequestFuture;

  // Call this function whenever you need the current location
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, return null
      return null;
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // If a permission request is already in progress, wait for it
      if (_isRequestingPermission && _permissionRequestFuture != null) {
        permission = await _permissionRequestFuture!;
      } else {
        // Start a new permission request
        _isRequestingPermission = true;
        _permissionRequestFuture = Geolocator.requestPermission();
        
        try {
          permission = await _permissionRequestFuture!;
        } finally {
          _isRequestingPermission = false;
          _permissionRequestFuture = null;
        }
      }

      if (permission == LocationPermission.denied) {
        // Permissions are denied, return null
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, return null
      return null;
    }

    // Get the current position
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Add timeout to prevent hanging
      );
    } catch (e) {
      // Handle any errors during position retrieval
      return null;
    }
  }
}