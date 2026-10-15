import 'dart:async';
import 'package:geolocator/geolocator.dart';

class SpeedMonitor {
  StreamSubscription<Position>? _positionStream;
  final _speedStreamController = StreamController<double>.broadcast();

  Stream<double> get speedStream => _speedStreamController.stream;

  // Simple moving average buffer for smoothing GPS fluctuations
  final List<double> _speedBuffer = [];
  final int smoothWindow;

  double _lastKnownSpeed = 0.0;

  /// Last computed smoothed speed (km/h).
  double get lastKnownSpeed => _lastKnownSpeed;

  SpeedMonitor({this.smoothWindow = 3});

  void start() {
    print('[SpeedMonitor] Started monitoring speed');
    // Optimize GPS usage for battery efficiency while driving
    var locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update only if moved 5+ meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      // GPS may report -1.0 when speed is unavailable — filter it out
      if (position.speed < 0) return;

      // Geolocator base speed is in m/s, convert to km/h
      double speedKmh = position.speed * 3.6;
      double smoothedSpeed = _applySmoothing(speedKmh);
      _lastKnownSpeed = smoothedSpeed;

      print('[Speed] Current: ${smoothedSpeed.toStringAsFixed(1)} km/h');
      if (!_speedStreamController.isClosed) {
        _speedStreamController.add(smoothedSpeed);
      }
    });
  }

  double _applySmoothing(double newSpeed) {
    _speedBuffer.add(newSpeed);
    if (_speedBuffer.length > smoothWindow) {
      _speedBuffer.removeAt(0);
    }
    double sum = _speedBuffer.reduce((a, b) => a + b);
    return sum / _speedBuffer.length;
  }

  void stop() {
    _positionStream?.cancel();
    _positionStream = null;
    _speedBuffer.clear();
    print('[SpeedMonitor] Stopped monitoring speed');
  }

  void dispose() {
    stop();
    _speedStreamController.close();
  }
}
