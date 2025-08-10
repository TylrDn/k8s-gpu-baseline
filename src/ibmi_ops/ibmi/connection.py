"""Connection utilities for IBM i systems."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class DB2Connection:
    """DB2 over ODBC or JDBC."""

    dsn: str
    user: str
    password: str
    use_jdbc: bool = False
    kwargs: Optional[dict[str, Any]] = None
    conn: Any | None = None

    def connect(self) -> None:
        """Establish the database connection."""
        try:
            if self.use_jdbc:
                import jaydebeapi  # type: ignore
                self.conn = jaydebeapi.connect(self.dsn, [self.user, self.password])
            else:
                import pyodbc  # type: ignore
                self.conn = pyodbc.connect(
                    self.dsn, user=self.user, password=self.password
                )  # type: ignore[arg-type]
        except Exception as exc:  # pragma: no cover - network
            raise RuntimeError("DB2 connection failed") from exc


@dataclass
class SSHConnection:
    """SSH/SFTP connection using paramiko."""

    host: str
    user: str
    password: str | None = None
    port: int = 22
    client: Any | None = None

    def connect(self) -> None:
        try:
            import paramiko  # type: ignore
            self.client = paramiko.SSHClient()
            self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.client.connect(
                self.host, username=self.user, password=self.password, port=self.port
            )
        except Exception as exc:  # pragma: no cover - network
            raise RuntimeError("SSH connection failed") from exc
