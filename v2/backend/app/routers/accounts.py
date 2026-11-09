from fastapi import APIRouter, status

from app.deps import DB, CurrentUser, get_owned
from app.models import Account
from app.schemas import AccountIn, AccountOut, AccountUpdate
from app.services.finance import account_balances, account_out, list_accounts_out

router = APIRouter(prefix="/accounts", tags=["Contas"])


@router.get("", response_model=list[AccountOut])
def list_accounts(user: CurrentUser, db: DB, include_archived: bool = False):
    return list_accounts_out(db, user, include_archived)


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
def create_account(data: AccountIn, user: CurrentUser, db: DB):
    account = Account(user_id=user.id, **data.model_dump())
    db.add(account)
    db.commit()
    return account_out(account, {})


@router.patch("/{account_id}", response_model=AccountOut)
def update_account(account_id: int, data: AccountUpdate, user: CurrentUser, db: DB):
    account = get_owned(db, Account, account_id, user, "Conta")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(account, field, value)
    db.commit()
    return account_out(account, account_balances(db, user.id))


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(account_id: int, user: CurrentUser, db: DB):
    db.delete(get_owned(db, Account, account_id, user, "Conta"))
    db.commit()
