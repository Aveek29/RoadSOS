import { io } from 'socket.io-client';

const SOCKET_URL = process.env.REACT_APP_API_URL || 'http://127.0.0.1:5000';

class SocketService {
  constructor() {
    this.socket = null;
  }

  connect(onConnect, onDisconnect) {
    if (this.socket) return;

    this.socket = io(SOCKET_URL, {
      transports: ['websocket'],
      autoConnect: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 2000,
    });

    this.socket.on('connect', () => {
      console.log('[Socket] Connected to backend Command Center');
      if (onConnect) onConnect();
    });

    this.socket.on('disconnect', () => {
      console.log('[Socket] Disconnected from backend Command Center');
      if (onDisconnect) onDisconnect();
    });
  }

  subscribeToIncidentCreated(callback) {
    if (!this.socket) return;
    this.socket.on('incident_created', (data) => {
      console.log('[Socket] Incident created:', data);
      callback(data);
    });
  }

  subscribeToIncidentUpdated(callback) {
    if (!this.socket) return;
    this.socket.on('incident_updated', (data) => {
      console.log('[Socket] Incident updated:', data);
      callback(data);
    });
  }

  subscribeToIncidentDeleted(callback) {
    if (!this.socket) return;
    this.socket.on('incident_deleted', (data) => {
      console.log('[Socket] Incident deleted:', data);
      callback(data);
    });
  }

  subscribeToHelperAccepted(callback) {
    if (!this.socket) return;
    this.socket.on('helper_accepted', (data) => {
      console.log('[Socket] Helper accepted:', data);
      callback(data);
    });
  }

  subscribeToSeverityPrediction(callback) {
    if (!this.socket) return;
    this.socket.on('severity_prediction', (data) => {
      console.log('[Socket] Severity prediction:', data);
      callback(data);
    });
  }

  subscribeToLocationUpdated(callback) {
    if (!this.socket) return;
    this.socket.on('location_updated', (data) => {
      console.log('[Socket] Location updated:', data);
      callback(data);
    });
  }

  emitDispatchResource(incidentId, type) {
    if (this.socket) {
      this.socket.emit('dispatch_resource', { incidentId, type });
      console.log('[Socket] Emitted dispatch_resource:', { incidentId, type });
    }
  }

  emitUpdateStatus(incidentId, status) {
    if (this.socket) {
      this.socket.emit('update_status', { incidentId, status });
      console.log('[Socket] Emitted update_status:', { incidentId, status });
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }
}

export const socketService = new SocketService();
