import sys
from pathlib import Path

# main.py is one folder up and not a package; this works however pytest is started.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import main  # noqa: E402


def test_reports_ok_and_environment(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "dev")
    assert main.smoke_test(None) == {"status": "ok", "environment": "dev"}


def test_environment_defaults_to_unknown(monkeypatch):
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    assert main.smoke_test(None)["environment"] == "unknown"
