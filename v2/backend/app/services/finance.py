"""Saldos, resumos mensais e criação de transações."""

import calendar
from collections import defaultdict
from datetime import date
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models import Account, Category, Source, Transaction, TransactionKind, User
from app.schemas import AccountOut, CategoryTotal, MonthSummary
from app.services import categorization, recurrence

ZERO = Decimal("0.00")


def month_bounds(year: int, month: int) -> tuple[date, date]:
    last = calendar.monthrange(year, month)[1]
    return date(year, month, 1), date(year, month, last)


def account_balances(db: Session, user_id: int) -> dict[int, Decimal]:
    signed = case(
        (Transaction.kind == TransactionKind.INCOME, Transaction.amount),
        else_=-Transaction.amount,
    )
    rows = db.execute(
        select(Transaction.account_id, func.coalesce(func.sum(signed), 0))
        .where(Transaction.user_id == user_id)
        .group_by(Transaction.account_id)
    ).all()
    return {account_id: Decimal(total) for account_id, total in rows}


def account_out(account: Account, movements: dict[int, Decimal]) -> AccountOut:
    out = AccountOut.model_validate(account)
    if account.synced_balance is not None:
        out.balance = account.synced_balance
    else:
        out.balance = (account.initial_balance + movements.get(account.id, ZERO)).quantize(Decimal("0.01"))
    return out


def list_accounts_out(db: Session, user: User, include_archived: bool = False) -> list[AccountOut]:
    query = select(Account).where(Account.user_id == user.id).order_by(Account.name)
    if not include_archived:
        query = query.where(Account.archived.is_(False))
    movements = account_balances(db, user.id)
    return [account_out(a, movements) for a in db.scalars(query)]


def category_totals(
    db: Session, user_id: int, start: date, end: date, kind: TransactionKind
) -> list[CategoryTotal]:
    rows = db.execute(
        select(
            Category.id,
            Category.name,
            Category.color,
            Category.icon,
            func.sum(Transaction.amount),
        )
        .select_from(Transaction)
        .outerjoin(Category, Category.id == Transaction.category_id)
        .where(
            Transaction.user_id == user_id,
            Transaction.kind == kind,
            Transaction.date >= start,
            Transaction.date <= end,
        )
        .group_by(Category.id, Category.name, Category.color, Category.icon)
    ).all()
    totals = [
        CategoryTotal(
            category_id=cid,
            name=name or "Sem categoria",
            color=color or "#9E9E9E",
            icon=icon or "help_outline",
            total=Decimal(total).quantize(Decimal("0.01")),
        )
        for cid, name, color, icon, total in rows
    ]
    return sorted(totals, key=lambda t: t.total, reverse=True)


def month_summary(db: Session, user: User, year: int, month: int) -> MonthSummary:
    start, end = month_bounds(year, month)
    expenses = category_totals(db, user.id, start, end, TransactionKind.EXPENSE)
    incomes = category_totals(db, user.id, start, end, TransactionKind.INCOME)
    expense = sum((c.total for c in expenses), ZERO)
    income = sum((c.total for c in incomes), ZERO)
    return MonthSummary(
        year=year,
        month=month,
        income=income,
        expense=expense,
        balance=income - expense,
        by_category=expenses,
    )


def spent_by_category(db: Session, user_id: int, start: date, end: date) -> dict[int | None, Decimal]:
    totals: dict[int | None, Decimal] = defaultdict(lambda: ZERO)
    for item in category_totals(db, user_id, start, end, TransactionKind.EXPENSE):
        totals[item.category_id] += item.total
    return totals


def create_transaction(
    db: Session,
    user: User,
    *,
    account_id: int,
    kind: TransactionKind,
    amount: Decimal,
    description: str,
    when: date,
    category_id: int | None = None,
    notes: str | None = None,
    source: Source = Source.MANUAL,
    external_id: str | None = None,
    recurrence_id: int | None = None,
) -> Transaction:
    """Cria a transação, categoriza automaticamente e liga a uma recorrência."""
    locked = category_id is not None
    if category_id is None:
        category_id = categorization.suggest_category(db, user.id, description, kind)
    tx = Transaction(
        user_id=user.id,
        account_id=account_id,
        category_id=category_id,
        kind=kind,
        amount=amount,
        description=description,
        date=when,
        notes=notes,
        source=source,
        external_id=external_id,
        category_locked=locked,
        recurrence_id=recurrence_id,
    )
    if recurrence_id is None:
        rec = recurrence.match_recurrence(db, tx)
        if rec is not None:
            tx.recurrence_id = rec.id
            if not locked and rec.category_id is not None:
                tx.category_id = rec.category_id
    db.add(tx)
    return tx
