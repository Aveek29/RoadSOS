import 'dart:async';
import 'speed_monitor.dart';
import 'riding_mode_manager.dart';
import 'detection_controller.dart';
import 'context_engine.dart';

/// A Mock class representing the DetectionController
/// without requiring the heavy geolocator/sensor plugins.
class MockDetectionController implements DetectionController {
  @override
  bool get isRunning => _mockRunning;
  bool _mockRunning = false;

  @override
  void startDetection() {
    if (_mockRunning) return;
    _mockRunning = true;
    print('[Detection] Engine Started');
  }

  @override
  void stopDetection() {
    if (!_mockRunning) return;
    _mockRunning = false;
    print('[Detection] Engine Stopped');
  }

  @override
  void dispose() {
    _mockRunning = false;
    print('[Detection] Engine Disposed');
  }
}

/// Simulated Monitor to cleanly push explicit values bypassing GPS
class SimulatedSpeedMonitor extends SpeedMonitor {
  final _controller = StreamController<double>.broadcast();

  @override
  Stream<double> get speedStream => _controller.stream;

  @override
  void start() {
    print('[SpeedMonitor] Simulated Speed started');
  }

  @override
  void stop() {
    _controller.close();
  }

  void emulateSpeed(double injectedSpeed) {
    print('[Speed] Current: ${injectedSpeed.toStringAsFixed(1)} km/h');
    _controller.add(injectedSpeed);
  }
}

void main() async {
  print('--- CONTEXT ENGINE SIMULATION START ---\n');
  
  final mockSpeedMonitor = SimulatedSpeedMonitor();
  
  // Low debounce criteria suitable for a rapid test script
  final ridingManager = RidingModeManager(
    rideActivateThresholdKmh: 20.0,
    rideDeactivateThresholdKmh: 5.0,
    suspiciousDecelerationKmhPerSec: 15.0,
    activateDuration: const Duration(seconds: 3),
    deactivateDuration: const Duration(seconds: 5), 
  );
  
  final controller = MockDetectionController();

  final contextEngine = ContextEngine(
    speedMonitor: mockSpeedMonitor,
    ridingModeManager: ridingManager,
    detectionController: controller,
  );

  contextEngine.initialize();

  // 1. Static Idle
  mockSpeedMonitor.emulateSpeed(0.0);
  await Future.delayed(const Duration(seconds: 1));

  // 2. Slow coasting (below threshold)
  mockSpeedMonitor.emulateSpeed(10.0);
  await Future.delayed(const Duration(seconds: 1));

  // 3. Accelerating quickly (hitting logic buffer)
  print('\n> Simulating High Speed Acceleration...');
  for (int i = 0; i < 4; i++) {
    mockSpeedMonitor.emulateSpeed(25.0);
    await Future.delayed(const Duration(seconds: 1));
  }

  // Riding Mode is now ON, Engine Started.
  
  print('\n> Cruising actively...');
  mockSpeedMonitor.emulateSpeed(50.0);
  await Future.delayed(const Duration(seconds: 1));

  // 4. Sudden crash deceleration -> SUSPICIOUS state
  print('\n> Simulating Sudden Crash Deceleration...');
  mockSpeedMonitor.emulateSpeed(2.0); // From 50 to 2 in ~1 second
  await Future.delayed(const Duration(seconds: 2));

  // 5. Speed picks back up (false alarm)
  print('\n> False alarm — rider resumes...');
  mockSpeedMonitor.emulateSpeed(30.0);
  await Future.delayed(const Duration(seconds: 1));

  // 6. Hard Stop (hitting logical drop buffer for deactivation)
  print('\n> Simulating Full Stop...');
  for (int i = 0; i < 6; i++) {
    mockSpeedMonitor.emulateSpeed(0.0);
    await Future.delayed(const Duration(seconds: 1));
  }

  // Riding Mode OFF, Engine Stopped.
  print('\n--- CONTEXT ENGINE SIMULATION END ---');
  contextEngine.dispose();
}
