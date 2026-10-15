import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches current location using high precision
  Future<Position?> fetchLocation() async {
    try {
      // Verify location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[Error][Location] Location services are disabled.');
        return null;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[Error][Location] Location permissions are denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[Error][Location] Location permissions permanently denied.');
        return null;
      }

      // Fetch high accuracy location with a timeout to prevent blocking forever.
      // Note: `timeLimit` was removed in geolocator >=10; use Future.timeout instead.
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Location fetch timed out'),
      );

      print('[Location] Lat: ${position.latitude}, Lng: ${position.longitude}');
      return position;
    } catch (e) {
      print('[Error][Location] Failed to fetch location: $e');
      return null;
    }
  }
}
