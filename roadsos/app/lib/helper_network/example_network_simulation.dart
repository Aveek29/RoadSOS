import 'dart:async';
import 'incident_manager.dart';
import 'location_index_service.dart';
import 'notification_service.dart';
import 'response_manager.dart';
import 'helper_network_service.dart';

// --- STUB MOCKS TO ALLOW CLI RUNNING ---
class MockIncidentManager extends IncidentManager {
  int _mockResponders = 0;
  
  @override
  Future<String> createIncident(double lat, double lng) async => 'INCIDENT-999';

  @override
  Future<int> getResponderCount(String incidentId) async => _mockResponders;

  @override
  Future<bool> addResponder(String incidentId, String helperUid, int maxResponders) async {
    if (_mockResponders >= maxResponders) return false;
    _mockResponders++;
    return true;
  }
}

class MockLocationIndexService extends LocationIndexService {
  @override
  Future<List<Map<String, dynamic>>> fetchAllHelpers() async {
    // Inject Mock Helpers across different distances relative to 0.0, 0.0
    return [
      {'uid': 'UID-A', 'fcmToken': 'fcm-A', 'lat': 0.0001, 'lng': 0.0000}, // ~11m away
      {'uid': 'UID-B', 'fcmToken': 'fcm-B', 'lat': 0.0006, 'lng': 0.0000}, // ~66m away
      {'uid': 'UID-C', 'fcmToken': 'fcm-C', 'lat': 0.0007, 'lng': 0.0000}, // ~77m away
      {'uid': 'UID-D', 'fcmToken': 'fcm-D', 'lat': 0.0016, 'lng': 0.0000}, // ~177m away
    ];
  }
}
// ----------------------------------------

void main() async {
  print('--- HELPER NETWORK DISTRIBUTED RUN ---');

  final mockIncidentManager = MockIncidentManager();
  final indexService = MockLocationIndexService();
  final notifService = NotificationService();

  final responseManager = ResponseManager(
    incidentManager: mockIncidentManager,
    maxResponders: 2,
  );

  final helperNetwork = HelperNetworkService(
    locationIndexService: indexService,
    notificationService: notifService,
    incidentManager: mockIncidentManager,
    ringWaitDuration: const Duration(seconds: 5), // Shorter for simulation
  );

  // Monitor search state
  helperNetwork.searchStateStream.listen((state) {
    print('[Monitor] Ring ${state.currentRingIndex}: ${state.currentRadius}m, '
        'notified: ${state.totalNotified}, responders: ${state.respondersFound}');
  });

  // Background hook to simulate late interactions over FCM
  Future.delayed(const Duration(seconds: 8), () async {
    print('\n> [Simulation] Incoming API response from Phone: UID-B -> ACCEPTS');
    await responseManager.handleHelperResponse(
      'INCIDENT-999', 'UID-B', true,
      distanceMeters: 66.0,
    );
  });
  
  // A late Reject
  Future.delayed(const Duration(seconds: 9), () async {
    print('> [Simulation] Incoming API response from Phone: UID-C -> REJECTS');
    await responseManager.handleHelperResponse(
      'INCIDENT-999', 'UID-C', false,
      distanceMeters: 77.0,
    );
  });

  // Start logic zero (Origin coordinates)
  await helperNetwork.triggerHelperSearch(0.0000, 0.0000);

  // Print response log
  print('\n--- RESPONSE LOG ---');
  for (final r in responseManager.responseLog) {
    print('  ${r.helperUid}: accepted=${r.accepted}, '
        'distance=${r.distanceMeters?.toStringAsFixed(0)}m, '
        'at=${r.respondedAt}');
  }

  print('--- END RUN ---');
}
