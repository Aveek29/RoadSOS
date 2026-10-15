import 'dart:async';
import 'incident_manager.dart';
import 'location_index_service.dart';
import 'notification_service.dart';

/// Tracks the current state of the helper search cascade
class HelperSearchState {
  final int currentRingIndex;
  final double currentRadius;
  final int totalNotified;
  final int respondersFound;
  final bool isComplete;

  HelperSearchState({
    required this.currentRingIndex,
    required this.currentRadius,
    required this.totalNotified,
    required this.respondersFound,
    required this.isComplete,
  });
}

class HelperNetworkService {
  final LocationIndexService _locationIndexService;
  final NotificationService _notificationService;
  final IncidentManager _incidentManager;

  // Track state memory cache
  final Set<String> _notifiedUsersTokens = {};

  // Progression Logic sequence
  final List<double> _radiusSteps;

  /// Wait time between radius rings for response collection
  final Duration ringWaitDuration;

  // State stream for external monitoring
  final _stateController = StreamController<HelperSearchState>.broadcast();
  Stream<HelperSearchState> get searchStateStream => _stateController.stream;

  HelperNetworkService({
    required LocationIndexService locationIndexService,
    required NotificationService notificationService,
    required IncidentManager incidentManager,
    List<double>? radiusSteps,
    this.ringWaitDuration = const Duration(seconds: 10),
  })  : _locationIndexService = locationIndexService,
        _notificationService = notificationService,
        _incidentManager = incidentManager,
        _radiusSteps = radiusSteps ?? [20.0, 50.0, 100.0, 200.0];

  /// Activates the distributed cascade search dynamically scaling radius rings
  Future<void> triggerHelperSearch(
      double incidentLat, double incidentLng) async {
    print('\n[Helper] Initiating Helper Network Flow');

    // 1. Snapshot generation
    String incidentId =
        await _incidentManager.createIncident(incidentLat, incidentLng);
    _notifiedUsersTokens.clear();

    // 2. Radius Expansion Iterations Loop
    for (int i = 0; i < _radiusSteps.length; i++) {
      final radius = _radiusSteps[i];
      print('[Helper] Searching within ${radius.toInt()}m');

      try {
        // Fetch nearby available helpers using backend geohash proximity lookup
        var nearbyUsers = await _locationIndexService.fetchNearestHelpers(
            incidentLat, incidentLng, radius);

        // Prevent duplicating pings onto already informed responders
        var newUsersToNotify = nearbyUsers
            .where(
                (user) => !_notifiedUsersTokens.contains(user['fcmToken']))
            .toList();

        if (newUsersToNotify.isNotEmpty) {
          print(
              '[Helper] Found ${newUsersToNotify.length} new users (Filtered dups)');

          List<String> tokens = newUsersToNotify
              .map((e) => e['fcmToken'] as String)
              .toList();

          await _notificationService.sendNotification(
            fcmTokens: tokens,
            incidentId: incidentId,
            lat: incidentLat,
            lng: incidentLng,
            distanceRequested: radius,
          );

          for (var token in tokens) {
            _notifiedUsersTokens.add(token);
          }
        } else {
          print(
              '[Helper] No eligible users found at ${radius.toInt()}m tier');
        }

        // Emit state for external monitoring
        _emitState(
          ringIndex: i,
          radius: radius,
          isComplete: false,
        );

        print(
            '[Helper] Waiting ${ringWaitDuration.inSeconds} seconds for responses...');
        await Future.delayed(ringWaitDuration);

        // After buffer polling, evaluate response counters
        int currentResponders =
            await _incidentManager.getResponderCount(incidentId);

        if (currentResponders > 0) {
          print(
              '[Helper] Event has responders ($currentResponders). Stopping radius expansion.');
          _emitState(
            ringIndex: i,
            radius: radius,
            respondersFound: currentResponders,
            isComplete: true,
          );
          return;
        } else {
          print('[Helper] Expanding radius...');
        }
      } catch (e) {
        // Per-ring error handling: log and continue to next ring
        print(
            '[Error][Helper] Ring ${radius.toInt()}m failed: $e — skipping to next ring');
        continue;
      }
    }

    _emitState(
      ringIndex: _radiusSteps.length - 1,
      radius: _radiusSteps.last,
      isComplete: true,
    );
    print(
        '[Helper] Radius expansion algorithm maxed out (${_radiusSteps.last.toInt()}m). End search cascade.');
  }

  void _emitState({
    required int ringIndex,
    required double radius,
    int respondersFound = 0,
    required bool isComplete,
  }) {
    if (!_stateController.isClosed) {
      _stateController.add(HelperSearchState(
        currentRingIndex: ringIndex,
        currentRadius: radius,
        totalNotified: _notifiedUsersTokens.length,
        respondersFound: respondersFound,
        isComplete: isComplete,
      ));
    }
  }

  void dispose() {
    _stateController.close();
  }
}
