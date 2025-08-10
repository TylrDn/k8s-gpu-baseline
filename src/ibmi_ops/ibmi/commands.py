"""Run IBM i system commands."""

from __future__ import annotations

import shlex
import subprocess
from typing import Iterable, Tuple


def run_command(
    command: Iterable[str], *, verbose: bool = False
) -> Tuple[int, str, str]:
    """Execute a system command and capture output."""
    cmd_list = list(command)
    if verbose:
        print("Executing:", " ".join(shlex.quote(c) for c in cmd_list))
    result = subprocess.run(cmd_list, shell=False, capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr
