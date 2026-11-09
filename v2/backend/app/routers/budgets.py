from datetime import date

from fastapi import APIRouter, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.deps import DB, CurrentUser, get_owned
from app.models import Budget, Category
from app.schemas import BudgetIn, BudgetOut
from app.services.finance import ZERO, month_bounds, spent_by_category

router = APIRouter(prefix="/budgets", tags=["Orçamentos"])


@router.get("", response_model=list[BudgetOut])
def list_budgets(user: CurrentUser, db: DB, year: int | None = None, month: int | None = None):
    today = date.today()
    start, end = month_bounds(year or today.year, month or today.month)
    spent = spent_by_category(db, user.id, start, end)
    budgets = db.scalars(
        select(Budget).options(selectinload(Budget.category)).where(Budget.user_id == user.id)
    ).all()
    result = []
    for b in budgets:
        out = BudgetOut.model_validate(b)
        out.spent = spent.get(b.category_id, ZERO)
        result.append(out)
    return result


@router.put("", response_model=BudgetOut, status_code=status.HTTP_200_OK)
def upsert_budget(data: BudgetIn, user: CurrentUser, db: DB):
    """Cria ou atualiza o limite mensal de uma categoria."""
    get_owned(db, Category, data.category_id, user, "Categoria")
    budget = db.scalar(
        select(Budget).where(Budget.user_id == user.id, Budget.category_id == data.category_id)
    )
    if budget is None:
        budget = Budget(user_id=user.id, category_id=data.category_id, monthly_limit=data.monthly_limit)
        db.add(budget)
    else:
        budget.monthly_limit = data.monthly_limit
    db.commit()
    db.refresh(budget)
    return BudgetOut.model_validate(budget)


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_budget(budget_id: int, user: CurrentUser, db: DB):
    db.delete(get_owned(db, Budget, budget_id, user, "Orçamento"))
    db.commit()
