"""Configuration loader for ibmi-ops-suite.

Reads environment variables and optional `.env` files. Profiles are supported
via `--profile` which looks for `.env.<profile>`.
"""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from pathlib import Path
from typing import Dict


@dataclass
class Config:
    """Runtime configuration for IBM i connections."""

    host: str
    user: str
    password: str | None = None
    database: str | None = None


def _parse_env_file(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    if not path.exists():
        return data
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        # Support quoted values per .env conventions
        parsed = shlex.split(value, posix=True)
        data[key.strip()] = parsed[0] if parsed else ""
    return data


def load_config(profile: str | None = None) -> Config:
    """Load configuration from environment and optional profile."""

    env_file = Path(f".env.{profile}") if profile else Path(".env")
    file_values = _parse_env_file(env_file)

    host = os.getenv("IBMI_HOST", file_values.get("IBMI_HOST", ""))
    user = os.getenv("IBMI_USER", file_values.get("IBMI_USER", ""))
    password = os.getenv("IBMI_PASSWORD", file_values.get("IBMI_PASSWORD"))
    database = os.getenv("IBMI_DATABASE", file_values.get("IBMI_DATABASE"))
    return Config(host=host, user=user, password=password, database=database)

