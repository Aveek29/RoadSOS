// Real-time accident detection pipeline test.
//
// Exercises the SAME chain the app runs on a phone:
//   raw accelerometer/gyroscope samples
//     -> MotionAnalyzer / OrientationAnalyzer / InactivityDetector
//     -> EventDispatcher (impact + abnormal orientation)
//     -> DetectionEngine confidence scoring (40% + 30% + 30%)
//     -> EngineEvent.accidentDetected (>= 0.7)
//
// No physical sensors are needed: a fake SensorService feeds the engine with
// synthetic samples, so the logic is verified in CI on any machine.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:roadsos_app/accident_detection/analyzers/inactivity_detector.dart';
import 'package:roadsos_app/accident_detection/analyzers/motion_analyzer.dart';
import 'package:roadsos_app/accident_detection/analyzers/orientation_analyzer.dart';
import 'package:roadsos_app/accident_detection/engine/detection_engine.dart';
import 'package:roadsos_app/accident_detection/events/event_dispatcher.dart';
import 'package:roadsos_app/accident_detection/services/sensor_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Replaces the platform sensor streams with test-controlled ones.
class _FakeSensorService extends SensorService {
  final StreamController<UserAccelerometerEvent> accel =
      StreamController<UserAccelerometerEvent>.broadcast();
  final StreamController<GyroscopeEvent> gyro =
      StreamController<GyroscopeEvent>.broadcast();

  @override
  Stream<UserAccelerometerEvent> get accelerometerStream => accel.stream;

  @override
  Stream<GyroscopeEvent> get gyroscopeStream => gyro.stream;

  @override
  void startListening() {}

  @override
  void stopListening() {}

  @override
  void dispose() {
    accel.close();
    gyro.close();
  }
}

({DetectionEngine engine, _FakeSensorService sensors, EventDispatcher dispatcher})
    _buildEngine() {
  final dispatcher = EventDispatcher();
  final sensors = _FakeSensorService();
  final engine = DetectionEngine(
    sensorService: sensors,
    motionAnalyzer: MotionAnalyzer(dispatcher),
    orientationAnalyzer: OrientationAnalyzer(
      dispatcher,
      // Short confirmation window keeps the test fast (2 s on device).
      sustainedDuration: const Duration(milliseconds: 80),
    ),
    inactivityDetector: InactivityDetector(
      dispatcher,
      inactivityDuration: const Duration(milliseconds: 160),
    ),
    dispatcher: dispatcher,
  );
  return (engine: engine, sensors: sensors, dispatcher: dispatcher);
}

UserAccelerometerEvent _accel(double g) =>
    UserAccelerometerEvent(g, 0, 0, DateTime.now());

GyroscopeEvent _gyro(double radPerSec) =>
    GyroscopeEvent(radPerSec, 0, 0, DateTime.now());

void main() {
  test('impact + sustained rotation reaches the 0.7 threshold and fires', () async {
    final (:engine, :sensors, :dispatcher) = _buildEngine();
    final detected = <EngineEventData>[];
    final sub = engine.accidentEvents
        .where((e) => e.type == EngineEvent.accidentDetected)
        .listen(detected.add);

    engine.start();
    expect(engine.isRunning, isTrue);

    // Two consecutive high-G samples confirm an impact (36 m/s² -> 1.0 scale).
    sensors.accel.add(_accel(36));
    sensors.accel.add(_accel(36));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // A violent rotation sustained past the confirmation window.
    sensors.gyro.add(_gyro(10));
    await Future<void>.delayed(const Duration(milliseconds: 160));

    expect(engine.accidentDetected, isTrue,
        reason: 'impact (0.4) + orientation (0.3) must cross the threshold');
    expect(engine.confidenceScore, greaterThanOrEqualTo(0.7));
    expect(detected, isNotEmpty,
        reason: 'accidentDetected must be delivered to listeners '
            '(main.dart forwards it to EmergencyService)');

    await sub.cancel();
    engine.dispose();
    dispatcher.dispose();
  });

  test('a single low spike does NOT raise a false accident', () async {
    final (:engine, :sensors, :dispatcher) = _buildEngine();
    final detected = <EngineEventData>[];
    final sub = engine.accidentEvents
        .where((e) => e.type == EngineEvent.accidentDetected)
        .listen(detected.add);

    engine.start();

    // One isolated spike is below confirmationSamples (2) -> no impact.
    sensors.accel.add(_accel(19));
    // Gentle rotation never crosses the 5 rad/s threshold.
    sensors.gyro.add(_gyro(1.5));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(engine.accidentDetected, isFalse);
    expect(detected, isEmpty);

    await sub.cancel();
    engine.dispose();
    dispatcher.dispose();
  });

  test('reset() re-arms detection after a confirmed accident', () async {
    final (:engine, :sensors, :dispatcher) = _buildEngine();
    engine.start();

    engine.simulateEvent(EngineEvent.impactDetected, magnitude: 40);
    engine.simulateEvent(EngineEvent.abnormalOrientationDetected, magnitude: 12);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(engine.accidentDetected, isTrue);

    engine.reset();
    expect(engine.accidentDetected, isFalse);
    expect(engine.confidenceScore, 0);

    engine.dispose();
    dispatcher.dispose();
  });

  test('Test SOS button path emits accidentDetected directly', () async {
    final dispatcher = EventDispatcher();
    final engine = DetectionEngine(
      sensorService: _FakeSensorService(),
      motionAnalyzer: MotionAnalyzer(dispatcher),
      orientationAnalyzer: OrientationAnalyzer(dispatcher),
      inactivityDetector: InactivityDetector(dispatcher),
      dispatcher: dispatcher,
    );
    final detected = <EngineEventData>[];
    final sub = engine.accidentEvents.listen(detected.add);

    // home_screen.dart 'Test SOS (Demo)' calls exactly this.
    engine.simulateEvent(EngineEvent.accidentDetected, magnitude: 0.95);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(detected, hasLength(1));
    expect(detected.first.type, EngineEvent.accidentDetected);
    expect(engine.confidenceScore, 0.95);

    await sub.cancel();
    engine.dispose();
    dispatcher.dispose();
  });
}
