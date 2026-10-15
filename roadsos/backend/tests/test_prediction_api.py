"""HTTP contract tests for the severity prediction endpoints.

These use an explicit stub model so they assert the API surface (status codes,
error shapes, auth, rate limiting) deterministically without the 1.97 GB
artifact. Real-model behaviour is covered by ``test_model_artifact.py``.
"""
from __future__ import annotations

import pytest

from .conftest import FakeModel, StubLoader, make_predictor


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------
def test_health_reports_available_with_loaded_model(client, patch_predictor, model_config, schema):
    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    res = client.get("/api/v1/model/health")
    assert res.status_code == 200
    body = res.get_json()
    assert body["success"] is True
    assert body["model"]["available"] is True
    assert body["model"]["model"]["name"] == "road-accident-severity-prediction"


def test_health_returns_503_when_model_unavailable(
    client, patch_predictor, model_config, schema
):
    predictor = make_predictor(
        StubLoader(model_config, model=None, unavailable_reason="missing"), schema
    )
    patch_predictor(predictor)
    res = client.get("/api/v1/model/health")
    assert res.status_code == 503
    body = res.get_json()
    assert body["model"]["available"] is False
    assert body["model"]["reason"] == "missing"


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------
def test_schema_endpoint_exposes_contract(client):
    res = client.get("/api/v1/predictions/schema")
    assert res.status_code == 200
    body = res.get_json()
    assert body["output"]["nFeatures"] == 61
    assert body["output"]["classOrder"] == ["Fatal", "Serious", "Slight"]
    assert "Latitute" not in str(body)
    assert "Vehicle_Type" in body["input"]["categoricalFeatures"]
    assert body["limitations"]  # uncertainty is disclosed
    # Clients build their inputs from this document, so the domain
    # restrictions they must enforce travel with it (regression test for a
    # live end-to-end run where speedLimitAllowed was missing).
    assert body["speedLimitAllowed"] == [10, 15, 20, 30, 40, 50, 60, 70]
    assert body["limits"]["hourMin"] == 0
    assert body["limits"]["hourMax"] == 23
    assert body["limits"]["latitudeMin"] <= -90 <= body["limits"]["latitudeMax"]


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------
def test_valid_prediction_returns_structured_response(
    client, patch_predictor, model_config, schema, valid_features
):
    predictor = make_predictor(
        StubLoader(model_config, model=FakeModel(class_index=1)), schema
    )
    patch_predictor(predictor)
    res = client.post(
        "/api/v1/predictions/severity",
        json={"features": valid_features},
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["success"] is True
    assert body["prediction"]["severity"] == "Serious"
    assert set(body["prediction"]["probabilities"]) == {"Fatal", "Serious", "Slight"}
    assert abs(sum(body["prediction"]["probabilities"].values()) - 1.0) < 1e-6
    assert body["model"]["revision"] == model_config.revision
    assert body["advisory"] is True
    assert body["limitations"]
    assert body["predictionId"]
    assert body["timestamp"].endswith("Z")
    # response must be JSON-serialisable and stable
    assert res.get_json() == body


# ---------------------------------------------------------------------------
# Invalid input -> 400 with structured errors
# ---------------------------------------------------------------------------
def test_malformed_json_body_400(client):
    res = client.post(
        "/api/v1/predictions/severity",
        data="{not json",
        content_type="application/json",
    )
    assert res.status_code == 400
    assert res.get_json()["code"] == "INVALID_JSON"


def test_wrong_content_type_400(client):
    res = client.post("/api/v1/predictions/severity", data="features=1")
    assert res.status_code == 400
    assert res.get_json()["code"] == "INVALID_JSON"


def test_missing_features_field_400(client):
    res = client.post("/api/v1/predictions/severity", json={"foo": 1})
    assert res.status_code == 400
    assert res.get_json()["code"] == "INVALID_JSON"


def test_features_not_object_400(client):
    res = client.post("/api/v1/predictions/severity", json={"features": [1, 2]})
    assert res.status_code == 400
    assert res.get_json()["code"] == "INVALID_JSON"


def test_invalid_category_400_with_details(
    client, patch_predictor, model_config, schema, valid_features
):
    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    bad = dict(valid_features, Weather_Conditions="Cyclone")
    res = client.post("/api/v1/predictions/severity", json={"features": bad})
    assert res.status_code == 400
    body = res.get_json()
    assert body["code"] == "INVALID_FEATURES"
    assert any("Weather_Conditions" in d for d in body["details"])


def test_missing_required_features_400(
    client, patch_predictor, model_config, schema
):
    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    res = client.post("/api/v1/predictions/severity", json={"features": {"Hour": 3}})
    assert res.status_code == 400
    body = res.get_json()
    # nearly every other required feature is missing -> reported individually
    assert body["code"] == "INVALID_FEATURES"
    assert any(d.startswith("Year:") for d in body["details"])
    assert any("Vehicle_Type" in d for d in body["details"])
    # the one present, valid field must not be flagged
    assert not any(d.startswith("Hour:") for d in body["details"])


def body_has_details_for(body, key: str) -> bool:
    return any(key in d for d in body.get("details", []))


def test_empty_request_body_400(client):
    res = client.post("/api/v1/predictions/severity")
    assert res.status_code == 400


# ---------------------------------------------------------------------------
# Model unavailable -> 503, never a fabricated prediction
# ---------------------------------------------------------------------------
def test_model_unavailable_returns_503(
    client, patch_predictor, model_config, schema, valid_features
):
    predictor = make_predictor(
        StubLoader(model_config, model=None, unavailable_reason="artifact missing"),
        schema,
    )
    patch_predictor(predictor)
    res = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert res.status_code == 503
    body = res.get_json()
    assert body["code"] == "MODEL_UNAVAILABLE"
    assert "prediction" not in body  # no fabricated result
    assert "emergency" in body["error"].lower()


def test_incident_prediction_503_when_model_down(
    client, patch_predictor, model_config, schema, valid_features
):
    predictor = make_predictor(
        StubLoader(model_config, model=None, unavailable_reason="down"), schema
    )
    patch_predictor(predictor)
    res = client.post(
        "/api/v1/incidents/abc123/severity-prediction",
        json={"features": valid_features},
    )
    assert res.status_code == 503
    assert "prediction" not in res.get_json()


# ---------------------------------------------------------------------------
# Validation before auth/rate-limit ordering & status codes
# ---------------------------------------------------------------------------
def test_invalid_incident_id_400(
    client, patch_predictor, model_config, schema, valid_features
):
    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    res = client.post(
        "/api/v1/incidents//severity-prediction", json={"features": valid_features}
    )
    # empty id will not match the route -> 404 from flask
    assert res.status_code == 404


# ---------------------------------------------------------------------------
# Authorization (optional API key)
# ---------------------------------------------------------------------------
def test_api_key_enforced_when_configured(
    client, patch_predictor, model_config, schema, valid_features, monkeypatch
):
    from routes import prediction_routes

    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    monkeypatch.setattr(prediction_routes, "_api_key", "secret-key")

    denied = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert denied.status_code == 401
    assert denied.get_json()["code"] == "UNAUTHORIZED"

    wrong = client.post(
        "/api/v1/predictions/severity",
        json={"features": valid_features},
        headers={"X-API-Key": "nope"},
    )
    assert wrong.status_code == 401

    ok = client.post(
        "/api/v1/predictions/severity",
        json={"features": valid_features},
        headers={"X-API-Key": "secret-key"},
    )
    assert ok.status_code == 200


def test_api_key_not_required_when_unset(
    client, patch_predictor, model_config, schema, valid_features, monkeypatch
):
    from routes import prediction_routes

    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    monkeypatch.setattr(prediction_routes, "_api_key", "")
    res = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert res.status_code == 200


# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------
def test_rate_limit_returns_429(
    client, patch_predictor, model_config, schema, valid_features, monkeypatch
):
    from routes import prediction_routes
    from ml.rate_limit import RateLimiter

    predictor = make_predictor(StubLoader(model_config, model=FakeModel()), schema)
    patch_predictor(predictor)
    monkeypatch.setattr(
        prediction_routes, "_rate_limit", RateLimiter(max_requests=1, window_seconds=60)
    )

    first = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert first.status_code == 200
    second = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert second.status_code == 429
    assert second.get_json()["code"] == "RATE_LIMITED"
    assert "Retry-After" in second.headers
