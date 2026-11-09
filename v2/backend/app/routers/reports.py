from datetime import date

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.deps import DB, CurrentUser
from app.models import Transaction
from app.schemas import Dashboard, MonthForecast, MonthSummary, TransactionOut
from app.services.finance import list_accounts_out, month_summary
from app.services.forecast import forecast_months, month_forecast
from app.services.subscription import is_premium

router = APIRouter(tags=["Relatórios e previsão"])


@router.get("/dashboard", response_model=Dashboard)
def dashboard(user: CurrentUser, db: DB):
    today = date.today()
    accounts = list_accounts_out(db, user)
    recent = db.scalars(
        select(Transaction)
        .options(selectinload(Transaction.category))
        .where(Transaction.user_id == user.id)
        .order_by(Transaction.date.desc(), Transaction.id.desc())
        .limit(10)
    ).all()
    return Dashboard(
        total_balance=sum((a.balance for a in accounts), start=0),
        accounts=accounts,
        month=month_summary(db, user, today.year, today.month),
        forecast=month_forecast(db, user, today.year, today.month),
        recent_transactions=[TransactionOut.model_validate(t) for t in recent],
    )


@router.get("/reports/monthly", response_model=list[MonthSummary])
def monthly_history(user: CurrentUser, db: DB, months: int = Query(default=6, ge=1, le=24)):
    """Resumo dos últimos N meses (o mais antigo primeiro)."""
    today = date.today()
    result = []
    for i in range(months - 1, -1, -1):
        y, m = today.year, today.month - i
        while m <= 0:
            m += 12
            y -= 1
        result.append(month_summary(db, user, y, m))
    return result


@router.get("/forecast", response_model=list[MonthForecast])
def forecast(user: CurrentUser, db: DB, months: int = Query(default=1, ge=1, le=12)):
    """Previsão do mês atual (grátis) e dos próximos meses (Premium)."""
    if months > 1 and not is_premium(user):
        raise HTTPException(status_code=402, detail="Previsão de vários meses disponível no plano Premium.")
    return forecast_months(db, user, months)
