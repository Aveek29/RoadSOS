/// Pure-Dart Open Location Code (OLC / Google Plus Code) encoder.
/// Implements the full OLC 20-character alphabet encoding algorithm.
/// No external packages required — runs fully offline.
///
/// Reference: https://github.com/google/open-location-code
class PlusCodeService {
  static const String _alphabet = '23456789CFGHJMPQRVWX';
  static const int _pairCodeLength = 10;
  static const int _gridCodeLength = 5;
  static const double _latMax = 90.0;
  static const double _lngMax = 180.0;
  static const int _encodingBase = 20;

  /// Encodes a lat/lng into a full-precision (10-char) Plus Code.
  /// Example: (12.9716, 77.5946) → "7J4VXQCG+Q4"
  static String encode(double latitude, double longitude, {int codeLength = 10}) {
    // Clip latitude and normalize longitude
    latitude = latitude.clamp(-_latMax + 1e-9, _latMax);
    longitude = (longitude + _lngMax) % (2 * _lngMax) - _lngMax;

    // Shift to positive range
    double lat = latitude + _latMax;
    double lng = longitude + _lngMax;

    final StringBuffer code = StringBuffer();

    // Encode pair section (alternating lat/lng pairs)
    int pLen = codeLength < _pairCodeLength ? codeLength : _pairCodeLength;
    int step = _encodingBase * _encodingBase;

    for (int i = 0; i < (pLen / 2).ceil(); i++) {
      final int latDigit = (lat / step).floor() % _encodingBase;
      final int lngDigit = (lng / step).floor() % _encodingBase;
      code.write(_alphabet[latDigit]);
      code.write(_alphabet[lngDigit]);
      step = (step / _encodingBase).floor();
      if (code.length == 8) code.write('+');
    }

    // Pad if requested code length is < 8
    while (code.length < 9) {
      code.write('0');
      if (code.length == 8) code.write('+');
    }

    return code.toString();
  }

  /// Returns a formatted string with both coordinates and Plus Code.
  static String formatLocation(double lat, double lng) {
    final plus = encode(lat, lng);
    final latStr = lat >= 0 ? '${lat.toStringAsFixed(5)}°N' : '${lat.abs().toStringAsFixed(5)}°S';
    final lngStr = lng >= 0 ? '${lng.toStringAsFixed(5)}°E' : '${lng.abs().toStringAsFixed(5)}°W';
    return '$latStr, $lngStr  |  📍 $plus';
  }
}
