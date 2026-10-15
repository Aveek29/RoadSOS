import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final _accelerometerStreamController =
      StreamController<UserAccelerometerEvent>.broadcast();
  final _gyroscopeStreamController =
      StreamController<GyroscopeEvent>.broadcast();

  Stream<UserAccelerometerEvent> get accelerometerStream =>
      _accelerometerStreamController.stream;
  Stream<GyroscopeEvent> get gyroscopeStream =>
      _gyroscopeStreamController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  void startListening() {
    if (_isListening) return;
    _isListening = true;

    _accelSub = userAccelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval)
        .listen(
      (event) {
        if (!_accelerometerStreamController.isClosed) {
          _accelerometerStreamController.add(event);
        }
      },
      onError: (error) {
        print('[Sensor][Error] Accelerometer stream error: $error');
      },
    );

    _gyroSub =
        gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
            .listen(
      (event) {
        if (!_gyroscopeStreamController.isClosed) {
          _gyroscopeStreamController.add(event);
        }
      },
      onError: (error) {
        print('[Sensor][Error] Gyroscope stream error: $error');
      },
    );

    print('[Sensor] Started listening to sensors');
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    print('[Sensor] Stopped listening to sensors');
  }

  void dispose() {
    stopListening();
    _accelerometerStreamController.close();
    _gyroscopeStreamController.close();
  }
}
