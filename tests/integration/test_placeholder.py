import os

import pytest

pytestmark = pytest.mark.skipif(
    os.getenv("INTEGRATION_TESTS") != "1",
    reason="integration tests disabled",
)


def test_placeholder() -> None:
    assert True
