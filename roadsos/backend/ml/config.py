"""Configuration for the accident-severity ML model.

All values can be overridden through environment variables so that the same
code runs in local development, CI and production without edits. The model
artifact (≈1.97 GB) is *never* committed to git; it is downloaded from the
verified Hugging Face revision by ``scripts/download_model.py``.

Environment variables
---------------------
MODEL_PATH            Explicit path to the ``.pkl`` artifact (highest priority).
MODEL_CACHE_DIR       Directory searched for the artifact if MODEL_PATH is unset.
MODEL_FILENAME        Artifact filename (default: road_accident_model.pkl).
MODEL_HF_REPO         Hugging Face repository id.
MODEL_HF_REVISION     Pinned revision / commit sha.
MODEL_SHA256          Expected SHA-256 of the artifact (empty disables check).
MODEL_SCHEMA_PATH     Path to feature_schema.json.
MODEL_HEALTHCHECK     "1" to load the model eagerly at import/startup.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache

# --- immutable facts about the published model ------------------------------
DEFAULT_HF_REPO = "hayamwahdan/road-accident-severity-prediction"
# Pinned to the revision observed when this integration was built.
DEFAULT_HF_REVISION = "c4a7daf40b05e506c3c00aca7c8ab00bc00db53c"
DEFAULT_FILENAME = "road_accident_model.pkl"
DEFAULT_SIZE_BYTES = 1965071297
DEFAULT_SHA256 = "B9E5BE7E6A24CEE9746C743F630E41FADE629E5A38A3DC9FE1017508FE7E98B2"

_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


@dataclass(frozen=True)
class ModelConfig:
    """Resolved, immutable configuration for the severity model."""

    repo_id: str
    revision: str
    filename: str
    expected_size: int
    expected_sha256: str
    artifact_path: str
    schema_path: str
    healthcheck_eager: bool
    cache_candidates: tuple = field(default=())

    def describe(self) -> dict:
        """Client-safe model metadata (no filesystem paths, no secrets)."""
        return {
            "name": "road-accident-severity-prediction",
            "framework": "scikit-learn RandomForestClassifier",
            "repo": self.repo_id,
            "revision": self.revision,
            "artifact_filename": self.filename,
            "expected_size_bytes": self.expected_size,
            "license": "MIT",
        }


def _candidate_paths(filename: str) -> list:
    cands = []
    explicit = os.environ.get("MODEL_PATH")
    if explicit:
        cands.append(explicit)
    cache_dir = os.environ.get("MODEL_CACHE_DIR")
    if cache_dir:
        cands.append(os.path.join(cache_dir, filename))
        cands.append(os.path.join(cache_dir, "models", filename))
    # Conventional locations inside / around the backend.
    cands.append(os.path.join(_BACKEND_DIR, "models", filename))
    cands.append(os.path.join(_BACKEND_DIR, filename))
    cands.append(os.path.join(os.path.dirname(_BACKEND_DIR), "models", filename))
    # De-duplicate while preserving priority order.
    seen, out = set(), []
    for c in cands:
        norm = os.path.normcase(os.path.abspath(c))
        if norm not in seen:
            seen.add(norm)
            out.append(os.path.abspath(c))
    return out


@lru_cache(maxsize=1)
def get_model_config() -> ModelConfig:
    filename = os.environ.get("MODEL_FILENAME", DEFAULT_FILENAME)
    sha = os.environ.get("MODEL_SHA256", DEFAULT_SHA256)
    candidates = _candidate_paths(filename)
    artifact_path = candidates[0]
    for c in candidates:
        if os.path.exists(c):
            artifact_path = c
            break

    schema_path = os.environ.get("MODEL_SCHEMA_PATH") or os.path.join(
        _BACKEND_DIR, "ml", "artifacts", "feature_schema.json"
    )

    return ModelConfig(
        repo_id=os.environ.get("MODEL_HF_REPO", DEFAULT_HF_REPO),
        revision=os.environ.get("MODEL_HF_REVISION", DEFAULT_HF_REVISION),
        filename=filename,
        expected_size=int(os.environ.get("MODEL_EXPECTED_SIZE", DEFAULT_SIZE_BYTES)),
        expected_sha256=(sha or "").strip().upper(),
        artifact_path=artifact_path,
        schema_path=os.path.abspath(schema_path),
        healthcheck_eager=_env_bool("MODEL_HEALTHCHECK", True),
        cache_candidates=tuple(candidates),
    )


def reload_model_config() -> ModelConfig:
    """Clear the cache (used by tests that mutate the environment)."""
    get_model_config.cache_clear()
    return get_model_config()
