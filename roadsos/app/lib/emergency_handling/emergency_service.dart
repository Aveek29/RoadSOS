import 'dart:async';
import 'countdown_manager.dart';
import 'location_service.dart';
import 'sms_service.dart';
import 'firestore_service.dart';
import '../accident_detection/events/event_dispatcher.dart';
import '../accident_detection/engine/detection_engine.dart';
import '../core/severity_engine.dart';
import '../services/voice_alert_service.dart';
import '../services/plus_code_service.dart';
import '../services/live_tracking_service.dart';

enum EmergencyState { idle, countdown, alerting, completed, cancelled }

class EmergencyService {
  final DetectionEngine detectionEngine;
  final CountdownManager _countdownManager;
  final LocationService _locationService;
  final SMSService _smsService;
  final FirestoreService _firestoreService;

  final List<String> emergencyContacts;

  bool _isEmergencyActive = false;
  StreamSubscription? _accidentSub;
  Timer? _cooldownTimer;

  // State stream for UI reactivity
  final _stateController = StreamController<EmergencyState>.broadcast();
  Stream<EmergencyState> get stateStream => _stateController.stream;

  /// Exposes the countdown tick stream for UI rendering
  Stream<CountdownTick> get countdownTicks => _countdownManager.tickStream;

  EmergencyState _currentState = EmergencyState.idle;
  EmergencyState get currentState => _currentState;

  EmergencyService({
    required this.detectionEngine,
    required this.emergencyContacts,
    CountdownManager? countdownManager,
    LocationService? locationService,
    SMSService? smsService,
    FirestoreService? firestoreService,
  })  : _countdownManager = countdownManager ?? CountdownManager(),
        _locationService = locationService ?? LocationService(),
        _smsService = smsService ?? SMSService(),
        _firestoreService = firestoreService ?? FirestoreService();

  /// Starts listening to the DetectionEngine streams for accident trigger
  void listen() {
    _accidentSub = detectionEngine.accidentEvents.listen((eventData) {
      if (eventData.type == EngineEvent.accidentDetected) {
        _handleAccidentDetected();
      }
    });
    print('[Emergency] Listening for accident events...');
  }

  void _emitState(EmergencyState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> _handleAccidentDetected() async {
    // Cooldown/Concurrency check
    if (_isEmergencyActive) {
      print('[Emergency] Emergency already active, ignoring duplicate trigger.');
      return;
    }

    _isEmergencyActive = true;
    print('[Emergency] Accident detected event received');

    // Phase 1: Countdown + Voice Alert
    _emitState(EmergencyState.countdown);
    await VoiceAlertService().announceAccidentDetected();
    bool completed = await _countdownManager.startCountdown();

    if (!completed) {
      print('[Emergency] Flow cancelled by user');
      _isEmergencyActive = false;
      _emitState(EmergencyState.cancelled);
      // Auto-return to idle after a brief delay
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(const Duration(seconds: 3), () {
        _emitState(EmergencyState.idle);
      });
      return;
    }

    // Phase 2: Alerting
    _emitState(EmergencyState.alerting);

    // Fetch GPS Location
    final position = await _locationService.fetchLocation();

    if (position == null) {
      print(
          '[Error][Emergency] Critical failure: Location unavailable, falling back gracefully.');
    }

    final lat = position?.latitude ?? 0.0;
    final lng = position?.longitude ?? 0.0;
    final confidence = detectionEngine.confidenceScore;

    // Compute severity from detection engine metrics
    final severityResult = SeverityEngine.compute(
      peakAccelGs: confidence * 8.0, // approximate from confidence
      peakGyroRads: confidence * 10.0,
      preImpactSpeedKmh: 0.0,
    );

    // Compute Plus Code
    final plusCode = PlusCodeService.encode(lat, lng);

    // Phase 3: Dispatch SMS and Firestore in parallel with error isolation.
    // Each operation is wrapped individually so one failure doesn't block the other.
    final results = await Future.wait([
      _safeSendSMS(lat, lng, confidence),
      _safeStoreIncident(lat, lng, confidence, severityResult, plusCode),
    ]);

    bool smsOk = results[0];
    bool firestoreOk = results[1];

    // Start live tracking if incident was stored
    if (firestoreOk) {
      await VoiceAlertService().announceHelpDispatched();
    }

    if (smsOk || firestoreOk) {
      print('[Emergency] Alert triggered (SMS: $smsOk, Firestore: $firestoreOk)');
    } else {
      print('[Error][Emergency] Both SMS and Firestore failed');
    }

    // Phase 4: Completed
    _emitState(EmergencyState.completed);
    print('[Emergency] Flow completed');

    // Cooldown: properly tracked and cancellable
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(minutes: 5), () {
      _isEmergencyActive = false;
      _emitState(EmergencyState.idle);
    });
  }

  Future<bool> _safeSendSMS(double lat, double lng, double confidence) async {
    try {
      await _smsService.sendEmergencySMS(
        contacts: emergencyContacts,
        latitude: lat,
        longitude: lng,
        confidenceScore: confidence,
      );
      return true;
    } catch (e) {
      print('[Error][Emergency] SMS dispatch failed: $e');
      return false;
    }
  }

  Future<bool> _safeStoreIncident(
      double lat, double lng, double confidence,
      SeverityResult severityResult, String plusCode) async {
    try {
      final docId = await _firestoreService.storeIncident(
        latitude: lat,
        longitude: lng,
        confidenceScore: confidence,
        severity: severityResult.label,
        severityScore: severityResult.score,
        plusCode: plusCode,
      );
      if (docId != null) {
        LiveTrackingService().startTracking(docId);
      }
      return docId != null;
    } catch (e) {
      print('[Error][Emergency] Firestore store failed: $e');
      return false;
    }
  }

  /// Cancels the ongoing countdown or resets active emergency states programmatically
  void cancelEmergency() {
    if (_currentState == EmergencyState.countdown) {
      _countdownManager.cancel();
    } else if (_currentState == EmergencyState.alerting || _currentState == EmergencyState.completed) {
      _cooldownTimer?.cancel();
      _isEmergencyActive = false;
      _emitState(EmergencyState.idle);
    }
  }

  void dispose() {
    _accidentSub?.cancel();
    _cooldownTimer?.cancel();
    _countdownManager.dispose();
    _stateController.close();
  }
}
