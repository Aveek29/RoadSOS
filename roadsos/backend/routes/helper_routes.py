import logging
from flask import Blueprint, jsonify, request
from services.helper_service import HelperService
from extensions import socketio

logger = logging.getLogger('RoadSoS.Routes')

helper_bp = Blueprint('helper_bp', __name__)
helper_service = HelperService()


@helper_bp.route('/helper/register', methods=['POST'])
def helper_register():
    """
    Registers a new volunteer or updates their metadata.
    Body: { "uid": "...", "name": "...", "phone": "...", "fcmToken": "..." }
    """
    logger.info("POST /helper/register")
    try:
        data = request.json or {}
        uid = str(data.get('uid', '')).strip()
        name = str(data.get('name', '')).strip()
        phone = str(data.get('phone', '')).strip()
        fcm_token = str(data.get('fcmToken', '')).strip() or None

        if not uid or not name or not phone:
            return jsonify({'success': False, 'error': 'uid, name, and phone are required'}), 400

        result = helper_service.register_helper(uid, name, phone, fcm_token)
        return jsonify(result), 200
    except Exception as e:
        logger.exception("POST /helper/register failed")
        return jsonify({'success': False, 'error': str(e)}), 500


@helper_bp.route('/helper/presence', methods=['POST'])
def helper_presence():
    """
    Updates the helper's GPS coordinates and online/offline status.
    Body: { "uid": "...", "latitude": 12.97, "longitude": 77.59, "status": "ONLINE"|"OFFLINE", "fcmToken": "..." }
    """
    logger.info("POST /helper/presence")
    try:
        data = request.json or {}
        uid = str(data.get('uid', '')).strip()
        lat = data.get('latitude')
        lng = data.get('longitude')
        status = str(data.get('status', 'ONLINE')).strip()
        fcm_token = str(data.get('fcmToken', '')).strip() or None

        if not uid or lat is None or lng is None:
            return jsonify({'success': False, 'error': 'uid, latitude, and longitude are required'}), 400

        result = helper_service.update_presence(uid, float(lat), float(lng), status, fcm_token)
        return jsonify(result), 200
    except Exception as e:
        logger.exception("POST /helper/presence failed")
        return jsonify({'success': False, 'error': str(e)}), 500


@helper_bp.route('/helper/nearest', methods=['GET'])
def helper_nearest():
    """
    Queries nearest available helpers relative to coordinates.
    Query params: ?lat=12.97&lng=77.59&radius=5000
    """
    logger.info("GET /helper/nearest")
    try:
        lat_str = request.args.get('lat')
        lng_str = request.args.get('lng')
        radius_str = request.args.get('radius', '5000')

        if lat_str is None or lng_str is None:
            return jsonify({'success': False, 'error': 'lat and lng parameters are required'}), 400

        lat = float(lat_str)
        lng = float(lng_str)
        radius = float(radius_str)

        helpers = helper_service.get_nearest_helpers(lat, lng, radius)
        # Convert objects to JSON safe format (reputationScore, distanceMeters, name, phone, status, fcmToken)
        response_data = []
        for h in helpers:
            response_data.append({
                'uid': h.get('uid'),
                'name': h.get('name'),
                'phone': h.get('phone'),
                'latitude': h.get('latitude'),
                'longitude': h.get('longitude'),
                'status': h.get('status'),
                'fcmToken': h.get('fcmToken', ''),
                'reputationScore': h.get('reputationScore', 5.0),
                'distanceMeters': h.get('distanceMeters', 0.0),
            })
        return jsonify({'success': True, 'helpers': response_data}), 200
    except Exception as e:
        logger.exception("GET /helper/nearest failed")
        return jsonify({'success': False, 'error': str(e)}), 500


@helper_bp.route('/helper/respond', methods=['POST'])
def helper_respond():
    """
    Called when a helper taps Accept or Decline on their phone.
    Body: { "incidentId": "...", "helperUid": "...", "accepted": true|false, "distanceMeters": ... }
    """
    logger.info("POST /helper/respond")
    try:
        data = request.json
        if not data:
            return jsonify({'success': False, 'error': 'Empty request body'}), 400

        incident_id = str(data.get('incidentId', '')).strip()
        helper_uid = str(data.get('helperUid', '')).strip()
        accepted = bool(data.get('accepted', False))
        distance = float(data.get('distanceMeters', 0.0))

        if not incident_id or not helper_uid:
            return jsonify({'success': False, 'error': 'incidentId and helperUid required'}), 400

        if accepted:
            result = helper_service.accept_incident(incident_id, helper_uid, distance)
            if result['success']:
                # Broadcast real-time helper update to React dashboard via Sockets
                socketio.emit('helper_accepted', {
                    'incidentId': incident_id,
                    'helperUid': helper_uid,
                    'helperName': result.get('helperName', 'Volunteer'),
                    'slotsFilled': result['slotsFilled'],
                    'distanceMeters': distance,
                    'missionId': result.get('missionId'),
                })
            return jsonify(result), 200
        else:
            result = helper_service.decline_incident(incident_id, helper_uid)
            return jsonify(result), 200

    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 400
    except ConnectionError as e:
        return jsonify({'success': False, 'error': str(e)}), 503
    except Exception as e:
        logger.exception("POST /helper/respond failed")
        return jsonify({'success': False, 'error': str(e)}), 500


@helper_bp.route('/helper/mission/update', methods=['POST'])
def helper_mission_update():
    """
    Updates progress state for an active mission.
    Body: { "missionId": "...", "status": "EN_ROUTE"|"ON_SCENE"|"COMPLETED"|"ABANDONED" }
    """
    logger.info("POST /helper/mission/update")
    try:
        data = request.json or {}
        mission_id = str(data.get('missionId', '')).strip()
        status = str(data.get('status', '')).strip()

        if not mission_id or not status:
            return jsonify({'success': False, 'error': 'missionId and status are required'}), 400

        result = helper_service.update_mission_status(mission_id, status)
        
        # Broadcast mission status to frontend so dispatchers track volunteer progress
        socketio.emit('mission_updated', {
            'missionId': mission_id,
            'status': result.get('status'),
            'reputationScore': result.get('reputationScore'),
        })
        return jsonify(result), 200
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 400
    except Exception as e:
        logger.exception("POST /helper/mission/update failed")
        return jsonify({'success': False, 'error': str(e)}), 500

