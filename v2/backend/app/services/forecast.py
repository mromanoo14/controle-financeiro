"""Previsão de gastos do mês e dos próximos meses.

Modelo simples e explicável:
  previsto = já gasto + recorrências que ainda vão vencer + estimativa variável

A estimativa variável usa a média dos gastos NÃO recorrentes de cada
categoria nos últimos meses fechados, proporcional aos dias que faltam.
"""

from collections import defaultdict
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from dateutil.relativedelta import relativedelta
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Budget, Category, Recurrence, Transaction, TransactionKind, User
from app.schemas import CategoryForecast, ForecastItem, MonthForecast
from app.services import recurrence as rec_service
from app.services.categorization import normalize
from app.services.finance import ZERO, month_bounds, spent_by_category

HISTORY_MONTHS = 3
CENT = Decimal("0.01")


def _q(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def _recurring_names(db: Session, user_id: int) -> list[str]:
    names = db.scalars(
        select(Recurrence.description).where(
            Recurrence.user_id == user_id,
            Recurrence.active.is_(True),
            Recurrence.kind == TransactionKind.EXPENSE,
        )
    ).all()
    return [n for n in (normalize(x) for x in names) if n]


def _variable_totals(db: Session, user_id: int, start: date, end: date) -> dict[int | None, Decimal]:
    """Soma por categoria dos gastos que NÃO são contas fixas.

    Exclui lançamentos ligados a uma recorrência e também os parecidos com
    alguma recorrência ativa (ex.: aluguéis lançados antes de cadastrar a conta
    fixa), para não contar o mesmo gasto duas vezes na previsão.
    """
    names = _recurring_names(db, user_id)
    rows = db.execute(
        select(Transaction.category_id, Transaction.description, Transaction.amount).where(
            Transaction.user_id == user_id,
            Transaction.kind == TransactionKind.EXPENSE,
            Transaction.recurrence_id.is_(None),
            Transaction.date >= start,
            Transaction.date <= end,
        )
    ).all()
    totals: dict[int | None, Decimal] = defaultdict(lambda: ZERO)
    for cid, description, amount in rows:
        text = normalize(description)
        if any(n in text or text in n for n in names):
            continue
        totals[cid] += Decimal(amount)
    return totals


def variable_monthly_average(db: Session, user_id: int, before: date) -> dict[int | None, Decimal]:
    """Média mensal de gastos não recorrentes por categoria nos meses anteriores a `before`."""
    first_tx = db.scalar(select(func.min(Transaction.date)).where(Transaction.user_id == user_id))
    if first_tx is None:
        return {}
    end = before.replace(day=1) - timedelta(days=1)
    start = before.replace(day=1) - relativedelta(months=HISTORY_MONTHS)
    start = max(start, first_tx.replace(day=1))
    if start > end:
        return {}
    months = (end.year - start.year) * 12 + end.month - start.month + 1
    return {cid: total / months for cid, total in _variable_totals(db, user_id, start, end).items()}


def month_forecast(db: Session, user: User, year: int, month: int, today: date | None = None) -> MonthForecast:
    today = today or date.today()
    start, end = month_bounds(year, month)
    days_in_month = (end - start).days + 1

    if today > end:  # mês passado: só valores reais
        remaining_from, remaining_days = end + timedelta(days=1), 0
    elif today < start:  # mês futuro: tudo é previsão
        remaining_from, remaining_days = start, days_in_month
    else:  # mês corrente: inclui o dia de hoje como "restante"
        remaining_from, remaining_days = today, (end - today).days + 1

    spent = spent_by_category(db, user.id, start, end)
    income_so_far = Decimal(
        db.scalar(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == user.id,
                Transaction.kind == TransactionKind.INCOME,
                Transaction.date >= start,
                Transaction.date <= end,
            )
        )
    )

    # Recorrências que ainda vão acontecer no mês (e não foram pagas).
    fixed: dict[int | None, Decimal] = defaultdict(lambda: ZERO)
    upcoming: list[ForecastItem] = []
    pending_income = ZERO
    recurrences = db.scalars(
        select(Recurrence).where(Recurrence.user_id == user.id, Recurrence.active.is_(True))
    ).all()
    if remaining_days:
        for rec in recurrences:
            for when in rec_service.occurrences(rec, remaining_from, end):
                if rec_service.is_paid(db, rec, when):
                    continue
                upcoming.append(
                    ForecastItem(
                        date=when,
                        description=rec.description,
                        amount=rec.amount,
                        kind=rec.kind,
                        category_id=rec.category_id,
                        recurrence_id=rec.id,
                    )
                )
                if rec.kind == TransactionKind.EXPENSE:
                    fixed[rec.category_id] += rec.amount
                else:
                    pending_income += rec.amount
    upcoming.sort(key=lambda i: (i.date, i.description))

    # Gastos variáveis: ritmo médio diário x dias restantes.
    variable: dict[int | None, Decimal] = defaultdict(lambda: ZERO)
    if remaining_days:
        averages = variable_monthly_average(db, user.id, min(start, today.replace(day=1)))
        already = _variable_totals(db, user.id, start, end) if today >= start else {}
        for cid, avg in averages.items():
            estimate = avg * remaining_days / days_in_month
            # Não prever além da média do mês se o usuário já gastou parte dela.
            estimate = min(estimate, max(avg - already.get(cid, ZERO), ZERO)) if already else estimate
            variable[cid] = _q(estimate)

    categories = {c.id: c for c in db.scalars(select(Category).where(Category.user_id == user.id))}
    budgets = {
        b.category_id: b.monthly_limit
        for b in db.scalars(select(Budget).where(Budget.user_id == user.id))
    }
    by_category: list[CategoryForecast] = []
    for cid in set(spent) | set(fixed) | set(variable):
        cat = categories.get(cid) if cid is not None else None
        if cat is not None and cat.kind != TransactionKind.EXPENSE:
            continue
        s, f, v = spent.get(cid, ZERO), _q(fixed.get(cid, ZERO)), variable.get(cid, ZERO)
        by_category.append(
            CategoryForecast(
                category_id=cid,
                name=cat.name if cat else "Sem categoria",
                color=cat.color if cat else "#9E9E9E",
                icon=cat.icon if cat else "help_outline",
                spent=_q(s),
                fixed=f,
                variable=v,
                projected=_q(s + f + v),
                budget=budgets.get(cid),
            )
        )
    by_category.sort(key=lambda c: c.projected, reverse=True)

    spent_total = _q(sum(spent.values(), ZERO))
    projected_expense = _q(sum((c.projected for c in by_category), ZERO))
    expected_income = income_so_far + pending_income
    if user.monthly_income and expected_income < user.monthly_income and today <= end:
        expected_income = user.monthly_income
    expected_income = _q(expected_income)

    return MonthForecast(
        year=year,
        month=month,
        expected_income=expected_income,
        income_so_far=_q(income_so_far),
        spent_so_far=spent_total,
        projected_expense=projected_expense,
        projected_balance=_q(expected_income - projected_expense),
        by_category=by_category,
        upcoming=upcoming,
    )


def forecast_months(db: Session, user: User, months: int, today: date | None = None) -> list[MonthForecast]:
    today = today or date.today()
    result = []
    for i in range(months):
        ref = today.replace(day=1) + relativedelta(months=i)
        result.append(month_forecast(db, user, ref.year, ref.month, today=today))
    return result
