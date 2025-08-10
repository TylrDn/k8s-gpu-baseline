"""Helpers for QSYS library management."""

from __future__ import annotations

from typing import List

_library_list: List[str] = []


def add_library(name: str) -> None:
    """Add a library to the current list."""
    if name not in _library_list:
        _library_list.append(name)


def get_libraries() -> List[str]:
    """Return the current library list."""
    return list(_library_list)
