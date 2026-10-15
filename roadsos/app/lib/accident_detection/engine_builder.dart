import 'events/event_dispatcher.dart';
import 'services/sensor_service.dart';
import 'analyzers/motion_analyzer.dart';
import 'analyzers/orientation_analyzer.dart';
import 'analyzers/inactivity_detector.dart';
import 'engine/detection_engine.dart';

/// Builder utility to initialize the Accident Detection Engine
/// with default or custom thresholds.
class EngineBuilder {
  static DetectionEngine build({
    // Motion analyzer
    double impactThreshold = 18.0,
    int confirmationSamples = 2,

    // Orientation analyzer
    double rotationThreshold = 5.0,
    Duration sustainedOrientationDuration = const Duration(seconds: 2),

    // Inactivity detector
    Duration inactivityDuration = const Duration(seconds: 60),
    double activityThreshold = 1.0,

    // Engine-level
    double confidenceThreshold = 0.7,
    Duration eventCorrelationWindow = const Duration(seconds: 90),
  }) {
    final dispatcher = EventDispatcher();
    final sensorService = SensorService();

    final motionAnalyzer = MotionAnalyzer(
      dispatcher,
      impactThreshold: impactThreshold,
      confirmationSamples: confirmationSamples,
    );

    final orientationAnalyzer = OrientationAnalyzer(
      dispatcher,
      rotationThreshold: rotationThreshold,
      sustainedDuration: sustainedOrientationDuration,
    );

    final inactivityDetector = InactivityDetector(
      dispatcher,
      inactivityDuration: inactivityDuration,
      activityThreshold: activityThreshold,
    );

    return DetectionEngine(
      sensorService: sensorService,
      motionAnalyzer: motionAnalyzer,
      orientationAnalyzer: orientationAnalyzer,
      inactivityDetector: inactivityDetector,
      dispatcher: dispatcher,
      confidenceThreshold: confidenceThreshold,
      eventCorrelationWindow: eventCorrelationWindow,
    );
  }
}
