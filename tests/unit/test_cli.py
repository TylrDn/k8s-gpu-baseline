from click.testing import CliRunner

from ibmi_ops.cli import cli


def test_ping() -> None:
    runner = CliRunner()
    result = runner.invoke(cli, ["ping"])
    assert result.exit_code == 0
    assert "pong" in result.output
