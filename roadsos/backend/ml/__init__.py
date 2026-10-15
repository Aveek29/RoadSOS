"""RoadSOS ML inference package.

Exposes the accident-severity prediction service. This package is deliberately
decoupled from the emergency-response code paths so that an unavailable or
failing model can never block crash detection, incident creation or dispatch.
"""
from ml.config import ModelConfig, get_model_config
from ml.errors import (
    FeatureValidationError,
    ModelArtifactError,
    ModelUnavailableError,
)
from ml.predictor import SeverityPredictor, get_predictor

__all__ = [
    "ModelConfig",
    "get_model_config",
    "FeatureValidationError",
    "ModelArtifactError",
    "ModelUnavailableError",
    "SeverityPredictor",
    "get_predictor",
]
