import 'dart:async';
import 'incident_manager.dart';

/// Record of a helper's response to an incident notification
class HelperResponse {
  final String helperUid;
  final bool accepted;
  final DateTime respondedAt;
  final double? distanceMeters;

  HelperResponse({
    required this.helperUid,
    required this.accepted,
    DateTime? respondedAt,
    this.distanceMeters,
  }) : respondedAt = respondedAt ?? DateTime.now();
}

class ResponseManager {
  final IncidentManager incidentManager;
  final int maxResponders;

  /// Tracks all responses (accepted + rejected) for analytics and audit
  final List<HelperResponse> _responseLog = [];
  List<HelperResponse> get responseLog => List.unmodifiable(_responseLog);

  /// Number of accepted responders
  int get acceptedCount =>
      _responseLog.where((r) => r.accepted).length;

  ResponseManager({required this.incidentManager, this.maxResponders = 3});

  /// Fired when an incoming API ping states a user hit 'Accept' or 'Reject'.
  /// Optionally accepts the helper's distance from the incident for ETA estimation.
  Future<bool> handleHelperResponse(
    String incidentId,
    String helperUid,
    bool accepted, {
    double? distanceMeters,
  }) async {
    // Log every response for audit trail
    _responseLog.add(HelperResponse(
      helperUid: helperUid,
      accepted: accepted,
      distanceMeters: distanceMeters,
    ));

    if (!accepted) {
      print('[Response] User rejected: $helperUid');
      return false;
    }

    print('[Response] User accepted: $helperUid');

    // Attempt Database Lock Assignment
    bool assigned = await incidentManager.addResponder(
        incidentId, helperUid, maxResponders);

    if (assigned) {
      final etaStr = distanceMeters != null
          ? ' (ETA ~${_estimateETA(distanceMeters)})'
          : '';
      print('[Helper] Assigned responder: $helperUid$etaStr');
      return true;
    } else {
      print(
          '[Helper] Assignment failed for $helperUid (Max limit of $maxResponders reached)');
      return false;
    }
  }

  /// Simple ETA estimation based on distance (assumes ~5 km/h walking speed)
  String _estimateETA(double distanceMeters) {
    const double walkingSpeedMps = 5000 / 3600; // ~1.39 m/s
    double seconds = distanceMeters / walkingSpeedMps;
    if (seconds < 60) return '${seconds.toInt()}s';
    return '${(seconds / 60).ceil()} min';
  }

  void clearLog() {
    _responseLog.clear();
  }
}
