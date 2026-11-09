from datetime import date

from app.services.categorization import keyword_from_description, normalize
from tests.conftest import category_id


def add(client, auth, account, desc, amount, kind="expense", when=None, **extra):
    body = {"account_id": account["id"], "description": desc, "amount": amount, "kind": kind,
            "date": (when or date.today()).isoformat(), **extra}
    resp = client.post("/transactions", json=body, headers=auth)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_auto_categorization(client, auth, account):
    assert add(client, auth, account, "IFOOD *Pizzaria", "45.00")["category"]["name"] == "Alimentação"
    assert add(client, auth, account, "Uber *Trip", "20.00")["category"]["name"] == "Transporte"
    assert add(client, auth, account, "Farmácia São João", "12.00")["category"]["name"] == "Saúde"
    assert add(client, auth, account, "Coisa aleatória", "5.00")["category"]["name"] == "Outros"
    income = add(client, auth, account, "Salario empresa", "3000.00", kind="income")
    assert income["category"]["name"] == "Salário"


def test_word_boundary_avoids_false_positive(client, auth, account):
    # "99" sozinho não deve virar transporte; "bar" não deve casar com "barbearia".
    assert add(client, auth, account, "Loja 99 centavos", "9.90")["category"]["name"] == "Outros"
    assert add(client, auth, account, "Barbearia do Zé", "40.00")["category"]["name"] == "Outros"


def test_correction_learns_rule_and_recategorizes(client, auth, account):
    first = add(client, auth, account, "PADARIA PAO QUENTE 123", "8.00")
    other = add(client, auth, account, "PADARIA PAO QUENTE 456", "9.00")
    mercado = category_id(client, auth, "Mercado")
    resp = client.patch(f"/transactions/{first['id']}", json={"category_id": mercado}, headers=auth)
    assert resp.json()["category_locked"] is True

    # transação antiga parecida foi recategorizada
    assert client.get(f"/transactions/{other['id']}", headers=auth).json()["category_id"] == mercado
    # e as novas também usam a regra
    assert add(client, auth, account, "PADARIA PAO QUENTE 789", "7.00")["category_id"] == mercado


def test_balance_and_filters(client, auth, account):
    add(client, auth, account, "Salário", "3000.00", kind="income")
    add(client, auth, account, "Mercado Assaí", "200.00")
    accounts = client.get("/accounts", headers=auth).json()
    assert accounts[0]["balance"] == "3800.00"

    page = client.get("/transactions", params={"kind": "expense"}, headers=auth).json()
    assert page["total"] == 1
    page = client.get("/transactions", params={"search": "assa"}, headers=auth).json()
    assert page["total"] == 1


def test_validation(client, auth, account):
    resp = client.post("/transactions", json={"account_id": account["id"], "description": "x",
                                              "amount": "-5", "date": "2026-01-01"}, headers=auth)
    assert resp.status_code == 422
    salario = category_id(client, auth, "Salário")
    resp = client.post("/transactions", json={"account_id": account["id"], "description": "x", "amount": "5",
                                              "kind": "expense", "category_id": salario, "date": "2026-01-01"},
                       headers=auth)
    assert resp.status_code == 422


def test_normalize_helpers():
    assert normalize("Açaí  da Esquina!") == "acai da esquina"
    assert keyword_from_description("UBER *TRIP 8842 SAO PAULO") == "uber trip sao"
    assert keyword_from_description("12345") is None
