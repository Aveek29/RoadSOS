import logging
from flask import Blueprint, jsonify, request
from services.incident_service import IncidentService
from services.firestore_service import FirestoreService

logger = logging.getLogger('RoadSoS.Routes')

incident_bp = Blueprint('incident_bp', __name__)
incident_service = IncidentService()
_fs = FirestoreService()


@incident_bp.route('/incidents', methods=['GET'])
def get_incidents():
    logger.info("GET /incidents")
    try:
        status_filter = request.args.get('status')

        # Input sanitization: validate limit is a positive integer in range
        try:
            limit = int(request.args.get('limit', 50))
            if limit < 1:
                limit = 1
            elif limit > 200:
                limit = 200
        except (ValueError, TypeError):
            return jsonify({"success": False, "error": "Invalid 'limit' parameter — must be a positive integer"}), 400

        # Validate status filter if provided
        if status_filter and status_filter not in ('ACTIVE', 'RESPONDING', 'RESOLVED', 'CRITICAL'):
            return jsonify({
                "success": False,
                "error": f"Invalid status filter '{status_filter}'. "
                         f"Must be one of: ACTIVE, RESPONDING, RESOLVED, CRITICAL"
            }), 400

        incidents = incident_service.get_incidents(status_filter, limit)
        return jsonify({"success": True, "data": incidents, "count": len(incidents)}), 200
    except ConnectionError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        logger.exception("GET /incidents failed")
        return jsonify({"success": False, "error": str(e)}), 500


@incident_bp.route('/incident/<incident_id>', methods=['GET'])
def get_incident(incident_id):
    logger.info("GET /incident/%s", incident_id)
    try:
        # Basic ID sanitization
        if not incident_id or len(incident_id) > 128:
            return jsonify({"success": False, "error": "Invalid incident ID format"}), 400

        incident = incident_service.get_incident(incident_id)
        if incident:
            return jsonify({"success": True, "data": incident}), 200
        return jsonify({"success": False, "error": "Incident not found"}), 404
    except ConnectionError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        logger.exception("GET /incident/%s failed", incident_id)
        return jsonify({"success": False, "error": str(e)}), 500


@incident_bp.route('/update-status', methods=['POST'])
def update_status():
    logger.info("POST /update-status")
    try:
        data = request.json
        if not data or 'incidentId' not in data or 'status' not in data:
            return jsonify({"success": False, "error": "Missing required fields: incidentId, status"}), 400

        incident_id = str(data['incidentId']).strip()
        new_status = str(data['status']).strip().upper()

        if not incident_id or len(incident_id) > 128:
            return jsonify({"success": False, "error": "Invalid incidentId format"}), 400

        incident_service.update_status(incident_id, new_status)
        return jsonify({"success": True, "message": f"Status updated to {new_status}"}), 200
    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except ConnectionError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        logger.exception("POST /update-status failed")
        return jsonify({"success": False, "error": str(e)}), 500


@incident_bp.route('/incident/<incident_id>/stop-tracking', methods=['POST'])
def stop_tracking(incident_id):
    """Stops victim live location tracking for a resolved incident."""
    logger.info("POST /incident/%s/stop-tracking", incident_id)
    try:
        if not incident_id or len(incident_id) > 128:
            return jsonify({"success": False, "error": "Invalid incident ID"}), 400
        incident_service.update_fields(incident_id, {'trackingActive': False})
        return jsonify({"success": True, "message": "Tracking stopped"}), 200
    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 404
    except ConnectionError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        logger.exception("POST /incident/%s/stop-tracking failed", incident_id)
        return jsonify({"success": False, "error": str(e)}), 500


@incident_bp.route('/incident/<incident_id>/location', methods=['POST'])
def update_location(incident_id):
    """
    Receives live victim GPS updates from Flutter.

    Body: { "latitude": float, "longitude": float }
    """
    logger.info("POST /incident/%s/location", incident_id)
    try:
        data = request.json
        if not data or 'latitude' not in data or 'longitude' not in data:
            return jsonify({"success": False, "error": "latitude and longitude required"}), 400

        lat = float(data['latitude'])
        lng = float(data['longitude'])

        incident_service.update_fields(incident_id, {
            'victimLat': lat,
            'victimLng': lng,
            'trackingActive': True,
        })
        return jsonify({"success": True}), 200
    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 404
    except ConnectionError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        logger.exception("POST /incident/%s/location failed", incident_id)
        return jsonify({"success": False, "error": str(e)}), 500
