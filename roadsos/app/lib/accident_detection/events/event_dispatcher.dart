import 'dart:async';

/// Typed event data payload carrying magnitude/context from analyzers
class EngineEventData {
  final EngineEvent type;
  final double? magnitude;
  final DateTime timestamp;

  EngineEventData({
    required this.type,
    this.magnitude,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'EngineEventData(type: $type, magnitude: ${magnitude?.toStringAsFixed(2)}, time: $timestamp)';
}

enum EngineEvent {
  impactDetected,
  abnormalOrientationDetected,
  inactivityWarning,
  inactivityDetected,
  accidentDetected,
}

class EventDispatcher {
  final _eventController = StreamController<EngineEventData>.broadcast();

  Stream<EngineEventData> get events => _eventController.stream;

  /// Convenience stream filtered to a specific event type
  Stream<EngineEventData> on(EngineEvent type) =>
      _eventController.stream.where((e) => e.type == type);

  void emit(EngineEvent event, {double? magnitude}) {
    if (!_eventController.isClosed) {
      _eventController.add(EngineEventData(
        type: event,
        magnitude: magnitude,
      ));
    }
  }

  void dispose() {
    _eventController.close();
  }
}
