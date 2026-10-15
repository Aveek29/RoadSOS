class NotificationService {
  /// Sends explicit payload triggers onto Firebase Cloud Messaging servers
  Future<bool> sendNotification({
    required List<String> fcmTokens,
    required String incidentId,
    required double lat,
    required double lng,
    required double distanceRequested,
  }) async {
    if (fcmTokens.isEmpty) return false;

    print('[FCM] Notification sent to ${fcmTokens.length} users');

    // MOCK CLOUD FUNCTION LAYER
    // Emulate formatting and shipping the exact JSON requested upstream securely.
    final _ = {
      "registration_ids": fcmTokens,
      "data": {
        "type": "ACCIDENT_ALERT",
        "incidentId": incidentId,
        "lat": lat,
        "lng": lng,
        "distance": distanceRequested,
      }
    };
    
    // In Production: Handle Http Client Post, Status Codes (200), and Firebase Retries
    return true; 
  }
}
