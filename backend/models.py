from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Date,
    Boolean,
    ForeignKey,
    DateTime,
    Text,
)
from sqlalchemy.orm import relationship
from datetime import datetime

from database import Base


# =========================================================
# USUÁRIO
# =========================================================

class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)

    nome = Column(String, nullable=False)

    email = Column(
        String,
        nullable=False,
        unique=True,
        index=True,
    )

    senha_hash = Column(
        String,
        nullable=False,
    )

    ativo = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    criado_em = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    contas = relationship(
        "Conta",
        back_populates="usuario",
        cascade="all, delete-orphan",
    )

    categorias = relationship(
        "Categoria",
        back_populates="usuario",
        cascade="all, delete-orphan",
    )

    transacoes = relationship(
        "Transacao",
        back_populates="usuario",
        cascade="all, delete-orphan",
    )

    metas = relationship(
        "Meta",
        back_populates="usuario",
        cascade="all, delete-orphan",
    )

    investimentos = relationship(
        "Investimento",
        back_populates="usuario",
        cascade="all, delete-orphan",
    )

    contas_futuras = relationship(
        "ContaFutura",
        back_populates="usuario",
        cascade="all, delete-orphan",
    )


# =========================================================
# CONTA
# =========================================================

class Conta(Base):
    __tablename__ = "contas"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    usuario_id = Column(
        Integer,
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )

    nome = Column(
        String,
        nullable=False,
    )

    tipo = Column(
        String,
        nullable=False,
    )

    saldo_inicial = Column(
        Float,
        nullable=False,
        default=0,
    )

    ativa = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    criado_em = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    usuario = relationship(
        "Usuario",
        back_populates="contas",
    )

    transacoes = relationship(
        "Transacao",
        back_populates="conta",
        cascade="all, delete-orphan",
    )


# =========================================================
# CATEGORIA
# =========================================================

class Categoria(Base):
    __tablename__ = "categorias"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    usuario_id = Column(
        Integer,
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )

    nome = Column(
        String,
        nullable=False,
    )

    orcamento = Column(
        Float,
        nullable=False,
        default=0,
    )

    ativa = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    usuario = relationship(
        "Usuario",
        back_populates="categorias",
    )

    transacoes = relationship(
        "Transacao",
        back_populates="categoria_relacao",
    )


# =========================================================
# TRANSAÇÃO
# =========================================================

class Transacao(Base):
    __tablename__ = "transacoes"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    usuario_id = Column(
        Integer,
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )

    conta_id = Column(
        Integer,
        ForeignKey("contas.id"),
        nullable=False,
        index=True,
    )

    categoria_id = Column(
        Integer,
        ForeignKey("categorias.id"),
        nullable=True,
        index=True,
    )

    descricao = Column(
        String,
        nullable=False,
    )

    tipo = Column(
        String,
        nullable=False,
    )

    valor = Column(
        Float,
        nullable=False,
    )

    data = Column(
        Date,
        nullable=False,
    )

    forma_pagamento = Column(
        String,
        nullable=False,
    )

    observacao = Column(
        Text,
        nullable=True,
    )

    recorrente = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    criado_em = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    usuario = relationship(
        "Usuario",
        back_populates="transacoes",
    )

    conta = relationship(
        "Conta",
        back_populates="transacoes",
    )

    categoria_relacao = relationship(
        "Categoria",
        back_populates="transacoes",
    )

    # =========================================================
# META
# =========================================================

class Meta(Base):
    __tablename__ = "metas"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    usuario_id = Column(
        Integer,
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )

    nome = Column(
        String,
        nullable=False,
    )

    valor_objetivo = Column(
        Float,
        nullable=False,
        default=0,
    )

    valor_atual = Column(
        Float,
        nullable=False,
        default=0,
    )

    data_limite = Column(
        Date,
        nullable=True,
    )

    concluida = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    criado_em = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    usuario = relationship(
        "Usuario",
        back_populates="metas",
    )


# =========================================================
# INVESTIMENTO
# =========================================================

class Investimento(Base):
    __tablename__ = "investimentos"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    usuario_id = Column(
        Integer,
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )

    nome = Column(
        String,
        nullable=False,
    )

    tipo = Column(
        String,
        nullable=False,
    )

    valor_investido = Column(
        Float,
        nullable=False,
        default=0,
    )

    ativo = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    criado_em = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    usuario = relationship(
        "Usuario",
        back_populates="investimentos",
    )

    # =========================================================
# CONTA FUTURA
# =========================================================

class ContaFutura(Base):
    __tablename__ = "contas_futuras"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    usuario_id = Column(
        Integer,
        ForeignKey("usuarios.id"),
        nullable=False,
        index=True,
    )

    descricao = Column(
        String,
        nullable=False,
    )

    valor = Column(
        Float,
        nullable=False,
    )

    vencimento = Column(
        Date,
        nullable=False,
    )

    categoria_id = Column(
        Integer,
        ForeignKey("categorias.id"),
        nullable=True,
        index=True,
    )

    paga = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    recorrente = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    criado_em = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    usuario = relationship(
        "Usuario",
        back_populates="contas_futuras",
    )

    categoria = relationship(
        "Categoria",
    )