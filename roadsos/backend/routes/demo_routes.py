import logging
import random
from datetime import datetime, timezone
from flask import Blueprint, jsonify, request
from services.firestore_service import FirestoreService
from services.severity_service import compute_severity
from extensions import socketio

logger = logging.getLogger('RoadSoS.Demo')

demo_bp = Blueprint('demo_bp', __name__)
_fs = FirestoreService()

# Realistic Chennai coordinates for demo incidents to align with police dispatcher dashboard
DEMO_LOCATIONS = [
    {'city': 'NH48, Koyambedu, Chennai, Tamil Nadu 600107', 'lat': 13.0681, 'lng': 80.2148},
    {'city': 'GST Road, Tambaram, Chennai, Tamil Nadu 600045', 'lat': 12.9249, 'lng': 80.1000},
    {'city': 'OMR, Sholinganallur, Chennai, Tamil Nadu 600119', 'lat': 12.9011, 'lng': 80.2269},
    {'city': 'Anna Salai, Teynampet, Chennai, Tamil Nadu 600018', 'lat': 13.0381, 'lng': 80.2443},
    {'city': 'Poonamallee High Road, Chennai, Tamil Nadu 600084', 'lat': 13.0473, 'lng': 80.0945},
]

SEVERITY_PARAMS = {
    'minor': {
        'peak_accel_gs': random.uniform(1.2, 2.2),
        'peak_gyro_rads': random.uniform(0.5, 2.0),
        'inactivity_secs': random.uniform(0, 10),
        'pre_impact_speed_kmh': random.uniform(10, 30),
    },
    'major': {
        'peak_accel_gs': random.uniform(3.0, 4.5),
        'peak_gyro_rads': random.uniform(3.0, 5.5),
        'inactivity_secs': random.uniform(20, 45),
        'pre_impact_speed_kmh': random.uniform(50, 80),
    },
    'critical': {
        'peak_accel_gs': random.uniform(5.0, 8.0),
        'peak_gyro_rads': random.uniform(6.0, 10.0),
        'inactivity_secs': random.uniform(50, 90),
        'pre_impact_speed_kmh': random.uniform(90, 130),
    },
}


def _build_severity_params(severity_key: str) -> dict:
    """Regenerate random params per call so each demo incident is unique."""
    ranges = {
        'minor': {
            'peak_accel_gs': (1.2, 2.2),
            'peak_gyro_rads': (0.5, 2.0),
            'inactivity_secs': (0, 10),
            'pre_impact_speed_kmh': (10, 30),
        },
        'major': {
            'peak_accel_gs': (3.0, 4.5),
            'peak_gyro_rads': (3.0, 5.5),
            'inactivity_secs': (20, 45),
            'pre_impact_speed_kmh': (50, 80),
        },
        'critical': {
            'peak_accel_gs': (5.0, 8.0),
            'peak_gyro_rads': (6.0, 10.0),
            'inactivity_secs': (50, 90),
            'pre_impact_speed_kmh': (90, 130),
        },
    }
    r = ranges[severity_key]
    return {k: random.uniform(*v) for k, v in r.items()}


@demo_bp.route('/demo/simulate', methods=['POST'])
def simulate_incident():
    """
    Creates a realistic demo incident in Firestore.

    Request body:
        { "severityType": "minor" | "major" | "critical" }

    Returns:
        { "success": true, "incidentId": "<id>", "severity": "HIGH", ... }
    """
    logger.info("POST /demo/simulate")
    try:
        data = request.json or {}
        severity_key = str(data.get('severityType', 'major')).lower()

        if severity_key not in ('minor', 'major', 'critical'):
            return jsonify({'success': False, 'error': 'severityType must be minor, major, or critical'}), 400

        # Pick a random Chennai demo location and jitter slightly (approx 500m)
        loc = random.choice(DEMO_LOCATIONS)
        lat = loc['lat'] + random.uniform(-0.005, 0.005)
        lng = loc['lng'] + random.uniform(-0.005, 0.005)

        # Compute severity
        params = _build_severity_params(severity_key)
        severity_result = compute_severity(**params)

        now_iso = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')

        incident_data = {
            'latitude': round(lat, 6),
            'longitude': round(lng, 6),
            'status': 'ACTIVE',
            'source': 'demo',
            'city': loc['city'],
            'severity': severity_result['severity'],
            'severityScore': severity_result['severityScore'],
            'confidence': round(params['peak_accel_gs'] / 8.0, 2),
            'peakAccelGs': round(params['peak_accel_gs'], 2),
            'preImpactSpeedKmh': round(params['pre_impact_speed_kmh'], 1),
            'trackingActive': True,
            'victimLat': round(lat, 6),
            'victimLng': round(lng, 6),
            'acceptedHelpers': [],
            'helperSlots': 0,
            'helperRequestOpen': True,
            'dispatchedResources': [],
            'isDemo': True,
            'timestamp': now_iso,
        }

        if _fs.is_connected:
            doc_id = _fs.add_document('incidents', incident_data)
            incident_data['id'] = doc_id
        else:
            # Offline demo: emit mock socket event with fake ID
            import uuid
            incident_data['id'] = f"demo_{uuid.uuid4().hex[:8]}"
            socketio.emit('incident_created', incident_data)

        logger.info(
            "Demo incident created: %s | severity=%s | loc=%s",
            incident_data['id'],
            severity_result['severity'],
            loc['city'],
        )

        return jsonify({
            'success': True,
            'incidentId': incident_data['id'],
            'severity': severity_result['severity'],
            'severityScore': severity_result['severityScore'],
            'city': loc['city'],
            'latitude': incident_data['latitude'],
            'longitude': incident_data['longitude'],
        }), 201

    except Exception as e:
        logger.exception("POST /demo/simulate failed")
        return jsonify({'success': False, 'error': str(e)}), 500


@demo_bp.route('/demo/clear', methods=['POST'])
def clear_demo_incidents():
    """Removes all demo incidents from Firestore (cleanup utility)."""
    logger.info("POST /demo/clear")
    try:
        if not _fs.is_connected:
            return jsonify({'success': False, 'error': 'Firestore not connected'}), 503

        db = _fs.db
        docs = list(db.collection('incidents').where('isDemo', '==', True).stream())
        deleted = 0
        for doc in docs:
            doc.reference.delete()
            deleted += 1
            socketio.emit('incident_deleted', {'id': doc.id})

        logger.info("Cleared %d demo incidents", deleted)
        return jsonify({'success': True, 'deleted': deleted}), 200
    except Exception as e:
        logger.exception("POST /demo/clear failed")
        return jsonify({'success': False, 'error': str(e)}), 500
