from fastapi import APIRouter, HTTPException

from app.deps import DB, CurrentUser
from app.models import SubscriptionStatus, User
from app.schemas import PlanOut, PurchaseIn, SubscriptionOut
from app.services.billing import BillingError, get_billing
from app.services.subscription import PLANS, activate_premium, is_premium

router = APIRouter(prefix="/subscription", tags=["Assinatura"])


def _out(user: User) -> SubscriptionOut:
    return SubscriptionOut(
        plan=user.plan,
        status=user.subscription_status,
        is_premium=is_premium(user),
        trial_ends_at=user.trial_ends_at,
        subscription_ends_at=user.subscription_ends_at,
    )


@router.get("/plans", response_model=list[PlanOut])
def plans():
    return PLANS


@router.get("", response_model=SubscriptionOut)
def current(user: CurrentUser):
    return _out(user)


@router.post("/purchase", response_model=SubscriptionOut)
def purchase(data: PurchaseIn, user: CurrentUser, db: DB):
    """Valida o comprovante da loja e ativa o Premium."""
    if data.product_id not in {p["id"] for p in PLANS}:
        raise HTTPException(status_code=422, detail="Plano desconhecido.")
    try:
        verified = get_billing().verify(data)
    except BillingError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    activate_premium(user, verified.expires_at)
    user.billing_customer_id = verified.customer_id
    db.commit()
    return _out(user)


@router.post("/cancel", response_model=SubscriptionOut)
def cancel(user: CurrentUser, db: DB):
    """Marca como cancelada; o acesso continua até o fim do período pago.

    Nas lojas, o cancelamento real é feito pelo usuário na Play Store/App Store
    e chega via webhook do provedor de pagamento.
    """
    if user.subscription_status == SubscriptionStatus.ACTIVE:
        user.subscription_status = SubscriptionStatus.CANCELED
        db.commit()
    return _out(user)
