#!/usr/bin/env python
"""Verify the integrity of a cached model artifact.

Checks, in order:
  1. the file exists,
  2. its size matches the published artifact exactly,
  3. its SHA-256 matches the digest observed when this integration was built.

Optionally (``--load``) it additionally deserialises the model and sanity-checks
its structure against ``feature_schema.json``. Loading requires ~8 GB RAM and a
few seconds, so it is opt-in.

Exit codes:
    0  verification passed
    1  verification failed

Usage
-----
    python scripts/verify_model.py
    python scripts/verify_model.py --path /srv/ml/road_accident_model.pkl
    python scripts/verify_model.py --load
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
import time

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BACKEND_DIR)

from ml.config import (  # noqa: E402
    DEFAULT_SHA256,
    DEFAULT_SIZE_BYTES,
    reload_model_config,
)

_READ_CHUNK = 1024 * 1024


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(_READ_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--path", default=None, help="artifact path (default: auto-resolve)")
    ap.add_argument("--load", action="store_true", help="also load and sanity-check")
    args = ap.parse_args()

    cfg = reload_model_config()
    path = args.path or cfg.artifact_path

    print(f"Verifying: {path}")
    if not os.path.isfile(path):
        print("FAIL: artifact not found.")
        print("      Run: python scripts/download_model.py")
        return 1

    actual_size = os.path.getsize(path)
    print(f"  size expected {cfg.expected_size} / actual {actual_size}")
    if actual_size != cfg.expected_size:
        print("FAIL: size mismatch (incomplete or corrupted download).")
        return 1

    print("  computing sha256 ...")
    actual_sha = sha256_file(path)
    expected = cfg.expected_sha256 or DEFAULT_SHA256
    print(f"  sha256 expected {expected}")
    print(f"  sha256 actual   {actual_sha}")
    if actual_sha.upper() != expected.upper():
        print("FAIL: SHA-256 mismatch — artifact does not match verified source.")
        return 1
    print("PASS: size and SHA-256 match the verified source artifact.")

    if args.load:
        print("Loading model to verify structure ...")
        t0 = time.time()
        import joblib

        model = joblib.load(path)
        elapsed = time.time() - t0
        from ml.feature_schema import FeatureSchema

        schema = FeatureSchema.from_path(cfg.schema_path)
        print(f"  load time       = {elapsed:.2f}s")
        print(f"  type            = {type(model).__name__}")
        print(f"  n_features_in_  = {getattr(model, 'n_features_in_', None)}")
        print(f"  classes_        = {list(getattr(model, 'classes_', []))}")
        print(f"  n_estimators    = {getattr(model, 'n_estimators', None)}")
        ok = (
            getattr(model, "n_features_in_", None) == schema.n_features
            and list(getattr(model, "classes_", [])) == [0, 1, 2]
        )
        if not ok:
            print("FAIL: model structure does not match feature_schema.json.")
            return 1
        print("PASS: model loads and matches the published schema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
