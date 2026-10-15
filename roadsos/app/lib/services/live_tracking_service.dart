import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'socket_service.dart';

class LiveTrackingService {
  static final LiveTrackingService _instance = LiveTrackingService._internal();
  factory LiveTrackingService() => _instance;
  LiveTrackingService._internal();

  static const Duration _updateInterval = Duration(seconds: 10);

  Timer? _timer;
  String? _activeIncidentId;
  bool _tracking = false;

  bool get isTracking => _tracking;

  /// Starts sending GPS location to backend every 10 seconds.
  void startTracking(String incidentId) {
    if (_tracking) return;

    _activeIncidentId = incidentId;
    _tracking = true;

    debugPrint('[LiveTracking] Started for incident: $incidentId');

    // Send first update immediately
    _sendLocationUpdate();

    _timer = Timer.periodic(_updateInterval, (_) {
      if (!_tracking) return;
      _sendLocationUpdate();
    });
  }

  /// Stops tracking and notifies the backend.
  Future<void> stopTracking() async {
    if (!_tracking || _activeIncidentId == null) return;

    _tracking = false;
    _timer?.cancel();
    _timer = null;

    final id = _activeIncidentId!;
    _activeIncidentId = null;

    try {
      SocketService().emit('stop_tracking', {'incidentId': id});
      debugPrint('[LiveTracking] Stopped tracking socket emitted for: $id');
    } catch (e) {
      debugPrint('[LiveTracking] Socket stop failed (non-fatal): $e');
    }
  }

  Future<void> _sendLocationUpdate() async {
    if (!_tracking || _activeIncidentId == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      SocketService().emitUpdateLocation(
        _activeIncidentId!,
        pos.latitude,
        pos.longitude,
      );

      debugPrint(
        '[LiveTracking] Updated location via Socket: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
      );
    } catch (e) {
      debugPrint('[LiveTracking] Location update failed (non-fatal): $e');
    }
  }
}
