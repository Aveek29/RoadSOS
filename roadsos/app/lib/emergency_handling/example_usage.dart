import '../accident_detection/engine_builder.dart';
import 'emergency_service.dart';

void main() {
  // 1. Initialize the modular Detection Engine built previously
  final engine = EngineBuilder.build(
    confidenceThreshold: 0.7,
    eventCorrelationWindow: const Duration(seconds: 90),
  );

  // 2. Initialize the Emergency Orchestrator Service injecting dependencies implicitly
  final emergencyService = EmergencyService(
    detectionEngine: engine,
    emergencyContacts: ['+919876543210', '+918765432109'],
  );

  // 3. Mount services and start listening
  print('Starting RoadSoS Subsystems...');

  // Monitor emergency state changes
  emergencyService.stateStream.listen((state) {
    print('[UI] Emergency state changed to: $state');
  });

  emergencyService.listen();
  engine.start();

  // Example Scenario:
  // - System waits
  // - Engine internally registers collision -> events queue
  // - Event loops into EmergencyService
  // - Timer initiates
  //
  // To simulate user hitting a 'Cancel' widget logically:
  // Future.delayed(const Duration(seconds: 4), () {
  //    emergencyService.cancelEmergency();
  // });
}
