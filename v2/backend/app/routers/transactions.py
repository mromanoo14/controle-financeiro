from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.deps import DB, CurrentUser, get_owned
from app.models import Account, Category, Transaction, TransactionKind, User
from app.schemas import TransactionIn, TransactionOut, TransactionPage, TransactionUpdate
from app.services.categorization import learn_rule
from app.services.finance import create_transaction, month_bounds

router = APIRouter(prefix="/transactions", tags=["Transações"])


def _check_refs(db: Session, user: User, account_id: int | None, category_id: int | None,
                kind: TransactionKind | None) -> None:
    if account_id is not None:
        get_owned(db, Account, account_id, user, "Conta")
    if category_id is not None:
        category = get_owned(db, Category, category_id, user, "Categoria")
        if kind is not None and category.kind != kind:
            raise HTTPException(status_code=422, detail="A categoria não corresponde ao tipo da transação.")


@router.get("", response_model=TransactionPage)
def list_transactions(
    user: CurrentUser,
    db: DB,
    year: int | None = None,
    month: int | None = Query(default=None, ge=1, le=12),
    start: date | None = None,
    end: date | None = None,
    account_id: int | None = None,
    category_id: int | None = None,
    kind: TransactionKind | None = None,
    search: str | None = None,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
):
    filters = [Transaction.user_id == user.id]
    if year and month:
        start, end = month_bounds(year, month)
    if start:
        filters.append(Transaction.date >= start)
    if end:
        filters.append(Transaction.date <= end)
    if account_id:
        filters.append(Transaction.account_id == account_id)
    if category_id:
        filters.append(Transaction.category_id == category_id)
    if kind:
        filters.append(Transaction.kind == kind)
    if search:
        pattern = f"%{search.strip()}%"
        filters.append(or_(Transaction.description.ilike(pattern), Transaction.notes.ilike(pattern)))

    total = db.scalar(select(func.count()).select_from(Transaction).where(*filters))
    items = db.scalars(
        select(Transaction)
        .options(selectinload(Transaction.category))
        .where(*filters)
        .order_by(Transaction.date.desc(), Transaction.id.desc())
        .limit(limit)
        .offset(offset)
    ).all()
    return TransactionPage(items=items, total=total)


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
def add_transaction(data: TransactionIn, user: CurrentUser, db: DB):
    _check_refs(db, user, data.account_id, data.category_id, data.kind)
    tx = create_transaction(
        db,
        user,
        account_id=data.account_id,
        kind=data.kind,
        amount=data.amount,
        description=data.description,
        when=data.date,
        category_id=data.category_id,
        notes=data.notes,
    )
    db.commit()
    db.refresh(tx)
    return tx


@router.get("/{tx_id}", response_model=TransactionOut)
def get_transaction(tx_id: int, user: CurrentUser, db: DB):
    return get_owned(db, Transaction, tx_id, user, "Transação")


@router.patch("/{tx_id}", response_model=TransactionOut)
def update_transaction(tx_id: int, data: TransactionUpdate, user: CurrentUser, db: DB):
    tx = get_owned(db, Transaction, tx_id, user, "Transação")
    changes = data.model_dump(exclude_unset=True, exclude={"learn_rule"})
    _check_refs(db, user, changes.get("account_id"), changes.get("category_id"), changes.get("kind", tx.kind))

    category_changed = "category_id" in changes and changes["category_id"] != tx.category_id
    for field, value in changes.items():
        setattr(tx, field, value)
    if category_changed:
        tx.category_locked = True
        if data.learn_rule and tx.category_id is not None:
            learn_rule(db, user.id, tx.description, tx.category_id)
    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{tx_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(tx_id: int, user: CurrentUser, db: DB):
    db.delete(get_owned(db, Transaction, tx_id, user, "Transação"))
    db.commit()
