import 'dart:async';

/// Represents the current tick state of the countdown
class CountdownTick {
  final int remaining;
  final int total;
  double get progress => (total - remaining) / total;

  CountdownTick({required this.remaining, required this.total});
}

class CountdownManager {
  final int durationSeconds;
  Timer? _timer;
  bool _isCancelled = false;
  bool _isRunning = false;
  Completer<bool>? _completer;

  final _tickController = StreamController<CountdownTick>.broadcast();

  /// Stream emitting each countdown tick for UI rendering (progress bar, etc.)
  Stream<CountdownTick> get tickStream => _tickController.stream;

  bool get isRunning => _isRunning;

  CountdownManager({this.durationSeconds = 10});

  /// Starts the countdown and returns a future that completes with `true`
  /// if the countdown finished naturally, or `false` if it was cancelled.
  /// If already running, cancels the existing countdown first.
  Future<bool> startCountdown() {
    // Guard against double-start
    if (_isRunning) {
      cancel();
    }

    _isCancelled = false;
    _isRunning = true;
    _completer = Completer<bool>();
    int remaining = durationSeconds;

    print('[Countdown] Started ($durationSeconds seconds)');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCancelled) {
        timer.cancel();
        _isRunning = false;
        print('[Countdown] Cancelled');
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(false);
        }
        return;
      }

      // Emit tick for UI
      if (!_tickController.isClosed) {
        _tickController
            .add(CountdownTick(remaining: remaining, total: durationSeconds));
      }

      print('[Countdown] $remaining...');
      remaining--;

      if (remaining < 0) {
        timer.cancel();
        _isRunning = false;
        print('[Countdown] Completed');
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(true);
        }
      }
    });

    return _completer!.future;
  }

  void cancel() {
    _isCancelled = true;
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(false);
    }
  }

  void dispose() {
    cancel();
    _tickController.close();
  }
}
