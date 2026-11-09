from tests.conftest import register


def test_register_login_and_me(client):
    headers = register(client)
    me = client.get("/me", headers=headers).json()
    assert me["email"] == "ana@example.com"
    assert me["subscription_status"] == "trial"
    assert me["is_premium"] is True  # período de teste

    resp = client.post("/auth/login", json={"email": "ANA@example.com", "password": "senha-segura-1"})
    assert resp.status_code == 200

    resp = client.post("/auth/login", json={"email": "ana@example.com", "password": "errada123"})
    assert resp.status_code == 401


def test_duplicate_email(client):
    register(client)
    resp = client.post("/auth/register", json={"name": "Ana", "email": "ana@example.com", "password": "outra-senha"})
    assert resp.status_code == 409


def test_requires_token(client):
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer lixo"}).status_code == 401


def test_default_categories_created(client, auth):
    names = {c["name"] for c in client.get("/categories", headers=auth).json()}
    assert {"Alimentação", "Transporte", "Salário"} <= names


def test_users_cannot_see_each_other(client, auth, account):
    other = register(client, email="bia@example.com")
    assert client.get("/accounts", headers=other).json() == []
    resp = client.patch(f"/accounts/{account['id']}", json={"name": "x"}, headers=other)
    assert resp.status_code == 404


def test_delete_account_removes_data(client, auth, account):
    assert client.delete("/me", headers=auth).status_code == 204
    assert client.get("/me", headers=auth).status_code == 401


def test_update_profile_and_password(client, auth):
    resp = client.patch("/me", json={"monthly_income": "5000.00"}, headers=auth)
    assert resp.json()["monthly_income"] == "5000.00"
    resp = client.post("/me/password", json={"current_password": "errada", "new_password": "nova-senha-1"}, headers=auth)
    assert resp.status_code == 400
    resp = client.post("/me/password", json={"current_password": "senha-segura-1", "new_password": "nova-senha-1"}, headers=auth)
    assert resp.status_code == 204
