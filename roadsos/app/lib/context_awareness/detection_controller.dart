import '../accident_detection/engine/detection_engine.dart';

class DetectionController {
  final DetectionEngine _detectionEngine;
  bool _isRunning = false;

  DetectionController(this._detectionEngine);

  bool get isRunning => _isRunning;

  void startDetection() {
    if (_isRunning) return;

    _isRunning = true;

    // If the engine was paused, resume it; otherwise start fresh
    if (_detectionEngine.isPaused) {
      _detectionEngine.resume();
      print('[Detection] Engine Resumed');
    } else if (!_detectionEngine.isRunning) {
      _detectionEngine.start();
      print('[Detection] Engine Started');
    }
  }

  void stopDetection() {
    if (!_isRunning) return;

    _isRunning = false;
    // Pause instead of dispose so the engine can be restarted without
    // recreating the entire object graph (subscriptions, analyzers, etc.)
    _detectionEngine.pause();
    print('[Detection] Engine Paused (preserving state)');
  }

  /// Full shutdown — destroys the engine permanently.
  /// Only call when the app is shutting down.
  void dispose() {
    _isRunning = false;
    _detectionEngine.dispose();
    print('[Detection] Engine Disposed permanently');
  }
}
