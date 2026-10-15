import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  IO.Socket? socket;
  
  // Note: 10.0.2.2 is the special loopback interface for Android Emulator 
  // pointing to the host machine's localhost (127.0.0.1).
  final String _serverUrl = 'http://10.0.2.2:5000'; 

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  void connect() {
    if (socket != null && socket!.connected) return;

    debugPrint('[Socket] Attempting to connect to $_serverUrl...');
    
    socket = IO.io(_serverUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect()
      .setReconnectionAttempts(5)
      .setReconnectionDelay(2000)
      .build());

    socket!.onConnect((_) {
      debugPrint('[Socket] Connected to RoadSOS Backend Command Center successfully.');
    });

    socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected from RoadSOS Backend Command Center.');
    });

    socket!.onConnectError((error) {
      debugPrint('[Socket] Connection error: $error');
    });
  }

  void emit(String event, dynamic data) {
    if (socket != null && socket!.connected) {
      socket!.emit(event, data);
      debugPrint('[Socket] Emitted event: $event');
    } else {
      debugPrint('[Socket][Warning] Cannot emit $event - socket not connected');
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
      callback({'success': false, 'message': 'Socket connection lost', 'success_status': false});
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
    debugPrint('[Socket] Disconnected permanently.');
  }
}
