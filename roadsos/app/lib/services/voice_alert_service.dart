import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class VoiceAlertService {
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  factory VoiceAlertService() => _instance;
  VoiceAlertService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.42); // Slightly slower for clarity in panic
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('[VoiceAlert] TTS init failed: $e');
    }
  }

  /// Speaks an emergency alert when accident is detected.
  Future<void> announceAccidentDetected() async {
    await _speak(
      'Emergency detected. '
      'An accident alert is being sent. '
      'Tap Cancel if you are okay.',
    );
  }

  /// Confirms help is on the way.
  Future<void> announceHelpDispatched() async {
    await _speak('Help has been notified. Stay calm. Emergency services are on the way.');
  }

  /// Alert when countdown expires and SOS is triggered.
  Future<void> announceSOSSent() async {
    await _speak('SOS alert sent. Your location has been shared with emergency contacts.');
  }

  Future<void> _speak(String text) async {
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      // Fallback: silent — TTS is non-critical, must not crash the emergency flow
      debugPrint('[VoiceAlert] TTS speak failed (non-fatal): $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
