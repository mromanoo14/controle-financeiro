"""Importa contas e transações de uma conexão bancária."""

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, BankConnection, ConnectionStatus, Source, Transaction, User
from app.schemas import SyncResult
from app.services.finance import create_transaction
from app.services.open_finance.base import OpenFinanceProvider, ProviderError

FIRST_SYNC_DAYS = 90
OVERLAP_DAYS = 7  # reimporta alguns dias para pegar lançamentos que mudaram


def sync_connection(db: Session, provider: OpenFinanceProvider, connection: BankConnection) -> SyncResult:
    user = db.get(User, connection.user_id)
    imported = skipped = 0
    try:
        item = provider.get_item(connection.external_id)
        connection.institution = item.institution or connection.institution
        connection.status = item.status
        connection.error_message = item.error_message

        if connection.last_synced_at:
            since = connection.last_synced_at.date() - timedelta(days=OVERLAP_DAYS)
        else:
            since = date.today() - timedelta(days=FIRST_SYNC_DAYS)

        provider_accounts = provider.list_accounts(connection.external_id)
        for p_acc in provider_accounts:
            account = db.scalar(
                select(Account).where(Account.user_id == user.id, Account.external_id == p_acc.external_id)
            )
            if account is None:
                account = Account(
                    user_id=user.id,
                    name=p_acc.name,
                    type=p_acc.type,
                    institution=p_acc.institution or connection.institution,
                    source=Source.OPEN_FINANCE,
                    external_id=p_acc.external_id,
                    connection_id=connection.id,
                )
                db.add(account)
                db.flush()
            account.synced_balance = p_acc.balance

            existing = set(
                db.scalars(
                    select(Transaction.external_id).where(
                        Transaction.account_id == account.id, Transaction.external_id.is_not(None)
                    )
                )
            )
            for p_tx in provider.list_transactions(p_acc.external_id, since):
                if p_tx.external_id in existing:
                    skipped += 1
                    continue
                create_transaction(
                    db,
                    user,
                    account_id=account.id,
                    kind=p_tx.kind,
                    amount=p_tx.amount,
                    description=p_tx.description,
                    when=p_tx.date,
                    source=Source.OPEN_FINANCE,
                    external_id=p_tx.external_id,
                )
                existing.add(p_tx.external_id)
                imported += 1
                db.flush()  # permite que a próxima transação veja recorrências já pagas

        connection.last_synced_at = datetime.now(timezone.utc)
        db.commit()
        return SyncResult(
            connection_id=connection.id, accounts=len(provider_accounts), imported=imported, skipped=skipped
        )
    except ProviderError as exc:
        db.rollback()
        connection.status = ConnectionStatus.ERROR
        connection.error_message = str(exc)[:500]
        db.commit()
        raise
