import 'dart:async';
import 'speed_monitor.dart';
import 'riding_mode_manager.dart';
import 'detection_controller.dart';

class ContextEngine {
  final SpeedMonitor _speedMonitor;
  final RidingModeManager _ridingModeManager;
  final DetectionController _detectionController;

  StreamSubscription<double>? _speedSub;
  StreamSubscription<RidingState>? _stateSub;

  ContextEngine({
    required SpeedMonitor speedMonitor,
    required RidingModeManager ridingModeManager,
    required DetectionController detectionController,
  })  : _speedMonitor = speedMonitor,
        _ridingModeManager = ridingModeManager,
        _detectionController = detectionController;

  void initialize() {
    // 1. Subscribe to Velocity Updates
    _speedSub = _speedMonitor.speedStream.listen((speedKmh) {
      _ridingModeManager.processSpeed(speedKmh);
    });

    // 2. Subscribe to Mode Changes
    _stateSub = _ridingModeManager.stateStream.listen((state) {
      switch (state) {
        case RidingState.riding:
          _detectionController.startDetection();
          break;
        case RidingState.idle:
          _detectionController.stopDetection();
          break;
        case RidingState.suspicious:
          // Keep detection running — the SUSPICIOUS state is a signal
          // to the detection engine that sensitivity should be heightened.
          // The engine remains active to catch post-deceleration events.
          if (!_detectionController.isRunning) {
            _detectionController.startDetection();
          }
          print('[ContextEngine] Suspicious deceleration — detection stays active');
          break;
      }
    });

    // 3. Mount Sensors and Begin Execution
    _speedMonitor.start();

    print('[ContextEngine] Initialized and monitoring environment');
  }

  void dispose() {
    _speedSub?.cancel();
    _stateSub?.cancel();
    _speedMonitor.dispose();
    _ridingModeManager.dispose();
    _detectionController.stopDetection();
    print('[ContextEngine] Disposed');
  }
}
