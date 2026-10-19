import os
import logging
import time


def _load_env_file(filename: str = ".env") -> None:
    """Load KEY=VALUE lines from ``backend/.env`` without extra dependencies.

    * Existing environment variables always win (shell/CI settings are never
      clobbered — same rule as python-dotenv's ``load_dotenv``).
    * Comments, blank lines and quoted values are handled; a missing file is a
      silent no-op.
    * Must run *before* any module reads ``os.environ`` at import time (the
      prediction blueprint reads its configuration on import).
    """
    if not os.path.isfile(filename):
        return
    try:
        with open(filename, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip()
                if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                    value = value[1:-1]
                if key and key not in os.environ:
                    os.environ[key] = value
    except OSError as exc:  # pragma: no cover - unreadable file
        logging.getLogger("RoadSoS").warning("Could not read %s: %s", filename, exc)


_load_env_file()  # before anything below reads os.environ at import time

from flask import Flask, request, g  # noqa: E402
from flask_cors import CORS  # noqa: E402
import firebase_admin  # noqa: E402
from firebase_admin import credentials  # noqa: E402

from extensions import socketio  # noqa: E402
from routes.health_routes import health_bp  # noqa: E402
from routes.incident_routes import incident_bp  # noqa: E402
from routes.dispatch_routes import dispatch_bp  # noqa: E402
from routes.helper_routes import helper_bp  # noqa: E402
from routes.analytics_routes import analytics_bp  # noqa: E402
from routes.demo_routes import demo_bp  # noqa: E402
from routes.prediction_routes import prediction_bp  # noqa: E402

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('RoadSoS')


def setup_firestore_listener(app):
    from firebase_admin import firestore
    from extensions import socketio
    
    try:
        db = firestore.client()
    except Exception as e:
        logger.warning(f"Could not start Firestore listener: {e}")
        return

    def clean_data(data):
        if isinstance(data, dict):
            return {k: clean_data(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [clean_data(item) for item in data]
        elif hasattr(data, 'isoformat'):
            return data.isoformat()
        elif type(data).__name__ == 'DatetimeWithNanoseconds':
            return str(data)
        return data

    def on_snapshot(col_snapshot, changes, read_time):
        with app.app_context():
            for change in changes:
                doc = change.document
                data = clean_data(doc.to_dict())
                data['id'] = doc.id
                
                if change.type.name == 'ADDED':
                    logger.info(f"Firestore added: {doc.id}")
                    socketio.emit('incident_created', data)
                elif change.type.name == 'MODIFIED':
                    logger.info(f"Firestore modified: {doc.id}")
                    socketio.emit('incident_updated', data)
                elif change.type.name == 'REMOVED':
                    logger.info(f"Firestore removed: {doc.id}")
                    socketio.emit('incident_deleted', {'id': doc.id})

    # Watch incidents collection
    db.collection('incidents').on_snapshot(on_snapshot)
    logger.info("Firestore listener registered on 'incidents' collection.")


@socketio.on('connect')
def handle_connect():
    logger.info("Client connected to SocketIO")


@socketio.on('disconnect')
def handle_disconnect():
    logger.info("Client disconnected from SocketIO")


@socketio.on('create_incident')
def handle_create_incident(data):
    logger.info(f"Socket event: create_incident received: {data}")
    from services.firestore_service import FirestoreService
    import uuid
    from datetime import datetime, timezone
    
    fs = FirestoreService()
    lat = float(data.get('latitude', 0.0))
    lng = float(data.get('longitude', 0.0))
    confidence = float(data.get('confidence', 0.5))
    severity = data.get('severity', 'LOW')
    severity_score = float(data.get('severityScore', 0.1))
    plus_code = data.get('plusCode', '')

    now_iso = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
    incident_data = {
        'latitude': lat,
        'longitude': lng,
        'victimLat': lat,
        'victimLng': lng,
        'timestamp': now_iso,
        'status': 'ACTIVE',
        'source': 'mobile',
        'trackingActive': True,
        'acceptedHelpers': [],
        'helperSlots': 0,
        'helperRequestOpen': True,
        'dispatchedResources': [],
        'confidence': confidence,
        'severity': severity,
        'severityScore': severity_score,
        'plusCode': plus_code,
    }

    if fs.is_connected:
        try:
            doc_id = fs.add_document('incidents', incident_data)
            incident_data['id'] = doc_id
            logger.info(f"Incident created via socket in Firestore: {doc_id}")
        except Exception as e:
            logger.error(f"Failed to add incident to Firestore: {e}")
            incident_data['id'] = f"sock_{uuid.uuid4().hex[:8]}"
            socketio.emit('incident_created', incident_data)
    else:
        incident_data['id'] = f"sock_{uuid.uuid4().hex[:8]}"
        socketio.emit('incident_created', incident_data)


@socketio.on('update_location')
def handle_update_location(data):
    logger.info(f"Socket event: update_location received: {data}")
    from services.firestore_service import FirestoreService
    fs = FirestoreService()
    incident_id = data.get('incidentId')
    lat = float(data.get('latitude', 0.0))
    lng = float(data.get('longitude', 0.0))
    
    if incident_id and fs.is_connected:
        try:
            fs.update_document('incidents', incident_id, {
                'victimLat': lat,
                'victimLng': lng,
                'trackingActive': True
            })
        except Exception as e:
            logger.error(f"Failed to update location: {e}")


@socketio.on('dispatch_resource')
def handle_dispatch_resource(data):
    logger.info(f"Socket event: dispatch_resource received: {data}")
    from services.dispatch_service import DispatchService
    dispatch_service = DispatchService()
    incident_id = data.get('incidentId')
    dispatch_type = str(data.get('type', '')).lower()
    
    if incident_id and dispatch_type:
        try:
            dispatch_service.dispatch_responder(incident_id, dispatch_type)
        except Exception as e:
            logger.error(f"Failed to dispatch resource via socket: {e}")


@socketio.on('update_status')
def handle_update_status(data):
    logger.info(f"Socket event: update_status received: {data}")
    from services.incident_service import IncidentService
    incident_service = IncidentService()
    incident_id = data.get('incidentId')
    status = str(data.get('status', '')).upper()
    
    if incident_id and status:
        try:
            incident_service.update_status(incident_id, status)
        except Exception as e:
            logger.error(f"Failed to update status via socket: {e}")


@socketio.on('helper_respond')
def handle_helper_respond(data):
    logger.info(f"Socket event: helper_respond received: {data}")
    from services.helper_service import HelperService
    helper_service = HelperService()
    incident_id = data.get('incidentId')
    helper_uid = data.get('helperUid')
    accepted = bool(data.get('accepted', False))
    distance = float(data.get('distanceMeters', 0.0))
    
    if not incident_id or not helper_uid:
        # Ack back so the Flutter HelperResponseScreen never waits on silence.
        return {'success': False, 'message': 'incidentId and helperUid are required'}

    try:
        if accepted:
            result = helper_service.accept_incident(incident_id, helper_uid, distance)
            if result.get('success'):
                socketio.emit('helper_accepted', {
                    'incidentId': incident_id,
                    'helperUid': helper_uid,
                    'helperName': result.get('helperName', 'Volunteer'),
                    'slotsFilled': result.get('slotsFilled', 0),
                    'distanceMeters': distance,
                    'missionId': result.get('missionId'),
                })
            # Return the accept/decline result as the Socket.IO ACK so the
            # mobile client receives a structured {success, message} instead
            # of an empty payload.
            return {
                'success': bool(result.get('success')),
                'message': result.get('message', ''),
                'slotsFilled': result.get('slotsFilled', 0),
                'missionId': result.get('missionId'),
            }
        result = helper_service.decline_incident(incident_id, helper_uid)
        return {
            'success': bool(result.get('success')),
            'message': result.get('message', 'Response recorded'),
        }
    except Exception as e:
        logger.error(f"Failed helper respond via socket: {e}")
        return {'success': False, 'message': 'Could not record response. Please try again.'}


@socketio.on('stop_tracking')
def handle_stop_tracking(data):
    logger.info(f"Socket event: stop_tracking received: {data}")
    from services.firestore_service import FirestoreService
    fs = FirestoreService()
    incident_id = data.get('incidentId')
    
    if incident_id and fs.is_connected:
        try:
            fs.update_document('incidents', incident_id, {'trackingActive': False})
        except Exception as e:
            logger.error(f"Failed to stop tracking: {e}")


def _allowed_origins():
    """Explicit allowed-origin list, else fall back to permissive (dev)."""
    raw = os.environ.get("ALLOWED_ORIGINS", "").strip()
    if not raw:
        logger.warning(
            "ALLOWED_ORIGINS is not set — CORS will allow any origin. "
            "Restrict this in production."
        )
        return "*"
    return [o.strip() for o in raw.split(",") if o.strip()]


def _startup_model(app):
    """Attempt to warm the severity model at startup.

    Loading ≈1.97 GB takes a few seconds; doing it here (not per-request) keeps
    inference latency low. Failures are logged and *non-fatal* — the rest of the
    application, including every emergency workflow, keeps running with the
    model reporting itself as unavailable.
    """
    try:
        from ml.predictor import get_predictor
    except Exception as e:  # pragma: no cover - import safety
        logger.warning("ML package unavailable: %s", e)
        return

    if not os.environ.get("MODEL_HEALTHCHECK", "1").strip().lower() in (
        "1", "true", "yes", "on"
    ):
        logger.info("Eager model loading disabled (MODEL_HEALTHCHECK=0).")
        return

    try:
        status = get_predictor().ensure_health()
        if status.get("available"):
            logger.info(
                "Severity model ready (load=%.2fs, sha256_verified=%s).",
                status.get("loadSeconds") or 0.0,
                status.get("sha256Verified"),
            )
        else:
            logger.warning(
                "Severity model NOT available: %s", status.get("reason")
            )
    except Exception as e:  # pragma: no cover - never block startup
        logger.warning("Severity model warm-up failed (non-fatal): %s", e)


def create_app():
    app = Flask(__name__)
    allowed = _allowed_origins()
    if allowed == "*":
        CORS(app)
    else:
        CORS(app, origins=allowed, supports_credentials=False)

    # Bound JSON request bodies (prediction + incident payloads are small).
    try:
        app.config["MAX_CONTENT_LENGTH"] = int(
            os.environ.get("MAX_CONTENT_LENGTH", 1024 * 1024)
        )
    except ValueError:
        app.config["MAX_CONTENT_LENGTH"] = 1024 * 1024

    # Initialize SocketIO with app (honor the same origin policy as HTTP)
    socketio.init_app(app, cors_allowed_origins=allowed)

    # Initialize Firebase Admin SDK
    cred_path = os.environ.get('FIREBASE_SERVICE_ACCOUNT_KEY', 'serviceAccountKey.json')
    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin initialized successfully.")
        setup_firestore_listener(app)
    except Exception as e:
        logger.warning(f"Firebase initialization failed or key missing: {e}")
        logger.warning("Ensure serviceAccountKey.json is present for Firestore API calls to work.")

    # Register Blueprints for modular routing
    app.register_blueprint(health_bp)
    app.register_blueprint(incident_bp)
    app.register_blueprint(dispatch_bp)
    app.register_blueprint(helper_bp)
    app.register_blueprint(analytics_bp)
    app.register_blueprint(demo_bp)
    app.register_blueprint(prediction_bp)

    # Warm the ML model once at startup (non-fatal if unavailable).
    _startup_model(app)

    # Request logging middleware
    @app.before_request
    def _before_request():
        g.start_time = time.time()

    @app.after_request
    def _after_request(response):
        latency = (time.time() - g.start_time) * 1000  # ms
        logger.info(
            "%s %s → %d (%.1fms)",
            request.method,
            request.path,
            response.status_code,
            latency,
        )
        return response

    logger.info("Flask Command Center started with SocketIO.")
    return app


if __name__ == '__main__':
    app = create_app()
    # Run configuration (dev defaults are explicit and overridable):
    #   RUN_HOST  – '127.0.0.1' behind a proxy, '0.0.0.0' for LAN demos
    #   RUN_PORT  – default 5000
    #   FLASK_DEBUG=1 – interactive debugger + auto-reload. NEVER enable this
    #                   where untrusted clients can reach the port: the Werkzeug
    #                   debugger can execute code.
    _host = os.environ.get("RUN_HOST", "0.0.0.0").strip() or "0.0.0.0"
    _port = int(os.environ.get("RUN_PORT", "5000") or 5000)
    _debug = os.environ.get("FLASK_DEBUG", "0").strip().lower() in ("1", "true", "yes", "on")
    if _debug:
        logger.warning(
            "FLASK_DEBUG=1: the Werkzeug debugger is enabled and reachable on "
            "%s:%s — use only on trusted networks.", _host, _port,
        )
    logger.info(
        "Serving on http://%s:%s  (FLASK_DEBUG=%s, reloader=off)",
        _host, _port, 1 if _debug else 0,
    )
    # use_reloader=False is deliberate: a file watcher would silently restart
    # the process mid-demo and spawn a second python.exe. FLASK_DEBUG only
    # controls the (off-by-default) interactive debugger.
    socketio.run(app, host=_host, port=_port, debug=_debug, use_reloader=False,
                 allow_unsafe_werkzeug=True)

