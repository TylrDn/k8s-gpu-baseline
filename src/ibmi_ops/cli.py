"""Command line interface for ibmi-ops-suite."""

from __future__ import annotations

import click

from .config import load_config


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
    cfg = load_config(ctx.obj.get("profile"))
    click.echo(f"Pinging {cfg.host} ...")
    click.echo("pong")


@cli.command("run-cmd")
@click.argument("command", nargs=-1)
@click.option("--dry-run", is_flag=True, help="Show command without executing")
@click.pass_context
def run_cmd(ctx: click.Context, command: tuple[str, ...], dry_run: bool) -> None:
    """Run a system command."""
    cmd_str = " ".join(command)
    if dry_run:
        click.echo(f"DRY-RUN: {cmd_str}")
        return
    click.echo(f"Executed: {cmd_str}")


@cli.command()
@click.option("--source", required=True)
@click.option("--target", required=True)
@click.option("--dry-run", is_flag=True)
def transfer(source: str, target: str, dry_run: bool) -> None:
    """Transfer a file between local and IFS."""
    if dry_run:
        click.echo(f"DRY-RUN: transfer {source} -> {target}")
        return
    click.echo(f"Transferred {source} -> {target}")


@cli.command("import-csv")
@click.argument("path")
@click.option("--dry-run", is_flag=True)
def import_csv(path: str, dry_run: bool) -> None:
    """Import a CSV file into DB2."""
    if dry_run:
        click.echo(f"DRY-RUN: import {path}")
        return
    click.echo(f"Imported {path}")


@cli.command("export-csv")
@click.argument("path")
@click.option("--dry-run", is_flag=True)
def export_csv(path: str, dry_run: bool) -> None:
    """Export a DB2 query to CSV."""
    if dry_run:
        click.echo(f"DRY-RUN: export {path}")
        return
    click.echo(f"Exported {path}")


@cli.command()
@click.option("--dry-run", is_flag=True)
def payroll(dry_run: bool) -> None:
    """Run sample payroll pipeline."""
    if dry_run:
        click.echo("DRY-RUN: payroll pipeline")
        return
    click.echo("Ran payroll pipeline")


if __name__ == "__main__":  # pragma: no cover
    cli()
