"""Contrato que todo provedor de Open Finance precisa implementar."""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Protocol

from app.models import AccountType, ConnectionStatus, TransactionKind


class ProviderError(Exception):
    pass


@dataclass
class ProviderItem:
    external_id: str
    institution: str | None
    status: ConnectionStatus
    error_message: str | None = None


@dataclass
class ProviderAccount:
    external_id: str
    name: str
    type: AccountType
    balance: Decimal | None
    institution: str | None = None


@dataclass
class ProviderTransaction:
    external_id: str
    date: date
    description: str
    amount: Decimal  # sempre positivo
    kind: TransactionKind


class OpenFinanceProvider(Protocol):
    name: str

    def create_connect_token(self, client_user_id: str, item_id: str | None = None) -> str:
        """Token usado pelo widget de conexão no app."""

    def get_item(self, item_id: str) -> ProviderItem: ...

    def list_accounts(self, item_id: str) -> list[ProviderAccount]: ...

    def list_transactions(self, account_id: str, since: date) -> list[ProviderTransaction]: ...
