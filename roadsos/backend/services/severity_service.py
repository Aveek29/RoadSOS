import math
import logging

logger = logging.getLogger('RoadSoS.Severity')

# Severity boundaries
CRITICAL_THRESHOLD = 0.78
HIGH_THRESHOLD = 0.55
MEDIUM_THRESHOLD = 0.30

SEVERITY_WEIGHTS = {
    'impact': 0.40,
    'orientation': 0.25,
    'inactivity': 0.20,
    'speed': 0.15,
}


def _sigmoid(value: float, midpoint: float, steepness: float) -> float:
    return 1.0 / (1.0 + math.exp(-steepness * (value - midpoint)))


def compute_severity(
    peak_accel_gs: float,
    peak_gyro_rads: float,
    inactivity_secs: float = 0.0,
    pre_impact_speed_kmh: float = 0.0,
) -> dict:
    """
    Mirror of the Dart SeverityEngine.compute() method.
    Returns a dict with 'severity' (str) and 'severityScore' (float 0-1).
    """
    s_impact = _sigmoid(peak_accel_gs, 3.0, 1.5)
    s_orient = _sigmoid(peak_gyro_rads, 4.0, 1.0)
    s_inactive = min(inactivity_secs / 60.0, 1.0)
    s_speed = _sigmoid(pre_impact_speed_kmh, 60.0, 0.10)

    score = (
        SEVERITY_WEIGHTS['impact'] * s_impact
        + SEVERITY_WEIGHTS['orientation'] * s_orient
        + SEVERITY_WEIGHTS['inactivity'] * s_inactive
        + SEVERITY_WEIGHTS['speed'] * s_speed
    )
    score = max(0.0, min(1.0, score))

    if score >= CRITICAL_THRESHOLD:
        label = 'CRITICAL'
    elif score >= HIGH_THRESHOLD:
        label = 'HIGH'
    elif score >= MEDIUM_THRESHOLD:
        label = 'MEDIUM'
    else:
        label = 'LOW'

    logger.debug("Severity computed: %s (score=%.3f)", label, score)
    return {'severity': label, 'severityScore': round(score, 3)}
