import 'dart:math';

class RadiusSearchEngine {
  /// Calculates Haversine distance in meters
  static double calculateDistanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth radius (meters)
    double phi1 = lat1 * pi / 180;
    double phi2 = lat2 * pi / 180;
    double deltaPhi = (lat2 - lat1) * pi / 180;
    double deltaLambda = (lon2 - lon1) * pi / 180;

    double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) *
        sin(deltaLambda / 2) * sin(deltaLambda / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; 
  }

  /// Evaluates batch coordinates and returns sorted users within the explicit threshold
  static List<Map<String, dynamic>> findUsersWithinRadius(
      List<Map<String, dynamic>> allUsers,
      double incidentLat,
      double incidentLng,
      double radiusInMeters) {
    
    List<Map<String, dynamic>> nearbyUsers = [];

    for (var user in allUsers) {
      double userLat = user['lat'];
      double userLng = user['lng'];
      
      double distance = calculateDistanceInMeters(
          incidentLat, incidentLng, userLat, userLng);

      if (distance <= radiusInMeters) {
        // Tag user with live distance for priority mapping downstream
        var taggedUser = Map<String, dynamic>.from(user);
        taggedUser['distance'] = distance;
        nearbyUsers.add(taggedUser);
      }
    }

    // Sort by proximity efficiently
    nearbyUsers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return nearbyUsers;
  }
}
