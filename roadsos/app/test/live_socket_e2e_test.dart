// Live duplex Socket.IO test: real Flutter client <-> real Flask/Socket.IO
// backend. Proves the backend -> app direction (server push), which the app
// previously never exercised (it was emit-only).
//
//   flutter test test/live_socket_e2e_test.dart \
//       --dart-define=ROADSOS_LIVE_E2E=true \
//       --dart-define=ROADSOS_BACKEND_URL=http://127.0.0.1:5000
//
// Without ROADSOS_LIVE_E2E=true the tests are reported as SKIPPED.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:roadsos_app/services/socket_service.dart';

const bool _live = bool.fromEnvironment('ROADSOS_LIVE_E2E', defaultValue: false);
const String _baseUrl = String.fromEnvironment(
  'ROADSOS_BACKEND_URL',
  defaultValue: 'http://127.0.0.1:5000',
);

const _skipReason =
    'live test: start the backend and re-run with '
    '--dart-define=ROADSOS_LIVE_E2E=true';

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  final skip = _live ? false : _skipReason;

  test('app receives real-time incident broadcasts over Socket.IO', () async {
    final socket = SocketService();
    final created = <Map<String, dynamic>>[];
    final sub = socket.onEvent('incident_created').listen(created.add);

    socket.connect(serverUrl: _baseUrl);
    await _waitFor(() => socket.isConnected);

    // Trigger a genuine backend broadcast (same route the dashboard uses).
    final res = await http.post(
      Uri.parse('$_baseUrl/demo/simulate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'severityType': 'minor'}),
    );
    expect(res.statusCode, anyOf(200, 201), reason: res.body);

    await _waitFor(() => created.isNotEmpty);
    final incident = created.last;
    expect(incident['id'], isNotNull,
        reason: 'server push must carry the incident id');
    expect(incident['status'], 'ACTIVE');
    expect(incident['severity'], isNotNull);

    await sub.cancel();
    socket.disconnect();
  }, skip: skip);

  test('serverEvents multiplexer reports the event name', () async {
    final socket = SocketService();
    final names = <String>[];
    final sub = socket.serverEvents.listen((e) => names.add(e['event'] as String));

    socket.connect(serverUrl: _baseUrl);
    await _waitFor(() => socket.isConnected);

    await http.post(
      Uri.parse('$_baseUrl/demo/simulate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'severityType': 'major'}),
    );

    await _waitFor(() => names.contains('incident_created'));
    expect(names, contains('incident_created'));

    await sub.cancel();
    socket.disconnect();
  }, skip: skip);

  test('status stream reports the connection state', () async {
    final socket = SocketService();
    final states = <bool>[];
    final sub = socket.statusStream.listen(states.add);

    socket.connect(serverUrl: _baseUrl);
    await _waitFor(() => socket.isConnected);
    expect(states, contains(true));

    await sub.cancel();
    socket.disconnect();
  }, skip: skip);
}
