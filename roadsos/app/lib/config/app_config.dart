import 'package:flutter/foundation.dart';

/// Single source of truth for the backend address and shared runtime config.
///
/// Every networked service (Socket.IO, prediction HTTP client, helper index)
/// resolves the backend through this class so the whole app points at ONE
/// address that can be changed from a single place.
///
/// Resolution order for the backend URL:
///   1. `--dart-define=ROADSOS_BACKEND_URL=http://<host>:<port>` (explicit)
///   2. A sensible platform default:
///        * Android  -> `10.0.2.2` (emulator alias for the host's localhost)
///        * Anything else (iOS simulator, desktop, web) -> `127.0.0.1`
class AppConfig {
  AppConfig._();

  /// Explicit override supplied at build/run time. Empty when not provided.
  static const String _envOverride =
      String.fromEnvironment('ROADSOS_BACKEND_URL');

  /// Platform-aware default address.
  static String get _platformDefault {
    if (kIsWeb) return 'http://127.0.0.1:5000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator reaches the host machine via 10.0.2.2.
        // On a PHYSICAL device pass ROADSOS_BACKEND_URL=http://<PC-LAN-IP>:5000
        return 'http://10.0.2.2:5000';
      default:
        // iOS simulator, macOS, Windows, Linux all use host loopback.
        return 'http://127.0.0.1:5000';
    }
  }

  /// The resolved backend base URL (no trailing slash).
  static final String backendBaseUrl =
      _envOverride.isNotEmpty ? _envOverride : _platformDefault;

  /// Builds an absolute [Uri] for a backend [path] (with or without leading `/`).
  static Uri uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$backendBaseUrl$normalized');
  }

  /// Emergency contacts notified by SMS on a confirmed crash.
  ///
  /// Mutable by design: settings UI mutates this list in place, and
  /// [EmergencyService] holds a reference to it, so edits apply immediately
  /// without restarting the detection engine.
  static final List<String> emergencyContacts = <String>[
    '+919876543210',
    '+918765432109',
  ];
}
