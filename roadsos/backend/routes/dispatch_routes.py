import logging
from flask import Blueprint, jsonify, request
from services.dispatch_service import DispatchService

logger = logging.getLogger('RoadSoS.Routes')

dispatch_bp = Blueprint('dispatch_bp', __name__)
dispatch_service = DispatchService()


@dispatch_bp.route('/dispatch', methods=['POST'])
def dispatch_responder():
    logger.info("POST /dispatch")
    try:
        data = request.json
        if not data or 'incidentId' not in data or 'type' not in data:
            return jsonify({"success": False, "error": "Missing required fields: incidentId, type"}), 400

        incident_id = str(data['incidentId']).strip()
        dispatch_type = str(data['type']).strip().lower()

        # Validate incident ID format
        if not incident_id or len(incident_id) > 128:
            return jsonify({"success": False, "error": "Invalid incidentId format"}), 400

        # Validate dispatch type
        valid_types = ['ambulance', 'police', 'helper']
        if dispatch_type not in valid_types:
            return jsonify({
                "success": False,
                "error": f"Invalid dispatch type '{dispatch_type}'. Must be one of: {valid_types}"
            }), 400

        dispatch_service.dispatch_responder(incident_id, dispatch_type)
        return jsonify({
            "success": True,
            "message": f"{dispatch_type.capitalize()} dispatched successfully"
        }), 200
    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except ConnectionError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        logger.exception("POST /dispatch failed")
        return jsonify({"success": False, "error": str(e)}), 500
