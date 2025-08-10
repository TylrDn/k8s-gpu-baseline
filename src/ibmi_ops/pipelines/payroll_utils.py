"""Utilities for payroll pipeline."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


def transfer_csv(csv_path: Path) -> None:
    """Transfer a CSV file using a Windows FTP helper script.

    The helper batch file ``ftp_cl_as400.bat`` is resolved relative to this
    module. Execution only occurs on Windows platforms. ``csv_path`` must exist
    or :class:`FileNotFoundError` is raised.
    """
    bat = Path(__file__).with_name("ftp_cl_as400.bat")
    if os.name != "nt":
        return
    if not csv_path.is_file():
        raise FileNotFoundError(csv_path)
    if not bat.is_file():
        raise FileNotFoundError(bat)
    subprocess.run([str(bat), str(csv_path)], check=True)
