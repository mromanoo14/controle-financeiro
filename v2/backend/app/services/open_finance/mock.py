"""Provedor simulado para desenvolvimento e testes (sem chaves de API)."""

from datetime import date, timedelta
from decimal import Decimal

from app.models import AccountType, ConnectionStatus, TransactionKind
from app.services.open_finance.base import ProviderAccount, ProviderItem, ProviderTransaction

_SAMPLE = [
    ("IFOOD *RESTAURANTE", "42.90", TransactionKind.EXPENSE),
    ("UBER *TRIP", "18.50", TransactionKind.EXPENSE),
    ("SUPERMERCADO ASSAI", "312.47", TransactionKind.EXPENSE),
    ("NETFLIX.COM", "55.90", TransactionKind.EXPENSE),
    ("POSTO SHELL", "200.00", TransactionKind.EXPENSE),
    ("DROGASIL", "37.80", TransactionKind.EXPENSE),
    ("PIX RECEBIDO", "150.00", TransactionKind.INCOME),
]


class MockProvider:
    name = "mock"

    def create_connect_token(self, client_user_id: str, item_id: str | None = None) -> str:
        return f"mock-connect-token-{client_user_id}"

    def get_item(self, item_id: str) -> ProviderItem:
        return ProviderItem(external_id=item_id, institution="Banco Simulado", status=ConnectionStatus.ACTIVE)

    def list_accounts(self, item_id: str) -> list[ProviderAccount]:
        return [
            ProviderAccount(f"{item_id}-cc", "Conta corrente", AccountType.CHECKING, Decimal("2500.00"), "Banco Simulado"),
            ProviderAccount(f"{item_id}-card", "Cartão de crédito", AccountType.CREDIT_CARD, Decimal("-830.15"), "Banco Simulado"),
        ]

    def list_transactions(self, account_id: str, since: date) -> list[ProviderTransaction]:
        today = date.today()
        result = []
        for i, (desc, amount, kind) in enumerate(_SAMPLE):
            when = today - timedelta(days=i * 3)
            if when >= since:
                result.append(ProviderTransaction(f"{account_id}-{i}", when, desc, Decimal(amount), kind))
        return result
