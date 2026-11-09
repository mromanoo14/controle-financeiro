"""Verificação de compras de assinatura.

Em produção, a compra é feita pela loja (Google Play Billing / Apple IAP) e o
backend precisa validar o comprovante com a loja — ou usar um serviço como o
RevenueCat, que faz isso e envia webhooks. Aqui fica a interface e um
provedor simulado para desenvolvimento.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from dateutil.relativedelta import relativedelta

from app.core.config import get_settings
from app.schemas import PurchaseIn


class BillingError(Exception):
    pass


@dataclass
class VerifiedPurchase:
    product_id: str
    expires_at: datetime
    customer_id: str


class MockBilling:
    def verify(self, purchase: PurchaseIn) -> VerifiedPurchase:
        if get_settings().is_production:
            raise BillingError("Provedor de pagamento simulado não pode ser usado em produção.")
        if not purchase.purchase_token.startswith("mock-"):
            raise BillingError("Comprovante inválido.")
        return VerifiedPurchase(
            product_id=purchase.product_id,
            expires_at=datetime.now(timezone.utc) + relativedelta(months=1) + timedelta(days=1),
            customer_id=purchase.purchase_token,
        )


def get_billing():
    provider = get_settings().billing_provider
    if provider == "mock":
        return MockBilling()
    raise BillingError(f"Provedor de pagamento '{provider}' ainda não implementado.")
