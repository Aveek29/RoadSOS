import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../events/event_dispatcher.dart';

class OrientationAnalyzer {
  final EventDispatcher _dispatcher;

  /// Rotation rate threshold (rad/s) indicating a sudden flip or spin.
  final double rotationThreshold;

  /// Duration the abnormal orientation must persist to confirm it's
  /// a real crash posture, not a casual phone flip.
  final Duration sustainedDuration;

  OrientationAnalyzer(
    this._dispatcher, {
    this.rotationThreshold = 5.0,
    this.sustainedDuration = const Duration(seconds: 2),
  });

  bool _abnormalOrientationDetected = false;
  bool _spikeDetected = false;
  double _peakRotation = 0.0;
  DateTime? _spikeTime;
  Timer? _confirmationTimer;

  bool get isAbnormalOrientation => _abnormalOrientationDetected;
  double get peakRotation => _peakRotation;

  void analyze(GyroscopeEvent event) {
    if (_abnormalOrientationDetected) return;

    double rotationMagnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    if (rotationMagnitude > rotationThreshold) {
      if (rotationMagnitude > _peakRotation) {
        _peakRotation = rotationMagnitude;
      }

      if (!_spikeDetected) {
        // First detection of abnormal rotation — start the confirmation window
        _spikeDetected = true;
        _spikeTime = DateTime.now();

        _confirmationTimer?.cancel();
        _confirmationTimer = Timer(sustainedDuration, () {
          // If we reach here, the abnormal orientation persisted
          _abnormalOrientationDetected = true;
          print(
              '[Orientation] Abnormal orientation confirmed (sustained ${sustainedDuration.inSeconds}s, peak: ${_peakRotation.toStringAsFixed(2)} rad/s)');
          _dispatcher.emit(EngineEvent.abnormalOrientationDetected,
              magnitude: _peakRotation);
        });
      }
      // If spike is already detected, continued high readings reinforce it
      // (the confirmation timer keeps running)
    } else {
      // A normal reading during the confirmation window — the phone stabilized,
      // so it was just a brief flip, not a crash posture.
      if (_spikeDetected && !_abnormalOrientationDetected) {
        final elapsed = DateTime.now().difference(_spikeTime!);
        if (elapsed < sustainedDuration) {
          // Spike didn't persist long enough — cancel
          _spikeDetected = false;
          _spikeTime = null;
          _confirmationTimer?.cancel();
        }
      }
    }
  }

  void reset() {
    _abnormalOrientationDetected = false;
    _spikeDetected = false;
    _peakRotation = 0.0;
    _spikeTime = null;
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
  }
}
