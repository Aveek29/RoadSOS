"""Thread-safe, lazy, single-load model artifact management.

The trained Random Forest is ≈1.97 GB on disk and takes several seconds to
deserialise, so it must be loaded **once per process** and reused. This module
owns that lifecycle and never raises on import — loading failures are captured
and surfaced through :meth:`ModelLoader.status` so that unrelated application
functionality (crash detection, incident creation, dispatch) keeps working.

SECURITY: ``joblib``/``pickle`` deserialisation executes arbitrary code. Only
artifacts from the verified Hugging Face revision are loaded, and an integrity
check (size + SHA-256) is enforced before deserialisation whenever a checksum is
configured.
"""
from __future__ import annotations

import hashlib
import logging
import os
import threading
import time
from dataclasses import dataclass
from typing import Any, Optional

from ml.config import ModelConfig, get_model_config
from ml.errors import ModelArtifactError, ModelUnavailableError

logger = logging.getLogger("RoadSoS.ML.Loader")

_READ_CHUNK = 1024 * 1024


@dataclass
class ModelStatus:
    available: bool
    loaded: bool
    state: str  # "not_loaded" | "loading" | "loaded" | "unavailable"
    reason: Optional[str] = None
    loaded_at: Optional[float] = None
    load_seconds: Optional[float] = None
    artifact_size_bytes: Optional[int] = None
    sha256_verified: Optional[bool] = None
    n_features_in_: Optional[int] = None


def _sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(_READ_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


class ModelLoader:
    """Owns at most one loaded model per process."""

    def __init__(self, config: Optional[ModelConfig] = None):
        self._config = config or get_model_config()
        self._model: Any = None
        self._lock = threading.RLock()
        self._status = ModelStatus(
            available=False, loaded=False, state="not_loaded"
        )

    # -- public API --------------------------------------------------------
    @property
    def config(self) -> ModelConfig:
        return self._config

    @property
    def model(self) -> Any:
        """Return the loaded model, loading it on first access."""
        with self._lock:
            if self._status.state == "loaded":
                return self._model
            if self._status.state == "unavailable":
                raise ModelUnavailableError(
                    self._status.reason or "Model is unavailable"
                )
            self._load_locked()
            if self._model is None:
                raise ModelUnavailableError(
                    self._status.reason or "Model is unavailable"
                )
            return self._model

    def status(self) -> ModelStatus:
        with self._lock:
            return self._status

    def is_available(self) -> bool:
        with self._lock:
            return self._status.state == "loaded"

    def ensure_loaded(self) -> ModelStatus:
        """Attempt to load the model; never raises. Used at startup/health."""
        try:
            self.model  # triggers load
        except (ModelUnavailableError, ModelArtifactError):
            pass
        except Exception as exc:  # pragma: no cover - defensive
            with self._lock:
                self._status = ModelStatus(
                    available=False,
                    loaded=False,
                    state="unavailable",
                    reason=f"{type(exc).__name__}: {exc}",
                )
        return self.status()

    def reset(self) -> None:
        """Drop the loaded model (tests / hot reload)."""
        with self._lock:
            self._model = None
            self._status = ModelStatus(
                available=False, loaded=False, state="not_loaded"
            )

    # -- internals ---------------------------------------------------------
    def _verify_artifact(self, path: str) -> None:
        if not os.path.isfile(path):
            raise ModelArtifactError(f"Model artifact not found at configured path")
        size = os.path.getsize(path)
        if self._config.expected_size and size != self._config.expected_size:
            raise ModelArtifactError(
                "Model artifact size mismatch: expected "
                f"{self._config.expected_size} bytes, found {size}. "
                "The download may be incomplete or corrupted."
            )
        if self._config.expected_sha256:
            actual = _sha256_file(path)
            if actual != self._config.expected_sha256:
                raise ModelArtifactError(
                    "Model artifact SHA-256 mismatch — refusing to deserialise "
                    "an unverified artifact."
                )

    def _load_locked(self) -> None:
        self._status = ModelStatus(
            available=False, loaded=False, state="loading", reason=None
        )
        cfg = self._config
        started = time.time()
        try:
            self._verify_artifact(cfg.artifact_path)
            import joblib

            logger.info("Loading severity model from %s ...", cfg.artifact_path)
            model = joblib.load(cfg.artifact_path)

            # Structural sanity checks against the published schema.
            n_features = getattr(model, "n_features_in_", None)
            classes = list(getattr(model, "classes_", []))

            from ml.feature_schema import FeatureSchema

            schema = FeatureSchema.from_path(cfg.schema_path)
            if n_features is not None and n_features != schema.n_features:
                raise ModelArtifactError(
                    f"Model expects {n_features} features but schema defines "
                    f"{schema.n_features}"
                )
            if classes and len(classes) != len(schema.class_order):
                raise ModelArtifactError(
                    f"Model exposes {len(classes)} classes but schema defines "
                    f"{len(schema.class_order)}"
                )

            elapsed = time.time() - started
            self._model = model
            self._status = ModelStatus(
                available=True,
                loaded=True,
                state="loaded",
                loaded_at=time.time(),
                load_seconds=round(elapsed, 3),
                artifact_size_bytes=os.path.getsize(cfg.artifact_path),
                sha256_verified=bool(cfg.expected_sha256),
                n_features_in_=n_features,
            )
            logger.info(
                "Severity model loaded in %.2fs (n_features=%s, classes=%s)",
                elapsed,
                n_features,
                classes,
            )
        except Exception as exc:  # noqa: BLE001 - we deliberately capture all
            reason = f"{type(exc).__name__}: {exc}"
            logger.error("Severity model unavailable: %s", reason)
            self._model = None
            self._status = ModelStatus(
                available=False,
                loaded=False,
                state="unavailable",
                reason=reason,
            )


_loader_singleton: Optional[ModelLoader] = None
_singleton_lock = threading.Lock()


def get_model_loader() -> ModelLoader:
    global _loader_singleton
    if _loader_singleton is None:
        with _singleton_lock:
            if _loader_singleton is None:
                _loader_singleton = ModelLoader()
    return _loader_singleton


def reset_model_loader() -> None:
    """Reset the process-wide loader (tests)."""
    global _loader_singleton
    with _singleton_lock:
        _loader_singleton = None
