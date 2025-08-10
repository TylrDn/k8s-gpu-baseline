# ibmi-ops-suite

Automation toolkit for IBM i (AS/400) operations.

## Overview
`ibmi-ops-suite` provides Python and Java helpers for interacting with IBM i systems: running commands, transferring data, and orchestrating batch pipelines.

## Prerequisites
- IBM i host reachable over TCP/IP
- Optional connectivity: ODBC/JDBC drivers for DB2, SSH/SFTP access
- Python 3.11+

## Setup
1. Copy `.env.example` to `.env` and adjust values.
2. Install dependencies with [uv](https://github.com/astral-sh/uv):
   ```bash
   uv sync
   ```

## Local Run
Execute the CLI:
```bash
python -m ibmi_ops.cli --help
```

## CLI Usage
`ibmi-ops` exposes several subcommands:
- `ping` – validate connectivity
- `run-cmd` – execute a system command
- `transfer` – move files between local system and IFS
- `import-csv` / `export-csv` – bulk data movement
- `payroll` – sample pipeline

Each command supports `--profile` for selecting an environment and `--verbose` for extra logs. Destructive actions accept `--dry-run`.

## Testing
Run linters and tests:
```bash
ruff check .
mypy src
pytest
```

## Continuous Integration
GitHub Actions workflow runs linting, type checks, unit tests, and builds Java helpers.

## Troubleshooting
- Verify network connectivity and credentials
- Use `--verbose` to inspect underlying commands

## Glossary
- **CCSID** – Coded Character Set Identifier used by IBM i
- **IFS** – Integrated File System

## Security
Never commit real credentials. Use `.env` only for local development. Report issues via the repository's issue tracker.
