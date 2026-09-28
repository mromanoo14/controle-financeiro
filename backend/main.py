from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import Base, engine

from routers import (
    usuarios,
    contas,
    transacoes,
    categorias,
    orcamentos,
    contas_futuras,
    metas,
    investimentos,
    open_finance,
    auth,
)


# =========================================================
# BANCO DE DADOS
# =========================================================

Base.metadata.create_all(bind=engine)


# =========================================================
# APLICAÇÃO
# =========================================================

app = FastAPI(
    title="Controle Financeiro API",
    version="2.0.0",
)


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# ROTAS
# =========================================================

@app.get("/")
def root():
    return {
        "message": "API do Controle Financeiro funcionando!",
        "version": "2.0.0",
    }


app.include_router(usuarios.router)
app.include_router(contas.router)
app.include_router(transacoes.router)
app.include_router(categorias.router)
app.include_router(orcamentos.router)
app.include_router(contas_futuras.router)
app.include_router(metas.router)
app.include_router(investimentos.router)
app.include_router(open_finance.router)
app.include_router(auth.router)