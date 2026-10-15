"""Feature-schema loading, validation and one-hot encoding.

The schema in ``ml/artifacts/feature_schema.json`` is generated from the model
publisher's own artifacts (``model_features.pkl`` + ``severity_encoder.pkl`` +
cleaned dataset) by ``scripts/build_feature_schema.py``. This module consumes
that schema and:

  1. validates a raw, human-friendly feature mapping, and
  2. encodes it into the *exact* 61-element one-hot vector the model expects,
     preserving the original column order and ``drop_first=True`` semantics.

Nothing here guesses a feature name, order, category or class label.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Dict, List

from ml.errors import FeatureValidationError

# Raw feature keys the API accepts (5 numeric + 9 categorical = 14 inputs).
NUMERIC_FEATURES = ["Year", "Latitude", "Longitude", "Speed_limit", "Hour"]


@dataclass(frozen=True)
class PredictionResult:
    """A single, fully-resolved prediction."""

    severity: str
    probabilities: Dict[str, float]
    class_order: List[str]
    model_version: str
    predicted_index: int
    latency_ms: float = 0.0

    def to_dict(self) -> dict:
        return {
            "severity": self.severity,
            "probabilities": self.probabilities,
            "classOrder": self.class_order,
            "predictedClassIndex": self.predicted_index,
            "modelVersion": self.model_version,
            "latencyMs": self.latency_ms,
        }


class FeatureSchema:
    """Immutable, validated representation of the model input contract."""

    def __init__(self, schema_dict: dict):
        self._raw = schema_dict
        self.feature_order: List[str] = list(schema_dict["feature_order"])
        self.n_features: int = int(schema_dict["n_features"])
        self.class_order: List[str] = list(schema_dict["class_order"])
        self.class_labels: Dict[int, str] = {
            int(k): v for k, v in schema_dict["class_labels"].items()
        }
        self.validation: Dict[str, Any] = dict(schema_dict.get("validation", {}))
        self.model_meta: Dict[str, Any] = dict(schema_dict.get("model", {}))

        self.numeric_features: List[str] = [
            f["name"] for f in schema_dict["numeric_features"]
        ]
        self.categorical: Dict[str, dict] = {
            c["name"]: c for c in schema_dict["categorical_features"]
        }

        if len(self.feature_order) != self.n_features:
            raise FeatureValidationError(
                "feature_schema.json is internally inconsistent "
                f"(n_features={self.n_features}, order={len(self.feature_order)})"
            )
        if len(self.class_labels) != len(self.class_order):
            raise FeatureValidationError("class_labels/class_order length mismatch")

    # -- constructors ------------------------------------------------------
    @classmethod
    def from_path(cls, path: str) -> "FeatureSchema":
        with open(path, "r", encoding="utf-8") as fh:
            return cls(json.load(fh))

    # -- introspection -----------------------------------------------------
    @property
    def raw_feature_names(self) -> List[str]:
        return self.numeric_features + list(self.categorical.keys())

    def allowed_values(self) -> Dict[str, List[str]]:
        return {name: list(c["values"]) for name, c in self.categorical.items()}

    def describe(self) -> dict:
        """Client-safe description used by the API (docs / 400 responses)."""
        return {
            "n_features": self.n_features,
            "featureOrder": self.feature_order,
            "numericFeatures": self.numeric_features,
            "categoricalFeatures": {
                name: {"values": c["values"], "baseline": c["baseline"]}
                for name, c in self.categorical.items()
            },
            "classOrder": self.class_order,
            "speedLimitAllowed": self.validation.get("speed_limit_allowed"),
        }

    # -- validation --------------------------------------------------------
    @staticmethod
    def _coerce_number(key: str, value: Any) -> float:
        if isinstance(value, bool):
            raise FeatureValidationError(
                f"'{key}' must be a number, not a boolean",
                details=[f"{key}: boolean is not a valid number"],
            )
        if isinstance(value, (int, float)):
            return float(value)
        if isinstance(value, str):
            try:
                return float(value.strip())
            except ValueError:
                pass
        raise FeatureValidationError(
            f"'{key}' must be a number",
            details=[f"{key}: expected a number, got {type(value).__name__}"],
        )

    def validate(self, raw: Any) -> Dict[str, Any]:
        """Validate a raw feature mapping and return a normalised copy.

        Raises :class:`FeatureValidationError` with field-scoped details on any
        problem. Unknown keys are rejected (never silently ignored) so that
        typos cannot produce a silently-wrong prediction.
        """
        if not isinstance(raw, dict):
            raise FeatureValidationError(
                "'features' must be a JSON object",
                details=["features: expected an object mapping feature -> value"],
            )

        details: List[str] = []
        normalised: Dict[str, Any] = {}

        known = set(self.raw_feature_names)
        unknown = sorted(set(raw.keys()) - known)
        for key in unknown:
            details.append(f"{key}: unknown feature")

        # Numeric features
        for name in self.numeric_features:
            if name not in raw:
                details.append(f"{name}: required numeric feature is missing")
                continue
            try:
                normalised[name] = self._coerce_number(name, raw[name])
            except FeatureValidationError as exc:
                details.extend(exc.details or [exc.message])

        # Categorical features
        for name, spec in self.categorical.items():
            if name not in raw:
                details.append(f"{name}: required categorical feature is missing")
                continue
            value = raw[name]
            if not isinstance(value, str):
                details.append(f"{name}: expected a string category")
                continue
            if value not in spec["values"]:
                details.append(
                    f"{name}: '{value}' is not an allowed category"
                )
                continue
            normalised[name] = value

        # Range / domain checks (only for values that parsed correctly)
        v = self.validation
        if "Year" in normalised:
            year = normalised["Year"]
            if not (v.get("year_min", 1900) <= year <= v.get("year_max", 2100)):
                details.append(
                    f"Year: {int(year) if year.is_integer() else year} is outside "
                    f"[{v.get('year_min')}, {v.get('year_max')}]"
                )
        if "Hour" in normalised:
            hour = normalised["Hour"]
            if not (v.get("hour_min", 0) <= hour <= v.get("hour_max", 23)):
                details.append("Hour: must be between 0 and 23")
        if "Latitude" in normalised:
            lat = normalised["Latitude"]
            if not (v.get("latitude_min", -90.0) <= lat <= v.get("latitude_max", 90.0)):
                details.append("Latitude: must be between -90 and 90")
        if "Longitude" in normalised:
            lon = normalised["Longitude"]
            if not (
                v.get("longitude_min", -180.0) <= lon <= v.get("longitude_max", 180.0)
            ):
                details.append("Longitude: must be between -180 and 180")
        if "Speed_limit" in normalised:
            allowed = set(v.get("speed_limit_allowed", []))
            if allowed and int(normalised["Speed_limit"]) not in allowed:
                details.append(
                    f"Speed_limit: must be one of {sorted(allowed)}"
                )

        if details:
            raise FeatureValidationError(
                "Invalid prediction request", details=details
            )
        return normalised

    # -- encoding ----------------------------------------------------------
    def encode(self, normalised: Dict[str, Any]) -> List[float]:
        """Encode a validated mapping into the model's 61-float vector."""
        vector = [0.0] * self.n_features
        index = {name: i for i, name in enumerate(self.feature_order)}

        for name in self.numeric_features:
            vector[index[name]] = float(normalised[name])

        for name, spec in self.categorical.items():
            value = normalised[name]
            onehot = spec["onehot"]
            if value in onehot:  # non-baseline category -> set its column to 1
                vector[index[onehot[value]]] = 1.0
            # baseline category -> leave every column in this group at 0
        return vector
