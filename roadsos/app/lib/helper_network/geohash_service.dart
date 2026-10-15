/// Pure-Dart Geohash encoder.
/// Implements standard geohashing encoding of coordinate points to base32 representation.
/// No external library dependencies — works fully offline.
class GeohashService {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes latitude and longitude into a geohash representation.
  static String encode(double latitude, double longitude, {int precision = 9}) {
    // Clip lat/lng
    double lat = latitude.clamp(-90.0, 90.0);
    double lon = ((longitude + 180.0) % 360.0) - 180.0;

    List<double> latInterval = [-90.0, 90.0];
    List<double> lonInterval = [-180.0, 180.0];
    StringBuffer geohash = StringBuffer();
    int bits = 0;
    int ch = 0;
    bool even = true;

    while (geohash.length < precision) {
      if (even) {
        double mid = (lonInterval[0] + lonInterval[1]) / 2.0;
        if (lon > mid) {
          ch |= (1 << (4 - bits));
          lonInterval = [mid, lonInterval[1]];
        } else {
          lonInterval = [lonInterval[0], mid];
        }
      } else {
        double mid = (latInterval[0] + latInterval[1]) / 2.0;
        if (lat > mid) {
          ch |= (1 << (4 - bits));
          latInterval = [mid, latInterval[1]];
        } else {
          latInterval = [latInterval[0], mid];
        }
      }
      even = !even;
      if (bits < 4) {
        bits++;
      } else {
        geohash.write(_base32[ch]);
        bits = 0;
        ch = 0;
      }
    }
    return geohash.toString();
  }
}
