import os

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["ENVIRONMENT"] = "test"
os.environ["OPEN_FINANCE_PROVIDER"] = "mock"
os.environ["OPEN_FINANCE_WEBHOOK_SECRET"] = "segredo-teste"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import db as db_module
from app.db import Base, get_db
from app.main import app


@pytest.fixture()
def session_factory(monkeypatch):
    url = os.environ.get("TEST_DATABASE_URL")  # ex.: Postgres local para testar de verdade
    if url:
        engine = create_engine(url)
        Base.metadata.drop_all(engine)
    else:
        engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    monkeypatch.setattr(db_module, "SessionLocal", factory)
    import app.routers.open_finance as of

    monkeypatch.setattr(of, "SessionLocal", factory)
    yield factory
    if url:
        Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture()
def client(session_factory):
    def override():
        db = session_factory()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def register(client, email="ana@example.com", password="senha-segura-1"):
    resp = client.post("/auth/register", json={"name": "Ana", "email": email, "password": password})
    assert resp.status_code == 201, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


@pytest.fixture()
def auth(client):
    return register(client)


@pytest.fixture()
def account(client, auth):
    resp = client.post("/accounts", json={"name": "Nubank", "initial_balance": "1000.00"}, headers=auth)
    assert resp.status_code == 201
    return resp.json()


def category_id(client, auth, name):
    cats = client.get("/categories", headers=auth).json()
    return next(c["id"] for c in cats if c["name"] == name)
