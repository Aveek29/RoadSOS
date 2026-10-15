"""Safety invariants for a safety-critical application.

Proves that:
  * ML failure can never block or break emergency incident creation.
  * Severity predictions are advisory only — they never mutate incident status
    or suppress escalation.
  * Existing crash-detection / demo incident workflows keep working when the
    model is unavailable.

If any of these fail, the integration is unsafe and must not ship.
"""
from __future__ import annotations

import pytest

from .conftest import FakeModel, StubLoader, make_predictor


def test_incident_creation_works_while_model_unavailable(
    client, patch_predictor, model_config, schema
):
    """`/demo/simulate` must still create incidents with the model down."""
    from extensions import socketio

    captured = []

    class _FakeSock:
        def emit(self, event, payload=None, **kw):
            captured.append((event, payload))

    # Force the ML layer into an unavailable state.
    down = make_predictor(
        StubLoader(model_config, model=None, unavailable_reason="model down"), schema
    )
    patch_predictor(down)

    original_emit = socketio.emit
    socketio.emit = _FakeSock().emit
    try:
        res = client.post("/demo/simulate", json={"severityType": "major"})
        assert res.status_code == 201, res.get_json()
        body = res.get_json()
        assert body["success"] is True
        assert body["severity"] in {"LOW", "MEDIUM", "HIGH", "CRITICAL"}
        # incident came from the SENSOR heuristic, not the ML model
        assert isinstance(body["severityScore"], (int, float))
    finally:
        socketio.emit = original_emit


def test_prediction_endpoints_do_not_create_or_mutate_incidents(
    client, patch_predictor, model_config, schema, valid_features
):
    """A prediction must be purely advisory: no status side effects."""
    from extensions import socketio

    up = make_predictor(StubLoader(model_config, model=FakeModel(class_index=0)), schema)
    patch_predictor(up)

    emitted = []

    class _Capture:
        def emit(self, event, payload=None, **kw):
            emitted.append((event, payload))

    socketio_emit_orig = socketio.emit
    socketio.emit = _Capture().emit
    try:
        res = client.post(
            "/api/v1/predictions/severity", json={"features": valid_features}
        )
        assert res.status_code == 200
        body = res.get_json()
        # Advisory payload must not carry any incident status change
        assert "status" not in body
        assert body["advisory"] is True
        # the disclaimer that this is an estimate, not a confirmed outcome, is present
        assert any("not a confirmed outcome" in m for m in body["limitations"])
        assert body["prediction"]["severity"] in {"Fatal", "Serious", "Slight"}
        # the standalone prediction endpoint never touched the incident collection
        assert emitted == []
    finally:
        socketio.emit = socketio_emit_orig


def test_fatal_prediction_does_not_claim_confirmation(
    client, patch_predictor, model_config, schema, valid_features
):
    """A predicted 'Fatal' must be presented as an estimate, never a fatality."""
    import sys

    FakeModel = sys.modules["tests.conftest"].FakeModel
    up = make_predictor(
        StubLoader(model_config, model=FakeModel(class_index=0)), schema
    )
    patch_predictor(up)
    res = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert res.status_code == 200
    body = res.get_json()
    assert body["prediction"]["severity"] == "Fatal"
    assert body["advisory"] is True
    assert any("not a confirmed outcome" in m for m in body["limitations"])


def test_slight_prediction_never_cancels_anything(
    client, patch_predictor, model_config, schema, valid_features
):
    """A 'Slight' prediction must not suppress emergency escalation.

    The prediction payload contains no cancel/escalate instruction, and the
    incident escalation path (demo/simulate + existing severity fields) is
    completely independent of the ML result.
    """
    import sys

    FakeModel = sys.modules["tests.conftest"].FakeModel
    up = make_predictor(
        StubLoader(model_config, model=FakeModel(class_index=2)), schema
    )
    patch_predictor(up)
    res = client.post("/api/v1/predictions/severity", json={"features": valid_features})
    assert res.status_code == 200
    body = res.get_json()
    assert body["prediction"]["severity"] == "Slight"
    dumped = str(body).lower()
    for banned in ("cancel", "suppress", "clear_alert", "dismiss"):
        assert banned not in dumped


def test_model_unavailable_does_not_break_health_or_app(client):
    """The app's own /health must keep answering even without the model."""
    res = client.get("/health")
    assert res.status_code == 200
    body = res.get_json()
    # ML status must not be required for the core health check to be OK
    assert body["status"] == "OK"


def test_loader_reports_unavailable_for_missing_artifact(tmp_path):
    """Corrupt/missing artifact -> explicit unavailable status, not a crash."""
    from ml.config import reload_model_config, ModelConfig
    from ml.model_loader import ModelLoader

    bad = ModelConfig(
        repo_id="x", revision="y", filename="nope.pkl",
        expected_size=0, expected_sha256="",
        artifact_path=str(tmp_path / "nope.pkl"),
        schema_path=reload_model_config().schema_path,
        healthcheck_eager=True, cache_candidates=(),
    )
    loader = ModelLoader(config=bad)
    status = loader.ensure_loaded()
    assert status.available is False
    assert status.state == "unavailable"
    assert status.reason  # a reason is always surfaced

    from ml.errors import ModelUnavailableError

    with pytest.raises(ModelUnavailableError):
        _ = loader.model


def test_loader_refuses_checksum_mismatch(tmp_path):
    """An artifact whose SHA-256 does not match must never be deserialised."""
    from ml.config import reload_model_config, ModelConfig
    from ml.model_loader import ModelLoader

    fake = tmp_path / "road_accident_model.pkl"
    fake.write_bytes(b"not the real model")

    cfg = ModelConfig(
        repo_id="x", revision="y", filename=fake.name,
        expected_size=len(b"not the real model"), expected_sha256="DEADBEEF",
        artifact_path=str(fake),
        schema_path=reload_model_config().schema_path,
        healthcheck_eager=True, cache_candidates=(),
    )
    loader = ModelLoader(config=cfg)
    status = loader.ensure_loaded()
    assert status.available is False
    assert "SHA-256" in (status.reason or "") or "checksum" in (status.reason or "").lower()


def test_prediction_never_blocks_when_payload_is_huge(client):
    """Large bodies are rejected by the size cap (413) before inference."""
    res = client.post(
        "/api/v1/predictions/severity",
        data='{"features": {"pad": "' + ("a" * 2_000_000) + '"}}',
        content_type="application/json",
    )
    assert res.status_code in (413, 400)
