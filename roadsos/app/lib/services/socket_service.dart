import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Socket.IO client for the RoadSOS backend command centre.
///
/// Hardened for reliability (an SOS channel must not silently drop data):
///   * Backend address comes from [AppConfig] (single source of truth).
///   * Transports: native builds connect over websocket (the only transport
///     socket_io_client implements on dart:io); web keeps polling as a
///     fallback for restrictive networks.
///   * Automatic reconnection with backoff.
///   * Fire-and-forget events emitted while disconnected are QUEUED (bounded)
///     and flushed on reconnect, so a `create_incident` SOS is not lost.
///   * Exposes a [statusStream] so the UI can reflect connectivity.
///   * Listens to backend-pushed events (incident_created/updated/deleted,
///     helper_accepted, mission_updated, severity_prediction) and exposes
///     them as streams via [serverEvents] / [onEvent] — the app is a full
///     duplex Socket.IO client, not emit-only.
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

  /// Server-push events the backend broadcasts to every connected client.
  /// Each emission is `{'event': <name>, 'data': <payload map>}`.
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// All backend-pushed events (multiplexed). Prefer [onEvent] for a single
  /// event type.
  Stream<Map<String, dynamic>> get serverEvents => _eventsController.stream;

  /// Typed stream for one event name, e.g. `onEvent('incident_created')`.
  Stream<Map<String, dynamic>> onEvent(String event) => _eventsController.stream
      .where((e) => e['event'] == event)
      .map((e) => e['data'] as Map<String, dynamic>);

  /// Events the backend emits that this client subscribes to.
  static const List<String> _subscribedEvents = [
    'incident_created',
    'incident_updated',
    'incident_deleted',
    'helper_accepted',
    'mission_updated',
    'severity_prediction',
    'location_updated',
  ];

  bool get isConnected => socket?.connected ?? false;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  void connect({String? serverUrl}) {
    if (socket != null && socket!.connected) return;

    final url = serverUrl ?? _serverUrl;
    debugPrint('[Socket] Attempting to connect to $url...');

    socket = IO.io(
      url,
      IO.OptionBuilder()
          // socket_io_client on native (dart:io) ONLY implements websocket;
          // requesting `polling` first creates a WebSocket transport with a
          // stale `transport=polling` query, which the server answers with
          // HTTP 200 instead of 101 (connection never establishes).
          // Web keeps long-polling as a fallback for restrictive networks.
          .setTransports(kIsWeb ? ['polling', 'websocket'] : ['websocket'])
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
      debugPrint('[Socket] Connected to RoadSOS backend at $url');
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

    _registerServerListeners(socket!);
  }

  /// Subscribes to every backend-pushed event so the UI can react in real
  /// time (live incident feed, helper-assignment alerts, severity updates).
  /// Called once per socket instance; socket_io_client keeps these handlers
  /// across reconnects of the same instance.
  void _registerServerListeners(IO.Socket s) {
    for (final name in _subscribedEvents) {
      s.on(name, (payload) {
        final data = _normalizePayload(payload);
        debugPrint('[Socket] Received server event: $name');
        if (!_eventsController.isClosed) {
          _eventsController.add({'event': name, 'data': data});
        }
      });
    }
  }

  /// Socket payloads arrive as `Map<dynamic, dynamic>`; normalizes to
  /// `Map<String, dynamic>` so downstream code can use it directly.
  static Map<String, dynamic> _normalizePayload(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }
    return {'value': payload};
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

  /// Emits the SOS `create_incident` and invokes [callback] with the server
  /// ACK: `{success, incidentId, source}`. The returned `incidentId` is the
  /// authoritative id (Firestore doc id, or a `sock_` id when the backend has
  /// no Firestore) and should be used to start live location tracking.
  ///
  /// If we're currently offline the event is queued for delivery on reconnect
  /// and the callback receives `{success: true, queued: true}` so the caller
  /// can proceed without blocking the emergency flow.
  void emitCreateIncidentWithAck(
    Map<String, dynamic> data,
    Function(dynamic ack) callback,
  ) {
    if (socket != null && socket!.connected) {
      socket!.emitWithAck('create_incident', data, ack: (response) {
        callback(response);
      });
      debugPrint('[Socket] Emitted create_incident with ACK');
    } else {
      // Queue it (outbox flushes on reconnect) so the SOS is not lost.
      emit('create_incident', data);
      callback({
        'success': true,
        'queued': true,
        'message': 'Offline: SOS queued, will reach command centre on reconnect.',
      });
    }
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
