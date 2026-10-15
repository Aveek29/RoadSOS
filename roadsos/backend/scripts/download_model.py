#!/usr/bin/env python
"""Download and cache the RoadSOS accident-severity model artifact.

The trained Random Forest (~1.97 GB) is too large to commit to git. This
script fetches it once from its original publisher (Hugging Face), pinned to a
specific revision, and verifies its integrity before considering it usable.

Behaviour
---------
* Pins ``MODEL_HF_REVISION`` (default: the revision this integration was built
  against) so the bytes you verify today are the bytes you serve later.
* Skips work if a valid copy is already cached (no re-downloading).
* Resumes interrupted downloads (delegates to ``huggingface_hub``).
* Retries transient failures.
* Verifies **exact size** and **SHA-256** after download; fails loudly otherwise.
* Never disables TLS verification; never requires credentials for this public
  model (pass ``HF_TOKEN`` only if the artifact ever becomes gated).
* Exits non-zero on any failure.

Usage
-----
    python scripts/download_model.py                 # -> models/ in repo root
    python scripts/download_model.py --dest /srv/ml
    python scripts/download_model.py --force         # re-download even if cached
    python scripts/download_model.py --skip-checksum # speed, not recommended
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
import time

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(BACKEND_DIR)

# Import config for the pinned, verified facts about the artifact.
sys.path.insert(0, BACKEND_DIR)
from ml.config import (  # noqa: E402
    DEFAULT_FILENAME,
    DEFAULT_HF_REPO,
    DEFAULT_HF_REVISION,
    DEFAULT_SHA256,
    DEFAULT_SIZE_BYTES,
)

_READ_CHUNK = 1024 * 1024


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(_READ_CHUNK), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def verify(path: str, expected_size: int, expected_sha: str, check_sha: bool):
    if not os.path.isfile(path):
        raise SystemExit(f"ERROR: expected artifact missing: {path}")
    actual_size = os.path.getsize(path)
    if actual_size != expected_size:
        raise SystemExit(
            f"ERROR: size mismatch for {path}\n"
            f"  expected {expected_size} bytes\n"
            f"  actual   {actual_size} bytes\n"
            "The download is incomplete or corrupted. Re-run with --force."
        )
    if check_sha:
        print("Computing SHA-256 (this reads the whole file) ...")
        actual_sha = sha256_file(path)
        if actual_sha != expected_sha.upper():
            raise SystemExit(
                f"ERROR: SHA-256 mismatch for {path}\n"
                f"  expected {expected_sha}\n"
                f"  actual   {actual_sha}\n"
                "Refusing to use an unverified artifact. Re-run with --force."
            )
    return actual_size


def download(repo_id: str, revision: str, filename: str, dest_dir: str, retries: int) -> str:
    from huggingface_hub import hf_hub_download

    os.makedirs(dest_dir, exist_ok=True)
    attempt = 0
    last_err: Exception | None = None
    while attempt <= retries:
        attempt += 1
        try:
            print(f"Downloading {repo_id}@{revision}/{filename} "
                  f"(attempt {attempt}/{retries + 1}) ...")
            path = hf_hub_download(
                repo_id=repo_id,
                filename=filename,
                revision=revision,
                local_dir=dest_dir,
                resume_download=True,
            )
            return path
        except Exception as err:  # noqa: BLE001
            last_err = err
            print(f"  download attempt failed: {err}")
            if attempt <= retries:
                wait = min(30, 2 ** attempt)
                print(f"  retrying in {wait}s ...")
                time.sleep(wait)
    raise SystemExit(
        f"ERROR: could not download {filename} after {retries + 1} attempts: {last_err}"
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dest", default=os.path.join(REPO_ROOT, "models"),
                    help="directory to store the artifact (default: <repo>/models)")
    ap.add_argument("--repo", default=DEFAULT_HF_REPO)
    ap.add_argument("--revision", default=DEFAULT_HF_REVISION)
    ap.add_argument("--filename", default=DEFAULT_FILENAME)
    ap.add_argument("--force", action="store_true", help="re-download even if cached")
    ap.add_argument("--skip-checksum", action="store_true",
                    help="skip SHA-256 (faster; NOT recommended)")
    ap.add_argument("--retries", type=int, default=4)
    args = ap.parse_args()

    dest_path = os.path.join(args.dest, args.filename)

    # 1. Reuse a verified cache if present.
    if os.path.isfile(dest_path) and not args.force:
        current_size = os.path.getsize(dest_path)
        if current_size == DEFAULT_SIZE_BYTES:
            if args.skip_checksum:
                print(f"Cached artifact present and correctly sized: {dest_path}")
                return 0
            print(f"Verifying cached artifact: {dest_path}")
            try:
                verify(dest_path, DEFAULT_SIZE_BYTES, DEFAULT_SHA256, check_sha=True)
                print("Cache verified (size + SHA-256 OK). Nothing to do.")
                return 0
            except SystemExit as err:
                print(str(err))
                print("Discarding bad cache and re-downloading ...")
        else:
            print(
                f"Cached file has wrong size ({current_size} != {DEFAULT_SIZE_BYTES}); "
                "re-downloading."
            )

    # 2. Download (resumable, retrying, TLS verified by huggingface_hub).
    path = download(args.repo, args.revision, args.filename, args.dest, args.retries)

    # 3. Verify.
    size = verify(path, DEFAULT_SIZE_BYTES, DEFAULT_SHA256, check_sha=not args.skip_checksum)
    print(f"OK: {path}")
    print(f"    size   = {size} bytes")
    if not args.skip_checksum:
        print(f"    sha256 = {DEFAULT_SHA256}")
    print(f"    source = https://huggingface.co/{args.repo} (revision {args.revision})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
