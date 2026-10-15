import logging
from flask import Blueprint, jsonify
from services.firestore_service import FirestoreService

logger = logging.getLogger('RoadSoS.Routes')

health_bp = Blueprint('health_bp', __name__)


@health_bp.route('/health', methods=['GET'])
def health_check():
    logger.info("GET /health")

    # Check Firebase/Firestore connectivity
    try:
        fs = FirestoreService()
        firebase_status = "connected" if fs.is_connected else "disconnected"
    except Exception:
        firebase_status = "error"

    return jsonify({
        "status": "OK",
        "firebase": firebase_status,
    }), 200
