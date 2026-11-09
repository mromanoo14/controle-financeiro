from datetime import date as Date

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.deps import DB, CurrentUser, get_owned
from app.models import Account, Category, Recurrence
from app.schemas import RecurrenceIn, RecurrenceOut, RecurrenceUpdate, TransactionOut
from app.services import recurrence as rec_service
from app.services.finance import create_transaction

router = APIRouter(prefix="/recurrences", tags=["Gastos e receitas recorrentes"])


def _out(rec: Recurrence) -> RecurrenceOut:
    out = RecurrenceOut.model_validate(rec)
    out.next_date = rec_service.next_occurrence(rec, Date.today())
    return out


def _validate(db, user, account_id, category_id, kind):
    if account_id is not None:
        get_owned(db, Account, account_id, user, "Conta")
    if category_id is not None:
        category = get_owned(db, Category, category_id, user, "Categoria")
        if category.kind != kind:
            raise HTTPException(status_code=422, detail="A categoria não corresponde ao tipo.")


@router.get("", response_model=list[RecurrenceOut])
def list_recurrences(user: CurrentUser, db: DB, include_inactive: bool = False):
    query = (
        select(Recurrence)
        .options(selectinload(Recurrence.category))
        .where(Recurrence.user_id == user.id)
        .order_by(Recurrence.description)
    )
    if not include_inactive:
        query = query.where(Recurrence.active.is_(True))
    return [_out(r) for r in db.scalars(query)]


@router.post("", response_model=RecurrenceOut, status_code=status.HTTP_201_CREATED)
def create_recurrence(data: RecurrenceIn, user: CurrentUser, db: DB):
    _validate(db, user, data.account_id, data.category_id, data.kind)
    rec = Recurrence(user_id=user.id, **data.model_dump())
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return _out(rec)


@router.patch("/{rec_id}", response_model=RecurrenceOut)
def update_recurrence(rec_id: int, data: RecurrenceUpdate, user: CurrentUser, db: DB):
    rec = get_owned(db, Recurrence, rec_id, user, "Recorrência")
    changes = data.model_dump(exclude_unset=True)
    _validate(db, user, changes.get("account_id"), changes.get("category_id"), rec.kind)
    for field, value in changes.items():
        setattr(rec, field, value)
    db.commit()
    db.refresh(rec)
    return _out(rec)


@router.delete("/{rec_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_recurrence(rec_id: int, user: CurrentUser, db: DB):
    db.delete(get_owned(db, Recurrence, rec_id, user, "Recorrência"))
    db.commit()


class PayIn(BaseModel):
    date: Date | None = None  # data da ocorrência; padrão = próxima
    account_id: int | None = None


@router.post("/{rec_id}/pay", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
def pay_recurrence(rec_id: int, data: PayIn, user: CurrentUser, db: DB):
    """Registra o pagamento/recebimento de uma ocorrência como transação."""
    rec = get_owned(db, Recurrence, rec_id, user, "Recorrência")
    when = data.date or rec_service.next_occurrence(rec, Date.today().replace(day=1))
    if when is None:
        raise HTTPException(status_code=422, detail="Esta recorrência não tem ocorrências futuras.")
    if rec_service.is_paid(db, rec, when):
        raise HTTPException(status_code=409, detail="Esta ocorrência já foi registrada.")
    account_id = data.account_id or rec.account_id
    if account_id is None:
        raise HTTPException(status_code=422, detail="Informe a conta do pagamento.")
    get_owned(db, Account, account_id, user, "Conta")
    tx = create_transaction(
        db,
        user,
        account_id=account_id,
        kind=rec.kind,
        amount=rec.amount,
        description=rec.description,
        when=when,
        category_id=rec.category_id,
        recurrence_id=rec.id,
    )
    db.commit()
    db.refresh(tx)
    return tx
