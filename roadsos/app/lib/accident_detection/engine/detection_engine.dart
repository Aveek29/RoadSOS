import 'dart:async';
import '../services/sensor_service.dart';
import '../analyzers/motion_analyzer.dart';
import '../analyzers/orientation_analyzer.dart';
import '../analyzers/inactivity_detector.dart';
import '../events/event_dispatcher.dart';

class DetectionEngine {
  final SensorService _sensorService;
  final MotionAnalyzer _motionAnalyzer;
  final OrientationAnalyzer _orientationAnalyzer;
  final InactivityDetector _inactivityDetector;
  final EventDispatcher _dispatcher;

  // Configuration
  final double confidenceThreshold;
  final Duration eventCorrelationWindow;

  // Stream subscriptions
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _eventSub;

  // State
  bool _isRunning = false;
  bool _isPaused = false;
  bool accidentDetected = false;
  double confidenceScore = 0.0;

  // Timestamped event tracking for correlation window
  DateTime? _impactTime;
  DateTime? _orientationTime;
  DateTime? _inactivityTime;

  // Magnitude tracking from analyzer reports
  double _impactMagnitude = 0.0;
  double _orientationMagnitude = 0.0;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  Stream<EngineEventData> get accidentEvents => _dispatcher.events;

  DetectionEngine({
    required SensorService sensorService,
    required MotionAnalyzer motionAnalyzer,
    required OrientationAnalyzer orientationAnalyzer,
    required InactivityDetector inactivityDetector,
    required EventDispatcher dispatcher,
    this.confidenceThreshold = 0.7,
    this.eventCorrelationWindow = const Duration(seconds: 90),
  })  : _sensorService = sensorService,
        _motionAnalyzer = motionAnalyzer,
        _orientationAnalyzer = orientationAnalyzer,
        _inactivityDetector = inactivityDetector,
        _dispatcher = dispatcher;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;

    _sensorService.startListening();

    _accelSub = _sensorService.accelerometerStream.listen((event) {
      if (_isPaused) return;
      _motionAnalyzer.analyze(event);
      _inactivityDetector.analyze(event);
    });

    _gyroSub = _sensorService.gyroscopeStream.listen((event) {
      if (_isPaused) return;
      _orientationAnalyzer.analyze(event);
    });

    _eventSub = _dispatcher.events.listen(_onEventDetected);

    print('[Engine] Accident Detection Engine Started');
  }

  /// Pauses detection without destroying subscriptions or state.
  /// Use resume() to continue.
  void pause() {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _sensorService.stopListening();
    print('[Engine] Engine Paused');
  }

  /// Resumes detection after a pause.
  void resume() {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;
    _sensorService.startListening();
    print('[Engine] Engine Resumed');
  }

  void _onEventDetected(EngineEventData eventData) {
    if (accidentDetected || _isPaused) return;

    final now = DateTime.now();

    switch (eventData.type) {
      case EngineEvent.impactDetected:
        _impactTime = now;
        _impactMagnitude = eventData.magnitude ?? 0.0;
        // Start tracking inactivity only after a significant impact
        _inactivityDetector.startTracking();
        break;

      case EngineEvent.abnormalOrientationDetected:
        _orientationTime = now;
        _orientationMagnitude = eventData.magnitude ?? 0.0;
        break;

      case EngineEvent.inactivityDetected:
        _inactivityTime = now;
        break;

      case EngineEvent.inactivityWarning:
        // UI hook — doesn't affect scoring
        break;

      case EngineEvent.accidentDetected:
        // Ignore self-emitted events
        break;
    }

    _calculateConfidenceScore();
    _evaluateConditions();
  }

  void _calculateConfidenceScore() {
    final now = DateTime.now();
    confidenceScore = 0.0;

    // Impact: 40% weight — scaled by magnitude relative to threshold
    if (_impactTime != null &&
        now.difference(_impactTime!) <= eventCorrelationWindow) {
      // Scale: at threshold = 0.5x, at 2x threshold = 1.0x
      double magnitudeScale =
          (_impactMagnitude / (_motionAnalyzer.impactThreshold * 2))
              .clamp(0.5, 1.0);
      confidenceScore += 0.4 * magnitudeScale;
    }

    // Orientation: 30% weight — scaled by rotation magnitude
    if (_orientationTime != null &&
        now.difference(_orientationTime!) <= eventCorrelationWindow) {
      double magnitudeScale = (_orientationMagnitude /
              (_orientationAnalyzer.rotationThreshold * 2))
          .clamp(0.5, 1.0);
      confidenceScore += 0.3 * magnitudeScale;
    }

    // Inactivity: 30% weight — binary (either confirmed or not)
    if (_inactivityTime != null &&
        now.difference(_inactivityTime!) <= eventCorrelationWindow) {
      confidenceScore += 0.3;
    }
  }

  void _evaluateConditions() {
    // Flexible threshold: trigger if combined confidence exceeds the threshold.
    // Impact(40%) + Orientation(30%) = 70% → triggers even without inactivity
    // Impact(40%) alone = 40% → doesn't trigger (safe)
    if (confidenceScore >= confidenceThreshold && !accidentDetected) {
      accidentDetected = true;
      print(
          '[Engine] ACCIDENT DETECTED (Confidence: ${(confidenceScore * 100).toInt()}%)');
      _dispatcher.emit(EngineEvent.accidentDetected,
          magnitude: confidenceScore);
    }
  }

  void reset() {
    accidentDetected = false;
    confidenceScore = 0.0;
    _impactTime = null;
    _orientationTime = null;
    _inactivityTime = null;
    _impactMagnitude = 0.0;
    _orientationMagnitude = 0.0;

    _motionAnalyzer.reset();
    _orientationAnalyzer.reset();
    _inactivityDetector.reset();

    print('[Engine] Engine Reset');
  }

  /// Simulates an event for testing and demonstrations
  void simulateEvent(EngineEvent type, {double? magnitude}) {
    if (type == EngineEvent.accidentDetected && magnitude != null) {
      confidenceScore = magnitude;
    }
    _dispatcher.emit(type, magnitude: magnitude);
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _eventSub?.cancel();
    _sensorService.dispose();
    _inactivityDetector.stopTracking();
    _isRunning = false;
    _isPaused = false;
    print('[Engine] Engine Disposed');
  }
}
