"""Accident-severity prediction API (ML inference endpoints).

Endpoints
---------
``GET  /api/v1/model/health``
    Reports whether the trained model is loaded and how to reach it.

``GET  /api/v1/predictions/schema``
    Returns the exact input contract (features, categories, class order).

``POST /api/v1/predictions/severity``
    Validates a scenario, runs the real Random Forest and returns the predicted
    class plus the model's class distribution.

``POST /api/v1/incidents/<incident_id>/severity-prediction``
    Runs the prediction *and* attaches the result to an existing incident,
    persisting it and broadcasting it over Socket.IO.

Safety
------
These endpoints are strictly **advisory**. They never create incidents, never
change incident status, and never influence crash detection or emergency
escalation. If the model is unavailable the endpoints report 503 while every
existing emergency workflow continues to function normally.
"""
from __future__ import annotations

import hmac
import logging
import os
import uuid
from datetime import datetime, timezone

from flask import Blueprint, jsonify, request

from extensions import socketio
from ml.errors import (
    FeatureValidationError,
    ModelArtifactError,
    ModelUnavailableError,
)
from ml.predictor import get_predictor
from ml.rate_limit import RateLimiter

logger = logging.getLogger("RoadSoS.Routes.Predictions")

prediction_bp = Blueprint("prediction_bp", __name__)

# --- configuration -----------------------------------------------------------
_api_key = os.environ.get("ROADSOS_API_KEY", "").strip()
_rate_limit = RateLimiter(
    max_requests=int(os.environ.get("PREDICTION_RATE_LIMIT_PER_MIN", "60")),
    window_seconds=60.0,
)

# Disclosed with every response so consumers never over-trust the output.
LIMITATIONS = [
    "Model-derived severity is a statistical estimate, not a confirmed outcome "
    "or a medical assessment.",
    "Probabilities are the model's vote distribution and are not calibrated "
    "real-world probabilities.",
    "The model uses environmental, infrastructure and spatio-temporal features; "
    "it does not observe the actual crash.",
    "Driver behaviour (alcohol, distraction, fatigue) and demographics are not "
    "modelled.",
]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _unauthorized():
    return (
        jsonify(
            {
                "success": False,
                "error": "Missing or invalid API key",
                "code": "UNAUTHORIZED",
            }
        ),
        401,
    )


def _require_api_key():
    """Optional bearer-style protection for inference endpoints."""
    if not _api_key:
        return None  # not configured -> open (local development)
    provided = request.headers.get("X-API-Key") or ""
    if not provided and request.headers.get("Authorization", "").startswith("Bearer "):
        provided = request.headers["Authorization"][7:].strip()
    # Constant-time comparison so a wrong guess cannot leak the key byte by byte.
    if not hmac.compare_digest(provided.encode("utf-8"), _api_key.encode("utf-8")):
        return _unauthorized()
    return None


def _client_key() -> str:
    try:
        return request.remote_addr or "unknown"
    except Exception:  # pragma: no cover
        return "unknown"


def _rate_limited():
    key = _client_key()
    retry_after = _rate_limit.retry_after(key)
    return (
        jsonify(
            {
                "success": False,
                "error": "Prediction rate limit exceeded",
                "code": "RATE_LIMITED",
                "retryAfterSeconds": retry_after,
            }
        ),
        429,
        {"Retry-After": str(retry_after)},
    )


def _read_json():
    """Return ``(payload, error_response)`` — exactly one is non-None."""
    if not request.is_json:
        return None, (
            jsonify(
                {
                    "success": False,
                    "error": "Request Content-Type must be application/json",
                    "code": "INVALID_JSON",
                }
            ),
            400,
        )
    payload = request.get_json(silent=True, cache=True)
    if payload is None or not isinstance(payload, dict):
        return None, (
            jsonify(
                {
                    "success": False,
                    "error": "Malformed JSON body: expected a JSON object",
                    "code": "INVALID_JSON",
                }
            ),
            400,
        )
    if "features" not in payload:
        return None, (
            jsonify(
                {
                    "success": False,
                    "error": "Missing required field: 'features'",
                    "code": "INVALID_JSON",
                }
            ),
            400,
        )
    return payload, (None, None)


