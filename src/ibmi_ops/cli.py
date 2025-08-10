"""Command line interface for ibmi-ops-suite."""

from __future__ import annotations

import shlex
from pathlib import Path

import click

from .config import load_config
from .ibmi import commands as ibmi_commands
from .ibmi import data_io
from .ibmi.connection import DB2Connection, SSHConnection
from .pipelines import payroll as payroll_pipeline


@click.group()
@click.option("--profile", default=None, help="Configuration profile")
@click.option("--verbose", is_flag=True, help="Verbose output")
@click.pass_context
def cli(ctx: click.Context, profile: str | None, verbose: bool) -> None:
    """Base command group."""
    ctx.obj = {"profile": profile, "verbose": verbose}


@cli.command()
@click.pass_context
def ping(ctx: click.Context) -> None:
    """Test connectivity to the IBM i host."""
    profile = ctx.obj.get("profile")
    verbose = ctx.obj.get("verbose", False)
    cfg = load_config(profile)
    if verbose:
        click.echo(f"Pinging {cfg.host} ...")
    if cfg.host and cfg.user:
        conn = SSHConnection(host=cfg.host, user=cfg.user, password=cfg.password or "")
        try:
            conn.connect()
        except RuntimeError as exc:
            raise click.ClickException(str(exc)) from exc
    click.echo("pong")


@cli.command("run-cmd")
@click.argument("command", nargs=-1)
@click.option("--dry-run", is_flag=True, help="Show command without executing")
@click.pass_context
def run_cmd(ctx: click.Context, command: tuple[str, ...], dry_run: bool) -> None:
    """Run a system command."""
    verbose = ctx.obj.get("verbose", False)
    load_config(ctx.obj.get("profile"))
    cmd_list = list(command)
    cmd_str = " ".join(shlex.quote(c) for c in cmd_list)
    if dry_run:
        click.echo(f"DRY-RUN: {cmd_str}")
        return
    rc, out, err = ibmi_commands.run_command(cmd_list, verbose=verbose)
    if out:
        click.echo(out)
    if err:
        click.echo(err, err=True)
    if verbose:
        click.echo(f"Return code: {rc}")


@cli.command()
@click.option("--source", required=True)
@click.option("--target", required=True)
@click.option("--dry-run", is_flag=True)
@click.pass_context
def transfer(ctx: click.Context, source: str, target: str, dry_run: bool) -> None:
    """Transfer a file between local system and IFS."""
    verbose = ctx.obj.get("verbose", False)
    load_config(ctx.obj.get("profile"))
    if dry_run:
        click.echo(f"DRY-RUN: transfer {source} -> {target}")
        return
    data_io.transfer_file(Path(source), Path(target))
    if verbose:
        click.echo(f"Transferred {source} -> {target}")
    else:
        click.echo("Transfer complete")


@cli.command("import-csv")
@click.argument("path")
@click.option("--dry-run", is_flag=True)
@click.pass_context
def import_csv(ctx: click.Context, path: str, dry_run: bool) -> None:
    """Import a CSV file into DB2."""
    profile = ctx.obj.get("profile")
    verbose = ctx.obj.get("verbose", False)
    cfg = load_config(profile)
    if dry_run:
        click.echo(f"DRY-RUN: import {path}")
        return
    if cfg.database and cfg.user:
        conn = DB2Connection(
            dsn=cfg.database,
            user=cfg.user,
            password=cfg.password or "",
        )
        conn.connect()
    rows = data_io.import_csv(Path(path))
    if verbose:
        click.echo(f"Imported {rows} rows from {path}")
    else:
        click.echo(f"Imported {path}")


@cli.command("export-csv")
@click.argument("path")
@click.option("--dry-run", is_flag=True)
@click.pass_context
def export_csv(ctx: click.Context, path: str, dry_run: bool) -> None:
    """Export a DB2 query to CSV."""
    profile = ctx.obj.get("profile")
    verbose = ctx.obj.get("verbose", False)
    cfg = load_config(profile)
    if dry_run:
        click.echo(f"DRY-RUN: export {path}")
        return
    if cfg.database and cfg.user:
        conn = DB2Connection(
            dsn=cfg.database,
            user=cfg.user,
            password=cfg.password or "",
        )
        conn.connect()
    sample_rows = [["id", "value"], ["1", "sample"]]
    data_io.export_csv(Path(path), sample_rows)
    if verbose:
        click.echo(f"Exported {len(sample_rows) - 1} rows to {path}")
    else:
        click.echo(f"Exported {path}")


@cli.command()
@click.option("--dry-run", is_flag=True)
@click.pass_context
def payroll(ctx: click.Context, dry_run: bool) -> None:
    """Run sample payroll pipeline."""
    verbose = ctx.obj.get("verbose", False)
    load_config(ctx.obj.get("profile"))
    if dry_run:
        click.echo("DRY-RUN: payroll pipeline")
        return
    payroll_pipeline.run()
    if verbose:
        click.echo("Payroll pipeline completed")


if __name__ == "__main__":  # pragma: no cover
    cli()
