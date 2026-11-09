"""Integração com agregadores de Open Finance (Pluggy, Belvo...)."""

from app.core.config import get_settings
from app.services.open_finance.base import OpenFinanceProvider


def get_provider() -> OpenFinanceProvider:
    settings = get_settings()
    if settings.open_finance_provider == "pluggy":
        from app.services.open_finance.pluggy import PluggyProvider

        return PluggyProvider(
            client_id=settings.pluggy_client_id,
            client_secret=settings.pluggy_client_secret,
            base_url=settings.pluggy_base_url,
        )
    from app.services.open_finance.mock import MockProvider

    return MockProvider()
