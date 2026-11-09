"""Ponto de entrada da API: `uvicorn app.main:app --reload`."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routers import (
    accounts,
    auth,
    budgets,
    categories,
    open_finance,
    recurrences,
    reports,
    subscription,
    transactions,
)

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="2.0.0",
    description="API do app de controle financeiro pessoal.",
    docs_url=None if settings.is_production else "/docs",
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["Status"])
def health():
    return {"status": "ok", "version": app.version}


for module in (auth, accounts, categories, transactions, recurrences, budgets, reports, open_finance, subscription):
    app.include_router(module.router)
