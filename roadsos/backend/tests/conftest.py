"""Shared pytest fixtures for the RoadSOS backend test suite.

Notes on the model under test
-----------------------------
* Tests that exercise only HTTP contract / validation logic use a **stub model**
  so they stay fast and deterministic regardless of whether the 1.97 GB artifact
  is present. Stubbed output is clearly marked and is never presented as a
  result of the real trained model.
* Tests that must prove the **real** model works are marked
  ``@pytest.mark.real_model`` and load the actual artifact. They are reported
  separately in the test report.

The suite must be run from the ``backend`` directory with:

    python -m pytest
"""
from __future__ import annotations

import os
import sys

import pytest

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

# Do not eagerly deserialise the 1.97 GB artifact when a test app starts.
# Real-model tests opt in explicitly.
os.environ.setdefault("MODEL_HEALTHCHECK", "0")


# ---------------------------------------------------------------------------
# Fake model + loader (unit / contract tests only)
# ---------------------------------------------------------------------------
class FakeModel:
    """Minimal stand-in exposing only the API the predictor uses."""

    def __init__(self, class_index=2, n_features=61, classes=(0, 1, 2), proba=None):
        self.n_features_in_ = n_features
        self.classes_ = list(classes)
        self._class_index = class_index
        self._proba = proba
        self.calls = 0

    def _row(self, n_classes):
        if self._proba is not None:
            return list(self._proba)
        defaults = {1: [0.0, 1.0], 2: [0.1, 0.2, 0.7], 3: [0.05, 0.15, 0.8]}
        return defaults.get(n_classes, [1.0 / n_classes] * n_classes)

    def predict(self, X):
        self.calls += 1
        return [self._class_index]

    def predict_proba(self, X):
        self.calls += 1
        return [self._row(len(self.classes_))]


class StubLoader:
    """Loader stand-in that can simulate ready / unavailable models."""

    def __init__(self, config, model=None, unavailable_reason=None):
        self._config = config
        self._model = model
        self._reason = unavailable_reason

    @property
    def config(self):
        return self._config

    @property
    def model(self):
        if self._model is None:
            from ml.errors import ModelUnavailableError

            raise ModelUnavailableError(self._reason or "stub unavailable")
        return self._model

    def status(self):
        from ml.model_loader import ModelStatus

        ready = self._model is not None
        return ModelStatus(
            available=ready,
            loaded=ready,
            state="loaded" if ready else "unavailable",
            reason=None if ready else self._reason,
            load_seconds=1.0 if ready else None,
            artifact_size_bytes=1965071297 if ready else None,
            sha256_verified=True if ready else None,
            n_features_in_=61 if ready else None,
        )

    def is_available(self):
        return self._model is not None

    def ensure_loaded(self):
        return self.status()


@pytest.fixture()
def schema():
    from ml.feature_schema import FeatureSchema

    return FeatureSchema.from_path(os.path.join(BACKEND_DIR, "ml", "artifacts", "feature_schema.json"))


@pytest.fixture()
def valid_features():
    """A synthetic-but-schema-valid scenario for technical testing."""
    return {
        "Year": 2021,
        "Latitude": 51.5,
        "Longitude": -0.12,
        "Speed_limit": 30,
        "Hour": 15,
        "Day_of_Week": "Monday",
        "Month": "Mar",
        "Junction_Control": "Auto traffic signal",
        "Light_Conditions": "Daylight",
        "Road_Surface_Conditions": "Dry",
        "Road_Type": "Single carriageway",
        "Urban_or_Rural_Area": "Urban",
        "Weather_Conditions": "Fine no high winds",
        "Vehicle_Type": "Car",
    }


@pytest.fixture()
def model_config():
    from ml.config import reload_model_config

    return reload_model_config()


def make_predictor(loader, schema=None):
    from ml.predictor import SeverityPredictor

    return SeverityPredictor(loader=loader, schema=schema)


@pytest.fixture()
def patch_predictor(monkeypatch, model_config):
    """Patch the prediction routes to use a supplied predictor instance."""

    def _patch(predictor):
        from routes import prediction_routes

        monkeypatch.setattr(prediction_routes, "get_predictor", lambda: predictor)
        return predictor

    return _patch


@pytest.fixture()
def app():
    from app import create_app

    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture()
def client(app):
    return app.test_client()


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "real_model: tests that load and exercise the real trained model artifact",
    )
