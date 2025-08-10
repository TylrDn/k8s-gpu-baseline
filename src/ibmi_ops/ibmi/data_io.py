"""Data transfer helpers."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable


def transfer_file(source: Path, target: Path, chunk_size: int = 1024 * 1024) -> None:
    """Copy a file using chunked reads to avoid memory spikes."""
    with source.open("rb") as src, target.open("wb") as dst:
        while True:
            chunk = src.read(chunk_size)
            if not chunk:
                break
            dst.write(chunk)


def import_csv(path: Path) -> int:
    """Placeholder CSV import routine.

    Returns number of rows processed.
    """
    # Real implementation would stream into DB2
    lines = path.read_text().splitlines()
    return len(lines)


def export_csv(path: Path, rows: Iterable[Iterable[str]]) -> None:
    """Write rows to a CSV file."""
    with path.open("w", newline="") as fh:
        for row in rows:
            fh.write(",".join(row) + "\n")