def _model_unavailable_response(exc: Exception):
    logger.warning("Severity inference requested but model unavailable: %s", exc)
    return (
        jsonify(
            {
                "success": False,
                "error": "Accident-severity model is currently unavailable. "
                "Emergency incident handling is unaffected.",
                "code": "MODEL_UNAVAILABLE",
            }
        ),
        503,
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------
@prediction_bp.route("/api/v1/model/health", methods=["GET"])
def model_health():
    logger.info("GET /api/v1/model/health")
    try:
        predictor = get_predictor()
        # Ensure a load attempt so readiness is reported truthfully (the
        # loader caches the model after the first successful load).
        health = predictor.ensure_health()
    except Exception as exc:  # pragma: no cover - defensive
        logger.exception("model health failed")
        return jsonify({"success": False, "error": str(exc)}), 500

    payload = {"success": True, "model": health}
    # 200 when ready, 503 when loaded-but-unavailable so probes can gate on it.
    return jsonify(payload), (200 if health.get("available") else 503)


# ---------------------------------------------------------------------------
# Schema (self-documenting contract)
# ---------------------------------------------------------------------------
@prediction_bp.route("/api/v1/predictions/schema", methods=["GET"])
def prediction_schema():
    logger.info("GET /api/v1/predictions/schema")
    try:
        predictor = get_predictor()
        schema = predictor.schema
        return (
            jsonify(
                {
                    "success": True,
                    "schemaVersion": schema._raw.get("schema_version"),
                    "model": schema.model_meta,
                    "input": {
                        "numericFeatures": schema.numeric_features,
                        "categoricalFeatures": {
                            name: {"values": c["values"], "baseline": c["baseline"]}
                            for name, c in schema.categorical.items()
                        },
                    },
                    "output": {
                        "classOrder": schema.class_order,
                        "classLabels": schema.class_labels,
                        "nFeatures": schema.n_features,
                    },
                    # Domain restrictions the client should enforce before
                    # sending (absent here means "not restricted").
                    "speedLimitAllowed": schema.validation.get(
                        "speed_limit_allowed", []
                    ),
                    "limits": {
                        "yearMin": schema.validation.get("year_min"),
                        "yearMax": schema.validation.get("year_max"),
                        "hourMin": schema.validation.get("hour_min"),
                        "hourMax": schema.validation.get("hour_max"),
                        "latitudeMin": schema.validation.get("latitude_min"),
                        "latitudeMax": schema.validation.get("latitude_max"),
                        "longitudeMin": schema.validation.get("longitude_min"),
                        "longitudeMax": schema.validation.get("longitude_max"),
                    },
                    "limitations": LIMITATIONS,
                }
            ),
            200,
        )
    except Exception as exc:
        logger.exception("prediction schema failed")
        return jsonify({"success": False, "error": str(exc)}), 500


# ---------------------------------------------------------------------------
# Predict severity
# ---------------------------------------------------------------------------
@prediction_bp.route("/api/v1/predictions/severity", methods=["POST"])
def predict_severity():
    logger.info("POST /api/v1/predictions/severity")

    denied = _require_api_key()
    if denied is not None:
        return denied
    if not _rate_limit.allow(_client_key()):
        return _rate_limited()

    payload, err = _read_json()
    if payload is None:
        return err
    features = payload.get("features")
    if not isinstance(features, dict):
        return (
            jsonify(
                {
                    "success": False,
                    "error": "'features' must be a JSON object of feature values",
                    "code": "INVALID_JSON",
                }
            ),
            400,
        )

    try:
        predictor = get_predictor()
        result = predictor.predict(features)
    except FeatureValidationError as exc:
        logger.info("Prediction rejected: %s", exc.details)
        return (
            jsonify(
                {
                    "success": False,
                    "error": exc.message,
                    "code": "INVALID_FEATURES",
                    "details": exc.details,
                }
            ),
            400,
        )
    except (ModelUnavailableError, ModelArtifactError) as exc:
        return _model_unavailable_response(exc)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Unexpected prediction failure")
        return (
            jsonify(
                {
                    "success": False,
                    "error": "Internal error while computing prediction",
                    "code": "PREDICTION_FAILED",
                }
            ),
            500,
        )

    model_meta = predictor.loader.config.describe()
    return (
        jsonify(
            {
                "success": True,
                "prediction": result.to_dict(),
                "model": model_meta,
                "predictionId": uuid.uuid4().hex,
                "timestamp": _now_iso(),
                "advisory": True,
                "limitations": LIMITATIONS,
            }
        ),
        200,
    )


# ---------------------------------------------------------------------------
# Predict and attach to an existing incident
# ---------------------------------------------------------------------------
@prediction_bp.route(
    "/api/v1/incidents/<incident_id>/severity-prediction", methods=["POST"]
)
def predict_for_incident(incident_id):
    logger.info("POST /api/v1/incidents/%s/severity-prediction", incident_id)

    denied = _require_api_key()
    if denied is not None:
        return denied
    if not _rate_limit.allow(_client_key()):
        return _rate_limited()

    if not incident_id or len(incident_id) > 128:
        return jsonify({"success": False, "error": "Invalid incident ID"}), 400

    payload, err = _read_json()
    if payload is None:
        return err
    features = payload.get("features")
    if not isinstance(features, dict):
        return (
            jsonify(
                {
                    "success": False,
                    "error": "'features' must be a JSON object of feature values",
                    "code": "INVALID_JSON",
                }
            ),
            400,
        )

    try:
        predictor = get_predictor()
        result = predictor.predict(features)
    except FeatureValidationError as exc:
        return (
            jsonify(
                {
                    "success": False,
                    "error": exc.message,
                    "code": "INVALID_FEATURES",
                    "details": exc.details,
                }
            ),
            400,
        )
    except (ModelUnavailableError, ModelArtifactError) as exc:
        return _model_unavailable_response(exc)
    except Exception:  # noqa: BLE001
        logger.exception("Unexpected prediction failure")
        return (
            jsonify(
                {
                    "success": False,
                    "error": "Internal error while computing prediction",
                    "code": "PREDICTION_FAILED",
                }
            ),
            500,
        )

    prediction_id = uuid.uuid4().hex
    stored = _attach_prediction(
        incident_id, prediction_id, result.to_dict()
    )

    if stored == "not_found":
        return jsonify({"success": False, "error": "Incident not found"}), 404
    if stored == "disconnected":
        logger.warning(
            "Firestore unavailable — returning prediction without persistence"
        )

    body = {
        "success": True,
        "incidentId": incident_id,
        "predictionId": prediction_id,
        "prediction": result.to_dict(),
        "model": predictor.loader.config.describe(),
        "timestamp": _now_iso(),
        "persisted": stored == "persisted",
        "advisory": True,
        "limitations": LIMITATIONS,
    }
    return jsonify(body), 200


def _attach_prediction(incident_id: str, prediction_id: str, result: dict) -> str:
    """Persist the prediction onto the incident and broadcast it.

    Returns ``"persisted"`` | ``"disconnected"`` | ``"not_found"``.
    Only adds a new ``severityPrediction`` sub-object — it never mutates the
    incident's existing status, sensor severity or escalation fields.
    """
    prediction_doc = {
        "predictionId": prediction_id,
        "severity": result["severity"],
        "probabilities": result["probabilities"],
        "classOrder": result["classOrder"],
        "modelVersion": result["modelVersion"],
        "model": "road-accident-severity-prediction",
        "predictedAt": _now_iso(),
        "advisory": True,
        "source": "ml",
    }

    # Broadcast first so real-time consumers always get the estimate even if
    # persistence is unavailable (never lose a prediction because of Firestore).
    try:
        socketio.emit(
            "severity_prediction",
            {"incidentId": incident_id, "prediction": prediction_doc},
        )
    except Exception as exc:  # pragma: no cover
        logger.warning("Failed to emit severity_prediction: %s", exc)

    try:
        from services.firestore_service import FirestoreService

        fs = FirestoreService()
        if not fs.is_connected:
            return "disconnected"
        doc = fs.get_document("incidents", incident_id)
        if not getattr(doc, "exists", False):
            return "not_found"
        fs.update_document("incidents", incident_id, {"severityPrediction": prediction_doc})
        return "persisted"
    except Exception as exc:
        logger.warning("Could not persist prediction for %s: %s", incident_id, exc)
        return "disconnected"
