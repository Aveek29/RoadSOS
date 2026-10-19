import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// HTTP client for the backend's volunteer/helper geohash index.
///
/// Every call resolves the backend through [AppConfig] (single source of
/// truth) and enforces a timeout so requests fail fast instead of hanging.
class LocationIndexService {
  LocationIndexService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Generous but bounded: geohash prefix queries are fast, but a cold backend
  /// or dead network must not stall the volunteer UI.
  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) =>
      AppConfig.uri(path).replace(queryParameters: query);

  /// Registers a volunteer helper profile on the backend.
  Future<bool> registerHelper(String uid, String name, String phone) async {
    try {
      final res = await _client
          .post(
            _uri('/helper/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid, 'name': name, 'phone': phone}),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[LocationIndex] Register failed: $e');
      return false;
    }
  }

  /// Updates helper location and status on the backend, triggering geohashing.
  Future<bool> updatePresence(
      String uid, double lat, double lng, String status) async {
    try {
      final res = await _client
          .post(
            _uri('/helper/presence'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'latitude': lat,
              'longitude': lng,
              'status': status, // ONLINE, OFFLINE, BUSY
            }),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[LocationIndex] Update presence failed: $e');
      return false;
    }
  }

  /// Queries the nearest online available helpers from the backend geohash index.
  Future<List<Map<String, dynamic>>> fetchNearestHelpers(
      double lat, double lng, double radiusMeters) async {
    try {
      final res = await _client
          .get(_uri('/helper/nearest', {
            'lat': '$lat',
            'lng': '$lng',
            'radius': '$radiusMeters',
          }))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['helpers'] != null) {
          return List<Map<String, dynamic>>.from(data['helpers']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('[LocationIndex] Fetch nearest helpers failed: $e');
      return [];
    }
  }

  void dispose() => _client.close();
}
