"""Run IBM i system commands."""

from __future__ import annotations

import subprocess
from typing import Tuple


def run_command(command: str) -> Tuple[int, str, str]:
    """Execute a system command and capture output."""
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr
