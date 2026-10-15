import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../events/event_dispatcher.dart';

class MotionAnalyzer {
  final EventDispatcher _dispatcher;

  /// Acceleration threshold (m/s²) indicating a significant impact.
  final double impactThreshold;

  /// Number of consecutive high-G samples required to confirm an impact.
  /// Prevents single-spike false positives (pothole, phone drop).
  final int confirmationSamples;

  /// Cooldown duration after a confirmed impact before another can fire.
  final Duration cooldownDuration;

  MotionAnalyzer(
    this._dispatcher, {
    this.impactThreshold = 18.0,
    this.confirmationSamples = 2,
    this.cooldownDuration = const Duration(seconds: 5),
  });

  bool _impactDetected = false;
  int _consecutiveHighG = 0;
  double _peakMagnitude = 0.0;
  DateTime? _lastImpactTime;

  bool get isImpactDetected => _impactDetected;
  double get peakMagnitude => _peakMagnitude;

  void analyze(UserAccelerometerEvent event) {
    // Respect cooldown window after a confirmed impact
    if (_impactDetected) {
      if (_lastImpactTime != null &&
          DateTime.now().difference(_lastImpactTime!) < cooldownDuration) {
        return;
      }
      // Cooldown elapsed — allow re-detection (engine may have reset)
    }

    double acc =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (acc > impactThreshold) {
      _consecutiveHighG++;
      if (acc > _peakMagnitude) _peakMagnitude = acc;

      // Require N consecutive high-G readings for confirmation
      if (_consecutiveHighG >= confirmationSamples) {
        _impactDetected = true;
        _lastImpactTime = DateTime.now();
        print(
            '[Motion] Impact confirmed (${_consecutiveHighG}x samples, peak: ${_peakMagnitude.toStringAsFixed(2)} m/s²)');
        _dispatcher.emit(EngineEvent.impactDetected,
            magnitude: _peakMagnitude);
      }
    } else {
      // Reset consecutive counter if a normal reading breaks the streak
      _consecutiveHighG = 0;
    }
  }

  void reset() {
    _impactDetected = false;
    _consecutiveHighG = 0;
    _peakMagnitude = 0.0;
    _lastImpactTime = null;
  }
}
