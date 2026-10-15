import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roadsos_app/accident_detection/engine_builder.dart';
import 'package:roadsos_app/emergency_handling/emergency_service.dart';
import 'package:roadsos_app/main.dart';

void main() {
  testWidgets('RoadSoS app shell renders the primary destinations',
      (WidgetTester tester) async {
    // `RoadSoSApp` reads the globals that `main()` creates, so a widget test
    // must mirror that wiring — minus Firebase and the backend socket, which
    // require platform channels and a running server.
    globalDetectionEngine = EngineBuilder.build(
      confidenceThreshold: 0.7,
      eventCorrelationWindow: const Duration(seconds: 90),
    );
    globalEmergencyService = EmergencyService(
      detectionEngine: globalDetectionEngine,
      emergencyContacts: const ['+919876543210', '+918765432109'],
    );

    // Use a realistic portrait phone surface: the default 800x600 test window
    // is a landscape-ish aspect that no target device uses.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RoadSoSApp());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Volunteer'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
