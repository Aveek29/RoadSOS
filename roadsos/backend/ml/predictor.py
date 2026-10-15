"""High-level severity prediction service.

This is the single seam through which the application talks to the model. It
composes the :class:`~ml.feature_schema.FeatureSchema` (validation + encoding)
with the :class:`~ml.model_loader.ModelLoader` (artifact lifecycle) and returns a
structured :class:`~ml.feature_schema.PredictionResult`.

Design guarantees
-----------------
* The model is loaded at most once per process (delegated to the loader).
* Inputs are validated and encoded exactly as the training notebook did.
* Failures raise typed exceptions; they never crash unrelated endpoints.
* Calling code must treat predictions as *advisory only* — they are never used
  to gate crash detection or emergency escalation.
"""
from __future__ import annotations

import logging
import math
import threading
import time
from typing import Any, Dict, List, Optional

from ml.feature_schema import FeatureSchema, PredictionResult
from ml.model_loader import ModelLoader, get_model_loader

logger = logging.getLogger("RoadSoS.ML.Predictor")


class SeverityPredictor:
    def __init__(
        self,
        loader: Optional[ModelLoader] = None,
        schema: Optional[FeatureSchema] = None,
    ):
        self._loader = loader or get_model_loader()
        self._schema = schema
        self._schema_lock = threading.Lock()

    # -- schema ------------------------------------------------------------
    @property
    def schema(self) -> FeatureSchema:
        if self._schema is None:
            with self._schema_lock:
                if self._schema is None:
                    self._schema = FeatureSchema.from_path(
                        self._loader.config.schema_path
                    )
        return self._schema

    @property
    def loader(self) -> ModelLoader:
        return self._loader

    # -- prediction --------------------------------------------------------
    def _build_dataframe(self, vector: List[float]):
        """Create a DataFrame with the exact training column names.

        Using a DataFrame (rather than a bare ndarray) avoids scikit-learn's
        "X does not have valid feature names" warning and guarantees the
        ordering is checked by the library itself.
        """
        import pandas as pd

        schema = self.schema
        return pd.DataFrame([vector], columns=schema.feature_order)

    def predict(self, raw_features: Any) -> PredictionResult:
        """Validate, encode and run inference for one incident scenario."""
        schema = self.schema
        normalised = schema.validate(raw_features)
        vector = schema.encode(normalised)

        model = self._loader.model  # may raise ModelUnavailableError
        frame = self._build_dataframe(vector)

        t0 = time.time()
        predicted_index = int(model.predict(frame)[0])
        proba_row = model.predict_proba(frame)[0]
        latency_ms = round((time.time() - t0) * 1000, 2)
        logger.info(
            "Severity inference: %s (%.1fms)",
            schema.class_labels.get(predicted_index, predicted_index),
            latency_ms,
        )

        probabilities = self._format_probabilities(proba_row, schema)
        severity = schema.class_labels.get(predicted_index)
        if severity is None:
            raise ValueError(
                f"Model returned class index {predicted_index} which is not in "
                "the documented class mapping"
            )

        return PredictionResult(
            severity=severity,
            probabilities=probabilities,
            class_order=list(schema.class_order),
            model_version=self._loader.config.revision,
            predicted_index=predicted_index,
            latency_ms=latency_ms,
        )

    @staticmethod
    def _format_probabilities(proba_row, schema: FeatureSchema) -> Dict[str, float]:
        """Map the probability vector onto class names, normalised to sum to 1.

        The values are the model's raw vote distribution over the forest. They
        are *not* calibrated probabilities and must not be presented as such.
        """
        values = [float(p) for p in proba_row]
        total = math.fsum(values)
        if total <= 0:
            raise ValueError("Model returned an empty/degenerate probability row")
        out: Dict[str, float] = {}
        for idx, name in schema.class_labels.items():
            if idx < len(values):
                out[name] = round(values[idx] / total, 6)
        return out

    # -- health ------------------------------------------------------------
    def ensure_health(self) -> Dict[str, Any]:
        """Force a load attempt (if needed) then return :meth:`health`."""
        self._loader.ensure_loaded()
        return self.health()

    def health(self) -> Dict[str, Any]:
        status = self._loader.status()
        cfg = self._loader.config
        return {
            "available": status.state == "loaded",
            "state": status.state,
            "reason": status.reason,
            "loadSeconds": status.load_seconds,
            "artifactSizeBytes": status.artifact_size_bytes,
            "sha256Verified": status.sha256_verified,
            "nFeaturesIn": status.n_features_in_,
            "model": cfg.describe(),
            "schemaVersion": self.schema._raw.get("schema_version"),
            "nFeaturesSchema": self.schema.n_features,
            "classOrder": list(self.schema.class_order),
        }


_predictor_singleton: Optional[SeverityPredictor] = None
_lock = threading.Lock()


def get_predictor() -> SeverityPredictor:
    global _predictor_singleton
    if _predictor_singleton is None:
        with _lock:
            if _predictor_singleton is None:
                _predictor_singleton = SeverityPredictor()
    return _predictor_singleton


def reset_predictor() -> None:
    global _predictor_singleton
    with _lock:
        _predictor_singleton = None
