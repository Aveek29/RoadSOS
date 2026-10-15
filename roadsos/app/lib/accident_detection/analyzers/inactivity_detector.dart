import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../events/event_dispatcher.dart';

class InactivityDetector {
  final EventDispatcher _dispatcher;

  /// Duration of inactivity required to trigger the event
  final Duration inactivityDuration;

  /// Acceleration threshold to be considered "moving"
  final double activityThreshold;

  /// Number of recent samples to keep for sliding-window evaluation.
  /// Movement is confirmed only if the majority of recent samples
  /// exceed the threshold — prevents sensor noise from resetting the timer.
  final int slidingWindowSize;

  Timer? _inactivityTimer;
  bool _inactivityDetected = false;
  bool _warningEmitted = false;
  bool _isActive = false;

  /// Circular buffer of recent acceleration magnitudes
  final Queue<double> _recentSamples = Queue<double>();

  bool get isInactivityDetected => _inactivityDetected;

  InactivityDetector(
    this._dispatcher, {
    this.inactivityDuration = const Duration(seconds: 60),
    this.activityThreshold = 1.0,
    this.slidingWindowSize = 5,
  });

  void startTracking() {
    if (_isActive) return;
    _isActive = true;
    _warningEmitted = false;
    _resetTimer();
  }

  void stopTracking() {
    _isActive = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void analyze(UserAccelerometerEvent event) {
    if (!_isActive || _inactivityDetected) return;

    double acc =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Maintain sliding window
    _recentSamples.addLast(acc);
    if (_recentSamples.length > slidingWindowSize) {
      _recentSamples.removeFirst();
    }

    // Consider it genuine movement only if the majority of recent
    // samples exceed the threshold (filters sensor noise)
    int activeCount =
        _recentSamples.where((s) => s > activityThreshold).length;
    bool isGenuineMovement = activeCount > (_recentSamples.length / 2);

    if (isGenuineMovement) {
      _resetTimer();
      _warningEmitted = false; // Reset warning on genuine movement
    }
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();

    // Calculate the warning point (50% of the total duration)
    final warningDuration = Duration(
        milliseconds: (inactivityDuration.inMilliseconds * 0.5).toInt());

    _inactivityTimer = Timer(warningDuration, () {
      if (!_warningEmitted && !_inactivityDetected) {
        _warningEmitted = true;
        print(
            '[Inactivity] Warning: No movement for ${warningDuration.inSeconds}s');
        _dispatcher.emit(EngineEvent.inactivityWarning);

        // Start the second half timer for full inactivity
        _inactivityTimer = Timer(
            inactivityDuration - warningDuration, () {
          if (!_inactivityDetected) {
            _inactivityDetected = true;
            print(
                '[Inactivity] Confirmed: No movement for ${inactivityDuration.inSeconds}s');
            _dispatcher.emit(EngineEvent.inactivityDetected);
          }
        });
      }
    });
  }

  void reset() {
    _inactivityDetected = false;
    _warningEmitted = false;
    _recentSamples.clear();
    stopTracking();
  }
}
