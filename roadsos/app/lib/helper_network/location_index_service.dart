import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationIndexService {
  static const String _baseUrl = 'http://10.0.2.2:5000';

  /// Registers a volunteer helper profile on the backend
  Future<bool> registerHelper(String uid, String name, String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/helper/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'name': name,
          'phone': phone,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[LocationIndex] Register failed: $e');
      return false;
    }
  }

  /// Updates helper location and status on the backend, triggering geohashing
  Future<bool> updatePresence(String uid, double lat, double lng, String status) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/helper/presence'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'latitude': lat,
          'longitude': lng,
          'status': status, // ONLINE, OFFLINE, BUSY
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[LocationIndex] Update presence failed: $e');
      return false;
    }
  }

  /// Queries the nearest online available helpers from the backend geohash index
  Future<List<Map<String, dynamic>>> fetchNearestHelpers(double lat, double lng, double radiusMeters) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/helper/nearest?lat=$lat&lng=$lng&radius=$radiusMeters'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['helpers'] != null) {
          return List<Map<String, dynamic>>.from(data['helpers']);
        }
      }
      return [];
    } catch (e) {
      print('[LocationIndex] Fetch nearest helpers failed: $e');
      return [];
    }
  }
}

