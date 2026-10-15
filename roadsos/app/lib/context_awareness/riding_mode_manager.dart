import 'dart:async';

enum RidingState { idle, riding, suspicious }

class RidingModeManager {
  final double rideActivateThresholdKmh;
  final double rideDeactivateThresholdKmh;

  /// Speed drop (km/h per second) that triggers the SUSPICIOUS state.
  /// A sudden deceleration from high speed may indicate a crash.
  final double suspiciousDecelerationKmhPerSec;

  // Debounce logic durations to avoid rapid state toggling
  final Duration activateDuration;
  final Duration deactivateDuration;

  RidingState currentState = RidingState.idle;

  DateTime? _conditionStartTime;
  bool _isSatisfyingCondition = false;

  double _lastSpeed = 0.0;
  DateTime? _lastSpeedTime;

  /// Exposes the last known speed for the detection engine
  double get lastSpeed => _lastSpeed;

  final _stateStreamController = StreamController<RidingState>.broadcast();
  Stream<RidingState> get stateStream => _stateStreamController.stream;

  RidingModeManager({
    this.rideActivateThresholdKmh = 20.0,
    this.rideDeactivateThresholdKmh = 5.0,
    this.suspiciousDecelerationKmhPerSec = 15.0,
    this.activateDuration = const Duration(seconds: 5),
    this.deactivateDuration = const Duration(seconds: 30),
  });

  void processSpeed(double currentSpeedKmh) {
    final now = DateTime.now();

    // Check for suspicious sudden deceleration while riding
    if (currentState == RidingState.riding && _lastSpeedTime != null) {
      final dtSeconds = now.difference(_lastSpeedTime!).inMilliseconds / 1000.0;
      if (dtSeconds > 0 && dtSeconds < 5) {
        // Only compute if readings are close enough in time
        final deceleration = (_lastSpeed - currentSpeedKmh) / dtSeconds;
        if (deceleration >= suspiciousDecelerationKmhPerSec &&
            _lastSpeed > rideActivateThresholdKmh) {
          // Sudden high-speed deceleration — possible crash
          _transitionTo(RidingState.suspicious);
        }
      }
    }

    _lastSpeed = currentSpeedKmh;
    _lastSpeedTime = now;

    if (currentState == RidingState.idle) {
      _checkActivation(currentSpeedKmh);
    } else if (currentState == RidingState.riding) {
      _checkDeactivation(currentSpeedKmh);
    } else if (currentState == RidingState.suspicious) {
      // In SUSPICIOUS state: if speed picks back up, return to RIDING.
      // If speed stays low for deactivateDuration, go to IDLE.
      if (currentSpeedKmh > rideActivateThresholdKmh) {
        // False alarm — the rider just braked hard
        _transitionTo(RidingState.riding);
      } else {
        _checkDeactivation(currentSpeedKmh);
      }
    }
  }

  void _checkActivation(double speed) {
    if (speed > rideActivateThresholdKmh) {
      if (!_isSatisfyingCondition) {
        _isSatisfyingCondition = true;
        _conditionStartTime = DateTime.now();
      } else {
        final durationPassed = DateTime.now().difference(_conditionStartTime!);
        if (durationPassed >= activateDuration) {
          _transitionTo(RidingState.riding);
        }
      }
    } else {
      _isSatisfyingCondition = false;
      _conditionStartTime = null;
    }
  }

  void _checkDeactivation(double speed) {
    if (speed < rideDeactivateThresholdKmh) {
      if (!_isSatisfyingCondition) {
        _isSatisfyingCondition = true;
        _conditionStartTime = DateTime.now();
      } else {
        final durationPassed = DateTime.now().difference(_conditionStartTime!);
        if (durationPassed >= deactivateDuration) {
          _transitionTo(RidingState.idle);
        }
      }
    } else {
      _isSatisfyingCondition = false;
      _conditionStartTime = null;
    }
  }

  void _transitionTo(RidingState newState) {
    if (currentState == newState) return;

    currentState = newState;
    _isSatisfyingCondition = false;
    _conditionStartTime = null;

    switch (newState) {
      case RidingState.riding:
        print('[Context] Riding Mode ON');
        break;
      case RidingState.idle:
        print('[Context] Riding Mode OFF');
        break;
      case RidingState.suspicious:
        print('[Context] SUSPICIOUS — sudden deceleration detected');
        break;
    }

    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(newState);
    }
  }

  void dispose() {
    _stateStreamController.close();
  }
}
