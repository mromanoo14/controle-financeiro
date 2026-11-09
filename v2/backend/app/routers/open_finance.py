import hmac
import logging

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Request, status
from sqlalchemy import select

from app.core.config import get_settings
from app.db import SessionLocal
from app.deps import DB, CurrentUser, PremiumUser, get_owned
from app.models import BankConnection
from app.schemas import ConnectionIn, ConnectionOut, ConnectTokenOut, SyncResult
from app.services.open_finance import get_provider
from app.services.open_finance.base import ProviderError
from app.services.open_finance.sync import sync_connection

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/open-finance", tags=["Open Finance"])


@router.post("/connect-token", response_model=ConnectTokenOut)
def connect_token(user: PremiumUser, item_id: str | None = None):
    """Token para abrir o widget de conexão do agregador no app.

    Envie `item_id` para reconectar um banco cuja conexão expirou.
    """
    provider = get_provider()
    try:
        token = provider.create_connect_token(client_user_id=str(user.id), item_id=item_id)
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    return ConnectTokenOut(provider=provider.name, connect_token=token)


@router.get("/connections", response_model=list[ConnectionOut])
def list_connections(user: CurrentUser, db: DB):
    return db.scalars(select(BankConnection).where(BankConnection.user_id == user.id)).all()


@router.post("/connections", response_model=SyncResult, status_code=status.HTTP_201_CREATED)
def add_connection(data: ConnectionIn, user: PremiumUser, db: DB):
    """Registra a conexão criada no widget e faz a primeira importação."""
    provider = get_provider()
    connection = db.scalar(
        select(BankConnection).where(
            BankConnection.provider == provider.name, BankConnection.external_id == data.external_id
        )
    )
    if connection is not None and connection.user_id != user.id:
        raise HTTPException(status_code=409, detail="Conexão pertence a outro usuário.")
    if connection is None:
        connection = BankConnection(user_id=user.id, provider=provider.name, external_id=data.external_id)
        db.add(connection)
        db.commit()
    try:
        return sync_connection(db, provider, connection)
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc))


@router.post("/connections/{connection_id}/sync", response_model=SyncResult)
def sync(connection_id: int, user: PremiumUser, db: DB):
    connection = get_owned(db, BankConnection, connection_id, user, "Conexão")
    try:
        return sync_connection(db, get_provider(), connection)
    except ProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc))


@router.delete("/connections/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_connection(connection_id: int, user: CurrentUser, db: DB):
    """Desconecta o banco. Contas e transações importadas são mantidas."""
    db.delete(get_owned(db, BankConnection, connection_id, user, "Conexão"))
    db.commit()


def _sync_in_background(connection_id: int) -> None:
    with SessionLocal() as db:
        connection = db.get(BankConnection, connection_id)
        if connection is None:
            return
        try:
            sync_connection(db, get_provider(), connection)
        except ProviderError:
            logger.exception("Falha ao sincronizar conexão %s", connection_id)


@router.post("/webhook", status_code=status.HTTP_202_ACCEPTED, include_in_schema=False)
async def webhook(
    request: Request,
    background: BackgroundTasks,
    x_webhook_secret: str | None = Header(default=None),
):
    """Recebe avisos do agregador (ex.: Pluggy `item/updated`) e sincroniza.

    Configure a URL do webhook como `.../open-finance/webhook` e envie o
    cabeçalho `X-Webhook-Secret` igual a OPEN_FINANCE_WEBHOOK_SECRET.
    """
    secret = get_settings().open_finance_webhook_secret
    if not secret or not hmac.compare_digest(x_webhook_secret or "", secret):
        raise HTTPException(status_code=401, detail="Webhook não autorizado.")
    payload = await request.json()
    item_id = payload.get("itemId") or payload.get("item_id")
    if not item_id:
        return {"ignored": True}
    with SessionLocal() as db:
        connection = db.scalar(select(BankConnection).where(BankConnection.external_id == item_id))
        if connection is None:
            return {"ignored": True}
        background.add_task(_sync_in_background, connection.id)
    return {"queued": True}
