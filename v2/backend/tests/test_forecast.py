from datetime import date
from decimal import Decimal

from app.models import Frequency, Recurrence
from app.services.recurrence import occurrences
from tests.conftest import category_id
from tests.test_transactions import add


def test_monthly_occurrence_clamps_end_of_month():
    rec = Recurrence(description="x", amount=Decimal("1"), frequency=Frequency.MONTHLY,
                     start_date=date(2026, 1, 31), active=True)
    got = occurrences(rec, date(2026, 1, 1), date(2026, 4, 30))
    assert got == [date(2026, 1, 31), date(2026, 2, 28), date(2026, 3, 31), date(2026, 4, 30)]


def test_installments_limit():
    rec = Recurrence(description="x", amount=Decimal("1"), frequency=Frequency.MONTHLY,
                     start_date=date(2026, 1, 10), installments=3, active=True)
    assert len(occurrences(rec, date(2026, 1, 1), date(2027, 1, 1))) == 3


def test_recurrence_payment_and_matching(client, auth, account):
    moradia = category_id(client, auth, "Moradia")
    today = date.today()
    rec = client.post("/recurrences", json={
        "description": "Aluguel", "amount": "1500.00", "category_id": moradia,
        "start_date": today.replace(day=1).isoformat(), "account_id": account["id"],
    }, headers=auth).json()
    assert rec["next_date"] is not None

    # Lançamento manual parecido é ligado automaticamente à recorrência.
    tx = add(client, auth, account, "Pagamento aluguel apto", "1500.00")
    assert tx["category_id"] == moradia

    resp = client.post(f"/recurrences/{rec['id']}/pay", json={}, headers=auth)
    assert resp.status_code == 409  # já pago este mês


def test_forecast_projects_fixed_and_variable(client, auth, account):
    today = date.today()
    # Histórico: 3 meses com R$ 300 de mercado (gasto variável).
    for i in range(1, 4):
        y, m = today.year, today.month - i
        while m <= 0:
            m += 12
            y -= 1
        add(client, auth, account, "Supermercado Assaí", "300.00", when=date(y, m, 10))

    # Recorrência que vence no último dia do mês (ainda não paga).
    last_day = date(today.year, today.month, 28)
    client.post("/recurrences", json={"description": "Escola", "amount": "800.00",
                                      "start_date": last_day.isoformat()}, headers=auth)
    client.patch("/me", json={"monthly_income": "5000.00"}, headers=auth)

    forecast = client.get("/forecast", headers=auth).json()[0]
    assert forecast["expected_income"] == "5000.00"
    projected = Decimal(forecast["projected_expense"])
    if today.day <= 28:
        assert projected >= Decimal("800.00")
        assert any(u["description"] == "Escola" for u in forecast["upcoming"])
    mercado = next(c for c in forecast["by_category"] if c["name"] == "Mercado")
    assert Decimal(mercado["variable"]) > 0
    assert Decimal(mercado["variable"]) <= Decimal("300.00")


def test_dashboard(client, auth, account):
    add(client, auth, account, "IFOOD", "50.00")
    data = client.get("/dashboard", headers=auth).json()
    assert data["total_balance"] == "950.00"
    assert data["month"]["expense"] == "50.00"
    assert len(data["recent_transactions"]) == 1
    assert client.get("/reports/monthly", params={"months": 3}, headers=auth).status_code == 200


def test_budgets(client, auth, account):
    alimentacao = category_id(client, auth, "Alimentação")
    resp = client.put("/budgets", json={"category_id": alimentacao, "monthly_limit": "500.00"}, headers=auth)
    assert resp.status_code == 200
    add(client, auth, account, "IFOOD", "120.00")
    budgets = client.get("/budgets", headers=auth).json()
    assert budgets[0]["spent"] == "120.00"


def test_fixed_expense_not_double_counted_as_variable(client, auth, account):
    """Aluguéis lançados antes de cadastrar a conta fixa não entram na média variável."""
    moradia = category_id(client, auth, "Moradia")
    today = date.today()
    for i in range(1, 4):
        y, m = today.year, today.month - i
        while m <= 0:
            m += 12
            y -= 1
        add(client, auth, account, "Aluguel apartamento", "1800.00", when=date(y, m, 10))
    client.post("/recurrences", json={"description": "Aluguel", "amount": "1800.00", "category_id": moradia,
                                      "start_date": date(today.year, today.month, 28).isoformat()}, headers=auth)
    forecast = client.get("/forecast", headers=auth).json()[0]
    row = next(c for c in forecast["by_category"] if c["name"] == "Moradia")
    assert Decimal(row["variable"]) == 0
