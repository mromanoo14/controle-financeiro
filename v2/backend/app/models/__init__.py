"""Modelos do banco de dados."""

from datetime import date, datetime, timezone
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

Money = Numeric(14, 2)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _enum(cls: type[StrEnum]) -> Enum:
    # Guarda o valor (texto) no banco, não o nome do membro.
    return Enum(cls, native_enum=False, length=20, values_callable=lambda e: [m.value for m in e])


class Plan(StrEnum):
    FREE = "free"
    PREMIUM = "premium"


class SubscriptionStatus(StrEnum):
    TRIAL = "trial"
    ACTIVE = "active"
    CANCELED = "canceled"
    EXPIRED = "expired"


class AccountType(StrEnum):
    CHECKING = "checking"  # conta corrente
    SAVINGS = "savings"  # poupança
    CREDIT_CARD = "credit_card"
    WALLET = "wallet"  # dinheiro / carteira
    INVESTMENT = "investment"


class TransactionKind(StrEnum):
    EXPENSE = "expense"
    INCOME = "income"


class Source(StrEnum):
    MANUAL = "manual"
    OPEN_FINANCE = "open_finance"


class Frequency(StrEnum):
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    YEARLY = "yearly"


class ConnectionStatus(StrEnum):
    PENDING = "pending"
    ACTIVE = "active"
    ERROR = "error"
    DISCONNECTED = "disconnected"


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Salário/renda mensal esperada, usada na previsão.
    monthly_income: Mapped[Decimal | None] = mapped_column(Money, nullable=True)

    plan: Mapped[Plan] = mapped_column(_enum(Plan), default=Plan.FREE)
    subscription_status: Mapped[SubscriptionStatus] = mapped_column(
        _enum(SubscriptionStatus), default=SubscriptionStatus.TRIAL
    )
    trial_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    subscription_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    billing_customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    accounts: Mapped[list["Account"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    categories: Mapped[list["Category"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class Account(TimestampMixin, Base):
    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    type: Mapped[AccountType] = mapped_column(_enum(AccountType), default=AccountType.CHECKING)
    institution: Mapped[str | None] = mapped_column(String(120), nullable=True)
    initial_balance: Mapped[Decimal] = mapped_column(Money, default=Decimal("0"))
    # Saldo informado pelo banco (Open Finance); quando presente, prevalece.
    synced_balance: Mapped[Decimal | None] = mapped_column(Money, nullable=True)
    source: Mapped[Source] = mapped_column(_enum(Source), default=Source.MANUAL)
    external_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    connection_id: Mapped[int | None] = mapped_column(
        ForeignKey("bank_connections.id", ondelete="SET NULL"), nullable=True
    )
    archived: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped[User] = relationship(back_populates="accounts")
    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="account", cascade="all, delete-orphan"
    )


class Category(TimestampMixin, Base):
    """Departamento de gasto (ex.: Alimentação, Transporte)."""

    __tablename__ = "categories"
    __table_args__ = (UniqueConstraint("user_id", "name", "kind", name="uq_category_user_name_kind"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    kind: Mapped[TransactionKind] = mapped_column(_enum(TransactionKind), default=TransactionKind.EXPENSE)
    icon: Mapped[str] = mapped_column(String(40), default="category")
    color: Mapped[str] = mapped_column(String(9), default="#607D8B")

    user: Mapped[User] = relationship(back_populates="categories")


class CategoryRule(TimestampMixin, Base):
    """Regra aprendida: descrição contendo `keyword` => categoria."""

    __tablename__ = "category_rules"
    __table_args__ = (UniqueConstraint("user_id", "keyword", name="uq_rule_user_keyword"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    keyword: Mapped[str] = mapped_column(String(120))
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id", ondelete="CASCADE"))


class Transaction(TimestampMixin, Base):
    __tablename__ = "transactions"
    __table_args__ = (UniqueConstraint("account_id", "external_id", name="uq_transaction_account_external"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    recurrence_id: Mapped[int | None] = mapped_column(
        ForeignKey("recurrences.id", ondelete="SET NULL"), nullable=True
    )
    kind: Mapped[TransactionKind] = mapped_column(_enum(TransactionKind))
    amount: Mapped[Decimal] = mapped_column(Money)  # sempre positivo
    description: Mapped[str] = mapped_column(String(255))
    date: Mapped[date] = mapped_column(Date, index=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    source: Mapped[Source] = mapped_column(_enum(Source), default=Source.MANUAL)
    external_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # True quando o usuário escolheu a categoria manualmente (não sobrescrever).
    category_locked: Mapped[bool] = mapped_column(Boolean, default=False)

    account: Mapped[Account] = relationship(back_populates="transactions")
    category: Mapped[Category | None] = relationship()


class Recurrence(TimestampMixin, Base):
    """Gasto ou receita fixa/recorrente (aluguel, salário, assinatura...)."""

    __tablename__ = "recurrences"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    account_id: Mapped[int | None] = mapped_column(ForeignKey("accounts.id", ondelete="SET NULL"), nullable=True)
    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"), nullable=True
    )
    kind: Mapped[TransactionKind] = mapped_column(_enum(TransactionKind), default=TransactionKind.EXPENSE)
    description: Mapped[str] = mapped_column(String(255))
    amount: Mapped[Decimal] = mapped_column(Money)
    frequency: Mapped[Frequency] = mapped_column(_enum(Frequency), default=Frequency.MONTHLY)
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Número de parcelas (compras parceladas). None = sem fim.
    installments: Mapped[int | None] = mapped_column(Integer, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    category: Mapped[Category | None] = relationship()


class Budget(TimestampMixin, Base):
    """Limite mensal de gasto por categoria."""

    __tablename__ = "budgets"
    __table_args__ = (UniqueConstraint("user_id", "category_id", name="uq_budget_user_category"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id", ondelete="CASCADE"))
    monthly_limit: Mapped[Decimal] = mapped_column(Money)

    category: Mapped[Category] = relationship()


class BankConnection(TimestampMixin, Base):
    """Conexão com um banco via agregador de Open Finance."""

    __tablename__ = "bank_connections"
    __table_args__ = (UniqueConstraint("provider", "external_id", name="uq_connection_provider_external"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(40))
    external_id: Mapped[str] = mapped_column(String(255))  # ex.: itemId da Pluggy
    institution: Mapped[str | None] = mapped_column(String(120), nullable=True)
    status: Mapped[ConnectionStatus] = mapped_column(_enum(ConnectionStatus), default=ConnectionStatus.PENDING)
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    error_message: Mapped[str | None] = mapped_column(String(500), nullable=True)
