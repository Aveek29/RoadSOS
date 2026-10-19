import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Socket.IO client for the RoadSOS backend command centre.
///
/// Hardened for reliability (an SOS channel must not silently drop data):
///   * Backend address comes from [AppConfig] (single source of truth).
///   * Transports `polling` then upgrade to `websocket` — far more reliable
///     across emulators/LANs/flaky mobile networks than websocket-only.
///   * Automatic reconnection with backoff.
///   * Fire-and-forget events emitted while disconnected are QUEUED (bounded)
///     and flushed on reconnect, so a `create_incident` SOS is not lost.
///   * Exposes a [statusStream] so the UI can reflect connectivity.
class SocketService {
  IO.Socket? socket;

  final String _serverUrl = AppConfig.backendBaseUrl;

  /// Outbound queue for events emitted before a connection exists.
  final List<Map<String, dynamic>> _outbox = <Map<String, dynamic>>[];
  static const int _maxOutbox = 32;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  /// Emits `true` on connect and `false` on disconnect/error.
  Stream<bool> get statusStream => _statusController.stream;

  bool get isConnected => socket?.connected ?? false;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  void connect() {
    if (socket != null && socket!.connected) return;

    debugPrint('[Socket] Attempting to connect to $_serverUrl...');

    socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          // Polling handshake first, then upgrade to websocket.
          .setTransports(['polling', 'websocket'])
          .enableAutoConnect()
          .enableReconnection()
          // Keep retrying: an emergency app should survive long network drops.
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setTimeout(10000)
          .build(),
    );

    socket!.onConnect((_) {
      debugPrint('[Socket] Connected to RoadSOS backend at $_serverUrl');
      _statusController.add(true);
      _flushOutbox();
    });

    socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected from RoadSOS backend.');
      _statusController.add(false);
    });

    socket!.onConnectError((error) {
      debugPrint('[Socket] Connection error: $error');
      _statusController.add(false);
    });

    socket!.onError((error) {
      debugPrint('[Socket] Socket error: $error');
    });
  }

  /// Sends any queued events once a connection is available.
  void _flushOutbox() {
    if (_outbox.isEmpty || socket == null || !socket!.connected) return;
    debugPrint('[Socket] Flushing ${_outbox.length} queued event(s).');
    for (final item in _outbox) {
      socket!.emit(item['event'], item['data']);
    }
    _outbox.clear();
  }

  void emit(String event, dynamic data) {
    if (socket != null && socket!.connected) {
      socket!.emit(event, data);
      debugPrint('[Socket] Emitted event: $event');
    } else {
      // Queue (bounded) so critical events aren't dropped, and kick a connect.
      debugPrint('[Socket] Not connected - queueing "$event" and reconnecting.');
      if (_outbox.length < _maxOutbox) {
        _outbox.add({'event': event, 'data': data});
      } else {
        debugPrint('[Socket][Warning] Outbox full, dropping "$event".');
      }
      connect();
    }
  }

  void emitCreateIncident(Map<String, dynamic> data) {
    emit('create_incident', data);
  }

  void emitUpdateLocation(String incidentId, double lat, double lng) {
    emit('update_location', {
      'incidentId': incidentId,
      'latitude': lat,
      'longitude': lng,
    });
  }

  /// Emits `helper_respond` and invokes [callback] with the server ack.
  /// Acks cannot be reliably queued, so if we're offline the callback is
  /// invoked immediately with a structured failure the UI can show.
  void emitHelperResponse(
    String incidentId,
    String helperUid,
    bool accepted,
    double distanceMeters,
    Function(dynamic) callback,
  ) {
    if (socket != null && socket!.connected) {
      socket!.emitWithAck('helper_respond', {
        'incidentId': incidentId,
        'helperUid': helperUid,
        'accepted': accepted,
        'distanceMeters': distanceMeters,
      }, ack: (response) {
        callback(response);
      });
      debugPrint('[Socket] Emitted helper_respond with ACK');
    } else {
      connect();
      callback({
        'success': false,
        'message': 'Not connected to command centre - try again shortly.',
      });
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    _outbox.clear();
    debugPrint('[Socket] Disconnected permanently.');
  }
}
