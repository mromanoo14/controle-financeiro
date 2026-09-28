from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


# =========================================================
# USUÁRIO
# =========================================================

class UsuarioBase(BaseModel):
    nome: str
    email: str


class UsuarioCreate(UsuarioBase):
    senha: str


class UsuarioResponse(UsuarioBase):
    id: int
    ativo: bool
    criado_em: datetime

    model_config = ConfigDict(from_attributes=True)


# =========================================================
# CONTA
# =========================================================

class ContaBase(BaseModel):
    nome: str
    tipo: str
    saldo_inicial: float = 0
    ativa: bool = True


class ContaCreate(ContaBase):
    pass


class ContaResponse(ContaBase):
    id: int
    usuario_id: int
    criado_em: datetime

    model_config = ConfigDict(from_attributes=True)


# =========================================================
# CATEGORIA
# =========================================================

class CategoriaBase(BaseModel):
    nome: str
    orcamento: float = 0
    ativa: bool = True


class CategoriaCreate(CategoriaBase):
    pass


class CategoriaResponse(CategoriaBase):
    id: int
    usuario_id: int

    model_config = ConfigDict(from_attributes=True)


# =========================================================
# TRANSAÇÃO
# =========================================================

class TransacaoBase(BaseModel):
    descricao: str
    tipo: str
    valor: float
    data: date
    forma_pagamento: str
    categoria_id: int | None = None
    observacao: str | None = None
    recorrente: bool = False


class TransacaoCreate(TransacaoBase):
    conta_id: int


class TransacaoResponse(TransacaoBase):
    id: int
    usuario_id: int
    conta_id: int
    criado_em: datetime

    model_config = ConfigDict(from_attributes=True)


# =========================================================
# CONTA FUTURA
# =========================================================

class ContaFuturaBase(BaseModel):
    descricao: str
    valor: float
    vencimento: date
    categoria_id: int | None = None
    paga: bool = False
    recorrente: bool = False


class ContaFuturaCreate(ContaFuturaBase):
    pass


class ContaFuturaResponse(ContaFuturaBase):
    id: int
    usuario_id: int
    criado_em: datetime

    model_config = ConfigDict(from_attributes=True)


# =========================================================
# META
# =========================================================

class MetaBase(BaseModel):
    nome: str
    valor_objetivo: float
    valor_atual: float = 0
    data_limite: date | None = None
    concluida: bool = False


class MetaCreate(MetaBase):
    pass


class MetaResponse(MetaBase):
    id: int
    usuario_id: int
    criado_em: datetime

    model_config = ConfigDict(from_attributes=True)


# =========================================================
# INVESTIMENTO
# =========================================================

class InvestimentoBase(BaseModel):
    nome: str
    tipo: str
    valor_investido: float
    ativo: bool = True


class InvestimentoCreate(InvestimentoBase):
    pass


class InvestimentoResponse(InvestimentoBase):
    id: int
    usuario_id: int
    criado_em: datetime

    model_config = ConfigDict(from_attributes=True)