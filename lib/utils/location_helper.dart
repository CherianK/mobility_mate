import 'package:geolocator/geolocator.dart';

class LocationHelper {
  // Static lock to prevent concurrent permission requests
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
      // If we're already requesting permission, wait for that request to complete
      if (_isRequestingPermission && _permissionRequestFuture != null) {
        permission = await _permissionRequestFuture!;
      } else {
        // Start a new permission request
        _isRequestingPermission = true;
        _permissionRequestFuture = Geolocator.requestPermission();
        permission = await _permissionRequestFuture!;
        _isRequestingPermission = false;
        _permissionRequestFuture = null;
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
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}