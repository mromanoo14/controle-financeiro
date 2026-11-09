"""Regras do plano de assinatura."""

from datetime import datetime, timedelta, timezone

from app.core.config import get_settings
from app.models import Plan, SubscriptionStatus, User

PLANS = [
    {
        "id": "premium_monthly",
        "name": "Premium mensal",
        "price_cents": 1490,
        "features": [
            "Conexão automática com bancos (Open Finance)",
            "Previsão de gastos para os próximos meses",
            "Categorias e orçamentos ilimitados",
        ],
    },
]


def _aware(dt: datetime | None) -> datetime | None:
    # SQLite devolve datetimes sem fuso; tratamos como UTC.
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def start_trial(user: User, now: datetime | None = None) -> None:
    now = now or datetime.now(timezone.utc)
    user.plan = Plan.FREE
    user.subscription_status = SubscriptionStatus.TRIAL
    user.trial_ends_at = now + timedelta(days=get_settings().trial_days)


def is_premium(user: User, now: datetime | None = None) -> bool:
    now = now or datetime.now(timezone.utc)
    if user.subscription_status == SubscriptionStatus.TRIAL:
        ends = _aware(user.trial_ends_at)
        return ends is not None and ends > now
    if user.plan == Plan.PREMIUM and user.subscription_status in (
        SubscriptionStatus.ACTIVE,
        SubscriptionStatus.CANCELED,  # cancelada continua válida até o fim do período pago
    ):
        ends = _aware(user.subscription_ends_at)
        return ends is None or ends > now
    return False


def activate_premium(user: User, until: datetime) -> None:
    user.plan = Plan.PREMIUM
    user.subscription_status = SubscriptionStatus.ACTIVE
    user.subscription_ends_at = until
