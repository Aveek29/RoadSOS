"""Real-model smoke tests — load the actual 1.97 GB artifact and run inference.

Marked ``real_model``. These are the only tests that assert behaviour of the
genuinely trained Random Forest. They:

  * verify artifact integrity (size + SHA-256) before deserialisation,
  * confirm the loaded model's structure matches the published schema,
  * run inference on **real, legitimate records taken from the published
    dataset** (not fabricated inputs),
  * verify outputs are well-formed and JSON-serialisable,
  * record observed startup and inference latency.

These tests validate plumbing and output shape only — they deliberately do NOT
measure or claim predictive accuracy.
"""
from __future__ import annotations

import json
import os

import pytest

pytestmark = pytest.mark.real_model

# Real records copied verbatim from Road_Accident_Data_Cleaned.csv.gz
# (the dataset published with the model). Used only as schema-valid inputs.
REAL_RECORDS = [
    {
        "rowIndex": 0,
        "features": {
            "Year": 2021, "Latitude": 51.512273, "Longitude": -0.201349,
            "Speed_limit": 30, "Hour": 15, "Day_of_Week": "Thursday",
            "Month": "Jan", "Junction_Control": "Give way or uncontrolled",
            "Light_Conditions": "Daylight", "Road_Surface_Conditions": "Dry",
            "Road_Type": "One way street", "Urban_or_Rural_Area": "Urban",
            "Weather_Conditions": "Fine no high winds", "Vehicle_Type": "Car",
        },
    },
    {
        "rowIndex": 100000,
        "features": {
            "Year": 2021, "Latitude": 51.854002, "Longitude": -0.421827,
            "Speed_limit": 70, "Hour": 9, "Day_of_Week": "Saturday",
            "Month": "Sep", "Junction_Control": "Give way or uncontrolled",
            "Light_Conditions": "Daylight", "Road_Surface_Conditions": "Dry",
            "Road_Type": "Dual carriageway", "Urban_or_Rural_Area": "Rural",
            "Weather_Conditions": "Fine no high winds", "Vehicle_Type": "Car",
        },
    },
]


@pytest.fixture(scope="module")
def real_loader():
    """Load the actual artifact once for this module."""
    from ml.model_loader import ModelLoader
    from ml.config import reload_model_config

    loader = ModelLoader(config=reload_model_config())
    status = loader.ensure_loaded()
    if not status.available:
        pytest.skip(
            f"real model unavailable: {status.reason} "
            "(run scripts/download_model.py first)"
        )
    return loader


def test_artifact_is_present_and_exact_size():
    from ml.config import reload_model_config

    cfg = reload_model_config()
    assert os.path.isfile(cfg.artifact_path), cfg.artifact_path
    size = os.path.getsize(cfg.artifact_path)
    assert size == cfg.expected_size == 1965071297


def test_artifact_sha256_matches_known_digest():
    import hashlib

    from ml.config import reload_model_config

    cfg = reload_model_config()
    assert cfg.expected_sha256, "checksum not configured"
    digest = hashlib.sha256()
    with open(cfg.artifact_path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    assert digest.hexdigest().upper() == cfg.expected_sha256.upper()


def test_model_loads_and_structure_matches_schema(real_loader):
    model = real_loader.model
    from ml.feature_schema import FeatureSchema

    schema = FeatureSchema.from_path(real_loader.config.schema_path)
    assert model.n_features_in_ == schema.n_features == 61
    assert list(model.classes_) == [0, 1, 2]
    assert model.n_estimators == 100
    status = real_loader.status()
    assert status.available and status.state == "loaded"
    assert status.sha256_verified is True
    assert status.load_seconds and status.load_seconds > 0
    # only one load happened (model is reused, not reloaded per request)
    assert real_loader.model is model


@pytest.mark.parametrize("record", REAL_RECORDS, ids=lambda r: f"row{r['rowIndex']}")
def test_real_inference_on_legitimate_records(real_loader, schema, valid_features, record):
    from ml.predictor import SeverityPredictor

    predictor = SeverityPredictor(loader=real_loader, schema=schema)
    result = predictor.predict(record["features"])

    assert result.severity in {"Fatal", "Serious", "Slight"}
    assert set(result.probabilities) == {"Fatal", "Serious", "Slight"}
    assert abs(sum(result.probabilities.values()) - 1.0) < 1e-4
    # returned label must be the argmax of the probability distribution
    assert max(result.probabilities, key=result.probabilities.get) == result.severity
    assert result.predicted_index in (0, 1, 2)
    assert result.latency_ms >= 0
    # round-trips through JSON
    json.dumps(result.to_dict())


def test_real_predictor_health_reports_available(real_loader, schema):
    from ml.predictor import SeverityPredictor

    predictor = SeverityPredictor(loader=real_loader, schema=schema)
    health = predictor.ensure_health()
    assert health["available"] is True
    assert health["sha256Verified"] is True
    assert health["nFeaturesIn"] == 61
    assert health["classOrder"] == ["Fatal", "Serious", "Slight"]


def test_api_end_to_end_with_real_model(
    client, patch_predictor, model_config, schema, real_loader
):
    """Full HTTP round-trip against the genuinely loaded model."""
    from ml.predictor import SeverityPredictor

    predictor = SeverityPredictor(loader=real_loader, schema=schema)
    patch_predictor(predictor)

    res = client.post(
        "/api/v1/predictions/severity",
        json={"features": REAL_RECORDS[0]["features"]},
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["success"] is True
    assert body["prediction"]["severity"] in {"Fatal", "Serious", "Slight"}
    assert set(body["prediction"]["probabilities"]) == {
        "Fatal",
        "Serious",
        "Slight",
    }
    assert body["model"]["revision"] == model_config.revision
    assert body["advisory"] is True
    assert body["limitations"]
    json.dumps(body)


def test_observed_latency_is_reported(real_loader, schema, capsys):
    """Record observed inference latency (informational, not an assertion target)."""
    from ml.predictor import SeverityPredictor
    import time

    predictor = SeverityPredictor(loader=real_loader, schema=schema)
    # warm-up
    predictor.predict(REAL_RECORDS[0]["features"])
    t0 = time.time()
    result = predictor.predict(REAL_RECORDS[1]["features"])
    elapsed_ms = (time.time() - t0) * 1000
    with capsys.disabled():
        print(
            f"\n[real model] inference latency ~{elapsed_ms:.1f}ms "
            f"(reported {result.latency_ms}ms); "
            f"load seconds = {real_loader.status().load_seconds}"
        )
    assert elapsed_ms < 5000
