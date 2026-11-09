"""Configurações da aplicação, lidas de variáveis de ambiente / arquivo .env."""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "Controle Financeiro API"
    environment: str = "development"  # development | production | test

    database_url: str = "postgresql+psycopg://financeiro:financeiro@localhost:5432/controle_financeiro"

    # Segurança
    secret_key: str = Field(default="troque-esta-chave-em-producao", min_length=16)
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 dias
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # Assinatura
    trial_days: int = 14
    billing_provider: str = "mock"  # mock | (futuro: google, apple, revenuecat)

    # Open Finance (agregador)
    open_finance_provider: str = "mock"  # mock | pluggy
    pluggy_client_id: str = ""
    pluggy_client_secret: str = ""
    pluggy_base_url: str = "https://api.pluggy.ai"
    open_finance_webhook_secret: str = ""

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.is_production and settings.secret_key == "troque-esta-chave-em-producao":
        raise RuntimeError("Defina SECRET_KEY no ambiente de produção.")
    return settings
