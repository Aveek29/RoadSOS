"""Tests for the dependency-free ``.env`` loader in ``backend/app.py``.

The loader runs at import time (before the prediction blueprint reads its
configuration), so these tests exercise the function directly with temp files
and assert the two safety rules:

1. values from the file are applied when the variable is not already set;
2. values already present in the environment are **never** overwritten.
"""
from __future__ import annotations

import os

from app import _load_env_file

# Unique names so a stray .env in the working directory cannot collide.
K1 = "ROADSOS_TEST_FROM_FILE"
K2 = "ROADSOS_TEST_PRESERVED"
K3 = "ROADSOS_TEST_QUOTED"


def _cleanup(*keys: str) -> None:
    for key in keys:
        os.environ.pop(key, None)


def test_loads_values_and_ignores_comments_and_blank_lines(tmp_path):
    env_file = tmp_path / "env"
    env_file.write_text(
        "# a comment\n"
        "\n"
        f"{K1}=from-file\n"
        "NOT A PAIR LINE\n",
        encoding="utf-8",
    )
    _cleanup(K1)
    try:
        _load_env_file(str(env_file))
        assert os.environ[K1] == "from-file"
        assert "NOT A PAIR LINE" not in os.environ
    finally:
        _cleanup(K1)


def test_existing_environment_always_wins(tmp_path):
    env_file = tmp_path / "env"
    env_file.write_text(f"{K2}=from-file\n", encoding="utf-8")
    os.environ[K2] = "from-shell"
    try:
        _load_env_file(str(env_file))
        assert os.environ[K2] == "from-shell"
    finally:
        _cleanup(K2)


def test_strips_matching_quotes(tmp_path):
    env_file = tmp_path / "env"
    env_file.write_text(f'{K3}="with spaces"\n', encoding="utf-8")
    _cleanup(K3)
    try:
        _load_env_file(str(env_file))
        assert os.environ[K3] == "with spaces"
    finally:
        _cleanup(K3)


def test_missing_file_is_a_silent_no_op(tmp_path):
    _load_env_file(str(tmp_path / "does-not-exist.env"))  # must not raise
