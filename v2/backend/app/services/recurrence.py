"""Cálculo das ocorrências de gastos/receitas recorrentes."""

from datetime import date, timedelta

from dateutil.relativedelta import relativedelta
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Frequency, Recurrence, Transaction
from app.services.categorization import normalize

_STEP = {
    Frequency.WEEKLY: relativedelta(weeks=1),
    Frequency.MONTHLY: relativedelta(months=1),
    Frequency.YEARLY: relativedelta(years=1),
}

# Limite de segurança para não gerar listas infinitas.
_MAX_ITERATIONS = 5000


def occurrences(rec: Recurrence, start: date, end: date) -> list[date]:
    """Datas em que a recorrência acontece dentro de [start, end].

    Cada data é calculada a partir de `start_date` (n * passo), assim um
    vencimento no dia 31 vira 28/29/30 em meses curtos e volta a 31 depois.
    """
    if not rec.active:
        return []
    step = _STEP[rec.frequency]
    result: list[date] = []
    for n in range(_MAX_ITERATIONS):
        if rec.installments is not None and n >= rec.installments:
            break
        current = rec.start_date + step * n
        if current > end or (rec.end_date is not None and current > rec.end_date):
            break
        if current >= start:
            result.append(current)
    return result


def next_occurrence(rec: Recurrence, today: date) -> date | None:
    found = occurrences(rec, today, today + relativedelta(years=2))
    return found[0] if found else None


def period_window(rec: Recurrence, when: date) -> tuple[date, date]:
    """Janela em que um lançamento conta como 'pagamento' desta ocorrência."""
    if rec.frequency == Frequency.WEEKLY:
        return when - timedelta(days=3), when + timedelta(days=3)
    # Mensal/anual: qualquer dia do mesmo mês.
    first = when.replace(day=1)
    return first, first + relativedelta(months=1) - timedelta(days=1)


def is_paid(db: Session, rec: Recurrence, when: date) -> bool:
    start, end = period_window(rec, when)
    return (
        db.scalar(
            select(Transaction.id).where(
                Transaction.recurrence_id == rec.id,
                Transaction.date >= start,
                Transaction.date <= end,
            ).limit(1)
        )
        is not None
    )


def match_recurrence(db: Session, tx: Transaction) -> Recurrence | None:
    """Tenta ligar uma transação nova a uma recorrência ainda não paga.

    Critérios: mesmo tipo, descrição parecida e valor até 15% diferente,
    com uma ocorrência prevista no mesmo período.
    """
    text = normalize(tx.description)
    candidates = db.scalars(
        select(Recurrence).where(
            Recurrence.user_id == tx.user_id,
            Recurrence.kind == tx.kind,
            Recurrence.active.is_(True),
        )
    ).all()
    for rec in candidates:
        name = normalize(rec.description)
        if not name or (name not in text and text not in name):
            continue
        if abs(tx.amount - rec.amount) > rec.amount * 15 / 100:
            continue
        window_start = tx.date - relativedelta(months=1)
        window_end = tx.date + relativedelta(months=1)
        for when in occurrences(rec, window_start, window_end):
            start, end = period_window(rec, when)
            if start <= tx.date <= end and not is_paid(db, rec, when):
                return rec
    return None
