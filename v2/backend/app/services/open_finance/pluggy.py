"""Provedor Pluggy (https://docs.pluggy.ai).

Fluxo:
1. Backend gera um connect token (POST /connect_token).
2. App abre o Pluggy Connect com o token; o usuário escolhe o banco e consente.
3. O widget devolve um `itemId`, que o app envia para POST /open-finance/connections.
4. Backend busca contas e transações; webhooks avisam de novas atualizações.
"""

import time
from datetime import date
from decimal import Decimal

import httpx

from app.models import AccountType, ConnectionStatus, TransactionKind
from app.services.open_finance.base import (
    ProviderAccount,
    ProviderError,
    ProviderItem,
    ProviderTransaction,
)

_STATUS = {
    "UPDATED": ConnectionStatus.ACTIVE,
    "UPDATING": ConnectionStatus.PENDING,
    "LOGIN_ERROR": ConnectionStatus.ERROR,
    "OUTDATED": ConnectionStatus.ERROR,
    "WAITING_USER_INPUT": ConnectionStatus.PENDING,
}

_ACCOUNT_TYPE = {
    "CHECKING_ACCOUNT": AccountType.CHECKING,
    "SAVINGS_ACCOUNT": AccountType.SAVINGS,
    "CREDIT_CARD": AccountType.CREDIT_CARD,
}


class PluggyProvider:
    name = "pluggy"

    def __init__(self, client_id: str, client_secret: str, base_url: str = "https://api.pluggy.ai",
                 client: httpx.Client | None = None):
        if not client_id or not client_secret:
            raise ProviderError("Configure PLUGGY_CLIENT_ID e PLUGGY_CLIENT_SECRET.")
        self._client_id = client_id
        self._client_secret = client_secret
        self._http = client or httpx.Client(base_url=base_url, timeout=30)
        self._api_key: str | None = None
        self._api_key_expires = 0.0

    # ------------------------------------------------------------ HTTP

    def _key(self) -> str:
        if self._api_key is None or time.time() >= self._api_key_expires:
            resp = self._http.post("/auth", json={"clientId": self._client_id, "clientSecret": self._client_secret})
            self._raise(resp)
            self._api_key = resp.json()["apiKey"]
            self._api_key_expires = time.time() + 60 * 60  # a chave vale 2h; renovamos antes
        return self._api_key

    def _request(self, method: str, path: str, **kwargs) -> dict:
        resp = self._http.request(method, path, headers={"X-API-KEY": self._key()}, **kwargs)
        self._raise(resp)
        return resp.json()

    @staticmethod
    def _raise(resp: httpx.Response) -> None:
        if resp.status_code >= 400:
            raise ProviderError(f"Pluggy respondeu {resp.status_code}: {resp.text[:300]}")

    # ------------------------------------------------------------ API

    def create_connect_token(self, client_user_id: str, item_id: str | None = None) -> str:
        body: dict = {"options": {"clientUserId": client_user_id}}
        if item_id:
            body["itemId"] = item_id
        return self._request("POST", "/connect_token", json=body)["accessToken"]

    def get_item(self, item_id: str) -> ProviderItem:
        data = self._request("GET", f"/items/{item_id}")
        error = data.get("error") or {}
        return ProviderItem(
            external_id=data["id"],
            institution=(data.get("connector") or {}).get("name"),
            status=_STATUS.get(data.get("status", ""), ConnectionStatus.PENDING),
            error_message=error.get("message"),
        )

    def list_accounts(self, item_id: str) -> list[ProviderAccount]:
        data = self._request("GET", "/accounts", params={"itemId": item_id})
        accounts = []
        for acc in data.get("results", []):
            acc_type = _ACCOUNT_TYPE.get(acc.get("subtype", ""), AccountType.CHECKING)
            balance = acc.get("balance")
            accounts.append(
                ProviderAccount(
                    external_id=acc["id"],
                    name=acc.get("marketingName") or acc.get("name") or "Conta",
                    type=acc_type,
                    # Para cartão, o "balance" da Pluggy é a fatura em aberto (positivo = dívida).
                    balance=None if balance is None else (
                        -Decimal(str(balance)) if acc_type == AccountType.CREDIT_CARD else Decimal(str(balance))
                    ),
                )
            )
        return accounts

    def list_transactions(self, account_id: str, since: date) -> list[ProviderTransaction]:
        result: list[ProviderTransaction] = []
        page, total_pages = 1, 1
        while page <= total_pages:
            data = self._request(
                "GET",
                "/transactions",
                params={"accountId": account_id, "from": since.isoformat(), "pageSize": 500, "page": page},
            )
            total_pages = data.get("totalPages", 1)
            for tx in data.get("results", []):
                amount = Decimal(str(tx["amount"]))
                kind = TransactionKind.EXPENSE if tx.get("type") == "DEBIT" else TransactionKind.INCOME
                result.append(
                    ProviderTransaction(
                        external_id=tx["id"],
                        date=date.fromisoformat(tx["date"][:10]),
                        description=tx.get("description") or "Transação",
                        amount=abs(amount),
                        kind=kind,
                    )
                )
            page += 1
        return result
