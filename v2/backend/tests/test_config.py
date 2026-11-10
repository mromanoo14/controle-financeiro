import pytest

from app.core.config import Settings


@pytest.mark.parametrize(
    ("given", "expected"),
    [
        ("postgres://u:p@host:5432/db", "postgresql+psycopg://u:p@host:5432/db"),
        ("postgresql://u:p@host/db", "postgresql+psycopg://u:p@host/db"),
        ("postgresql+psycopg://u:p@host/db", "postgresql+psycopg://u:p@host/db"),
        ("sqlite:///./dev.db", "sqlite:///./dev.db"),
    ],
)
def test_database_url_uses_psycopg(given, expected):
    assert Settings(database_url=given).database_url == expected


def test_cors_origins_from_env(monkeypatch):
    monkeypatch.setenv("CORS_ORIGINS", '["https://exemplo.github.io"]')
    assert Settings().cors_origins == ["https://exemplo.github.io"]
