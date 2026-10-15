"""Unit tests for the SeverityPredictor using an explicit stub model.

These validate surrounding logic (label mapping, probability handling, error
propagation). They deliberately do NOT claim the trained model works — that is
covered by the ``real_model``-marked suite.
"""
from __future__ import annotations

import pytest

from ml.errors import FeatureValidationError, ModelUnavailableError

from .conftest import FakeModel, StubLoader, make_predictor


def test_predict_maps_class_index_to_label(schema, model_config, valid_features):
    loader = StubLoader(model_config, model=FakeModel(class_index=1))
    predictor = make_predictor(loader, schema)
    result = predictor.predict(valid_features)
    assert result.severity == "Serious"
    assert result.predicted_index == 1
    assert list(result.class_order) == ["Fatal", "Serious", "Slight"]
    assert result.model_version == model_config.revision


def test_probabilities_cover_all_classes_and_sum_to_one(
    schema, model_config, valid_features
):
    loader = StubLoader(model_config, model=FakeModel(class_index=2))
    predictor = make_predictor(loader, schema)
    result = predictor.predict(valid_features)
    assert set(result.probabilities) == {"Fatal", "Serious", "Slight"}
    assert abs(sum(result.probabilities.values()) - 1.0) < 1e-6
    # most-probable class must match the returned label
    top = max(result.probabilities, key=result.probabilities.get)
    assert top == result.severity


def test_probability_row_is_normalised(schema, model_config, valid_features):
    unbalanced = [0.5, 0.25, 0.25]
    loader = StubLoader(model_config, model=FakeModel(class_index=0, proba=unbalanced))
    predictor = make_predictor(loader, schema)
    result = predictor.predict(valid_features)
    assert abs(sum(result.probabilities.values()) - 1.0) < 1e-6
    assert result.severity == "Fatal"


def test_invalid_features_raise_validation_error(schema, model_config):
    loader = StubLoader(model_config, model=FakeModel())
    predictor = make_predictor(loader, schema)
    with pytest.raises(FeatureValidationError):
        predictor.predict({"Year": 2021})  # missing nearly everything


def test_model_unavailable_propagates(schema, model_config, valid_features):
    loader = StubLoader(
        model_config, model=None, unavailable_reason="artifact missing"
    )
    predictor = make_predictor(loader, schema)
    with pytest.raises(ModelUnavailableError):
        predictor.predict(valid_features)


def test_valid_input_is_encoded_before_predict(schema, model_config, valid_features):
    model = FakeModel(class_index=2)
    loader = StubLoader(model_config, model=model)
    predictor = make_predictor(loader, schema)
    predictor.predict(valid_features)
    assert model.calls > 0


def test_health_reports_available_when_model_present(schema, model_config):
    loader = StubLoader(model_config, model=FakeModel())
    predictor = make_predictor(loader, schema)
    health = predictor.health()
    assert health["available"] is True
    assert health["state"] == "loaded"
    assert health["classOrder"] == ["Fatal", "Serious", "Slight"]
    assert health["nFeaturesSchema"] == 61
    # client-facing health must not leak filesystem paths or secrets
    dumped = str(health)
    assert "\\" not in dumped and "/tmp" not in dumped
    assert "serviceAccount" not in dumped and "API_KEY" not in dumped


def test_health_reports_unavailable_when_missing(schema, model_config):
    loader = StubLoader(model_config, model=None, unavailable_reason="missing")
    predictor = make_predictor(loader, schema)
    health = predictor.health()
    assert health["available"] is False
    assert health["state"] == "unavailable"
    assert health["reason"] == "missing"
