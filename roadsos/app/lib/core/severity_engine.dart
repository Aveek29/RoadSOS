import 'dart:math';

enum SeverityLevel { low, medium, high, critical }

class SeverityResult {
  final SeverityLevel level;
  final double score; // 0.0 - 1.0
  final String label;
  final String emoji;

  const SeverityResult({
    required this.level,
    required this.score,
    required this.label,
    required this.emoji,
  });

  Map<String, dynamic> toMap() => {
        'severity': label,
        'severityScore': score,
      };
}

/// Weighted multi-factor crash severity scoring engine.
///
/// Formula:
///   S = w_impact * sigmoid(g_force, 3.0, 1.5)
///     + w_orient * sigmoid(gyro_rads, 4.0, 1.0)
///     + w_inactive * (inactivity_s / 60.0).clamp(0,1)
///     + w_speed   * sigmoid(speed_kmh, 60.0, 0.1)
///
/// Weights: impact=0.40, orient=0.25, inactivity=0.20, speed=0.15
class SeverityEngine {
  // Weights — must sum to 1.0
  static const double _wImpact = 0.40;
  static const double _wOrient = 0.25;
  static const double _wInactive = 0.20;
  static const double _wSpeed = 0.15;

  /// Logistic sigmoid normaliser — maps physical values to [0, 1].
  static double _sigmoid(double value, double midpoint, double steepness) {
    return 1.0 / (1.0 + exp(-steepness * (value - midpoint)));
  }

  /// Computes severity from sensor readings collected at the moment of impact.
  ///
  /// [peakAccelGs]     — Peak accelerometer reading in g-force units
  /// [peakGyroRads]    — Peak gyroscope reading in rad/s
  /// [inactivitySecs]  — Duration of post-impact stillness in seconds (0 if unknown)
  /// [preImpactSpeedKmh] — GPS speed immediately before impact (0 if unavailable)
  static SeverityResult compute({
    required double peakAccelGs,
    required double peakGyroRads,
    double inactivitySecs = 0.0,
    double preImpactSpeedKmh = 0.0,
  }) {
    final sImpact = _sigmoid(peakAccelGs, 3.0, 1.5);
    final sOrient = _sigmoid(peakGyroRads, 4.0, 1.0);
    final sInactive = (inactivitySecs / 60.0).clamp(0.0, 1.0);
    final sSpeed = _sigmoid(preImpactSpeedKmh, 60.0, 0.10);

    final score = (_wImpact * sImpact) +
        (_wOrient * sOrient) +
        (_wInactive * sInactive) +
        (_wSpeed * sSpeed);

    final clamped = score.clamp(0.0, 1.0);
    return _classify(clamped);
  }

  static SeverityResult _classify(double score) {
    if (score >= 0.78) {
      return SeverityResult(
          level: SeverityLevel.critical,
          score: score,
          label: 'CRITICAL',
          emoji: '🚨');
    } else if (score >= 0.55) {
      return SeverityResult(
          level: SeverityLevel.high,
          score: score,
          label: 'HIGH',
          emoji: '🔴');
    } else if (score >= 0.30) {
      return SeverityResult(
          level: SeverityLevel.medium,
          score: score,
          label: 'MEDIUM',
          emoji: '🟠');
    } else {
      return SeverityResult(
          level: SeverityLevel.low,
          score: score,
          label: 'LOW',
          emoji: '🟡');
    }
  }
}
