from datetime import datetime, timedelta, timezone

from app.models import User


def expire_trial(session_factory):
    with session_factory() as db:
        user = db.query(User).first()
        user.trial_ends_at = datetime.now(timezone.utc) - timedelta(days=1)
        db.commit()


def test_open_finance_sync_with_mock(client, auth):
    token = client.post("/open-finance/connect-token", headers=auth).json()
    assert token["provider"] == "mock"

    resp = client.post("/open-finance/connections", json={"external_id": "item-1"}, headers=auth)
    assert resp.status_code == 201, resp.text
    result = resp.json()
    assert result["accounts"] == 2 and result["imported"] > 0

    # Sincronizar de novo não duplica.
    conn_id = client.get("/open-finance/connections", headers=auth).json()[0]["id"]
    again = client.post(f"/open-finance/connections/{conn_id}/sync", headers=auth).json()
    assert again["imported"] == 0 and again["skipped"] > 0
    assert client.get("/transactions", headers=auth).json()["total"] == result["imported"]

    txs = client.get("/transactions", headers=auth).json()["items"]
    assert any(t["source"] == "open_finance" and t["category"]["name"] == "Alimentação" for t in txs)
    accounts = client.get("/accounts", headers=auth).json()
    assert {a["balance"] for a in accounts} == {"2500.00", "-830.15"}


def test_webhook_requires_secret(client, auth):
    client.post("/open-finance/connections", json={"external_id": "item-2"}, headers=auth)
    assert client.post("/open-finance/webhook", json={"itemId": "item-2"}).status_code == 401
    resp = client.post("/open-finance/webhook", json={"itemId": "item-2"},
                       headers={"X-Webhook-Secret": "segredo-teste"})
    assert resp.status_code == 202 and resp.json() == {"queued": True}


def test_premium_features_blocked_after_trial(client, auth, session_factory):
    expire_trial(session_factory)
    assert client.get("/me", headers=auth).json()["is_premium"] is False
    assert client.post("/open-finance/connect-token", headers=auth).status_code == 402
    assert client.get("/forecast", params={"months": 3}, headers=auth).status_code == 402
    assert client.get("/forecast", headers=auth).status_code == 200  # mês atual é grátis


def test_purchase_activates_premium(client, auth, session_factory):
    expire_trial(session_factory)
    assert len(client.get("/subscription/plans").json()) >= 1
    bad = client.post("/subscription/purchase", json={"platform": "mock", "product_id": "premium_monthly",
                                                      "purchase_token": "falso"}, headers=auth)
    assert bad.status_code == 400
    ok = client.post("/subscription/purchase", json={"platform": "mock", "product_id": "premium_monthly",
                                                     "purchase_token": "mock-123"}, headers=auth)
    assert ok.json()["is_premium"] is True and ok.json()["status"] == "active"

    canceled = client.post("/subscription/cancel", headers=auth).json()
    assert canceled["status"] == "canceled" and canceled["is_premium"] is True
    assert client.get("/forecast", params={"months": 3}, headers=auth).status_code == 200
