"""Schemas (entrada/saída) da API."""

from datetime import date as Date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import (
    AccountType,
    ConnectionStatus,
    Frequency,
    Plan,
    Source,
    SubscriptionStatus,
    TransactionKind,
)

PositiveMoney = Field(gt=0, max_digits=14, decimal_places=2)


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------- Auth / usuário


class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(ORM):
    id: int
    name: str
    email: EmailStr
    monthly_income: Decimal | None
    plan: Plan
    subscription_status: SubscriptionStatus
    trial_ends_at: datetime | None
    subscription_ends_at: datetime | None
    is_premium: bool = False


class UserUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    monthly_income: Decimal | None = Field(default=None, ge=0, max_digits=14, decimal_places=2)


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


# ---------------------------------------------------------------- Contas


class AccountIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: AccountType = AccountType.CHECKING
    institution: str | None = Field(default=None, max_length=120)
    initial_balance: Decimal = Field(default=Decimal("0"), max_digits=14, decimal_places=2)


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    type: AccountType | None = None
    institution: str | None = None
    initial_balance: Decimal | None = Field(default=None, max_digits=14, decimal_places=2)
    archived: bool | None = None


class AccountOut(ORM):
    id: int
    name: str
    type: AccountType
    institution: str | None
    initial_balance: Decimal
    balance: Decimal = Decimal("0")
    source: Source
    archived: bool


# ---------------------------------------------------------------- Categorias


class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    kind: TransactionKind = TransactionKind.EXPENSE
    icon: str = Field(default="category", max_length=40)
    color: str = Field(default="#607D8B", pattern=r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    icon: str | None = Field(default=None, max_length=40)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")


class CategoryOut(ORM):
    id: int
    name: str
    kind: TransactionKind
    icon: str
    color: str


# ---------------------------------------------------------------- Transações


class TransactionIn(BaseModel):
    account_id: int
    category_id: int | None = None  # None => categorização automática
    kind: TransactionKind = TransactionKind.EXPENSE
    amount: Decimal = PositiveMoney
    description: str = Field(min_length=1, max_length=255)
    date: Date
    notes: str | None = Field(default=None, max_length=500)

    @field_validator("description")
    @classmethod
    def strip(cls, v: str) -> str:
        return v.strip()


class TransactionUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    kind: TransactionKind | None = None
    amount: Decimal | None = Field(default=None, gt=0, max_digits=14, decimal_places=2)
    description: str | None = Field(default=None, min_length=1, max_length=255)
    date: Date | None = None
    notes: str | None = Field(default=None, max_length=500)
    # Quando o usuário corrige a categoria, aprender para as próximas.
    learn_rule: bool = True


class TransactionOut(ORM):
    id: int
    account_id: int
    category_id: int | None
    category: CategoryOut | None
    kind: TransactionKind
    amount: Decimal
    description: str
    date: Date
    notes: str | None
    source: Source
    category_locked: bool


class TransactionPage(BaseModel):
    items: list[TransactionOut]
    total: int


# ---------------------------------------------------------------- Recorrências


class RecurrenceIn(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    kind: TransactionKind = TransactionKind.EXPENSE
    description: str = Field(min_length=1, max_length=255)
    amount: Decimal = PositiveMoney
    frequency: Frequency = Frequency.MONTHLY
    start_date: Date
    end_date: Date | None = None
    installments: int | None = Field(default=None, ge=1, le=480)


class RecurrenceUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    description: str | None = Field(default=None, min_length=1, max_length=255)
    amount: Decimal | None = Field(default=None, gt=0, max_digits=14, decimal_places=2)
    frequency: Frequency | None = None
    end_date: Date | None = None
    installments: int | None = Field(default=None, ge=1, le=480)
    active: bool | None = None


class RecurrenceOut(ORM):
    id: int
    account_id: int | None
    category_id: int | None
    category: CategoryOut | None
    kind: TransactionKind
    description: str
    amount: Decimal
    frequency: Frequency
    start_date: Date
    end_date: Date | None
    installments: int | None
    active: bool
    next_date: Date | None = None


# ---------------------------------------------------------------- Orçamentos


class BudgetIn(BaseModel):
    category_id: int
    monthly_limit: Decimal = PositiveMoney


class BudgetOut(ORM):
    id: int
    category_id: int
    category: CategoryOut
    monthly_limit: Decimal
    spent: Decimal = Decimal("0")


# ---------------------------------------------------------------- Relatórios / previsão


class CategoryTotal(BaseModel):
    category_id: int | None
    name: str
    color: str
    icon: str
    total: Decimal


class MonthSummary(BaseModel):
    year: int
    month: int
    income: Decimal
    expense: Decimal
    balance: Decimal
    by_category: list[CategoryTotal]


class ForecastItem(BaseModel):
    date: Date
    description: str
    amount: Decimal
    kind: TransactionKind
    category_id: int | None
    recurrence_id: int


class CategoryForecast(BaseModel):
    category_id: int | None
    name: str
    color: str
    icon: str
    spent: Decimal  # já gasto no mês
    fixed: Decimal  # recorrências ainda por vir
    variable: Decimal  # estimativa de gastos variáveis restantes
    projected: Decimal  # total previsto no mês
    budget: Decimal | None


class MonthForecast(BaseModel):
    year: int
    month: int
    expected_income: Decimal
    income_so_far: Decimal
    spent_so_far: Decimal
    projected_expense: Decimal
    projected_balance: Decimal
    by_category: list[CategoryForecast]
    upcoming: list[ForecastItem]


class Dashboard(BaseModel):
    total_balance: Decimal
    accounts: list[AccountOut]
    month: MonthSummary
    forecast: MonthForecast
    recent_transactions: list[TransactionOut]


# ---------------------------------------------------------------- Open Finance


class ConnectTokenOut(BaseModel):
    provider: str
    connect_token: str


class ConnectionIn(BaseModel):
    external_id: str = Field(min_length=1, max_length=255)  # itemId retornado pelo widget


class ConnectionOut(ORM):
    id: int
    provider: str
    external_id: str
    institution: str | None
    status: ConnectionStatus
    last_synced_at: datetime | None
    error_message: str | None


class SyncResult(BaseModel):
    connection_id: int
    accounts: int
    imported: int
    skipped: int


# ---------------------------------------------------------------- Assinatura


class PlanOut(BaseModel):
    id: str
    name: str
    price_cents: int
    currency: str = "BRL"
    interval: str = "month"
    features: list[str]


class SubscriptionOut(BaseModel):
    plan: Plan
    status: SubscriptionStatus
    is_premium: bool
    trial_ends_at: datetime | None
    subscription_ends_at: datetime | None


class PurchaseIn(BaseModel):
    """Comprovante enviado pelo app após a compra na loja."""

    platform: str = Field(pattern="^(android|ios|mock)$")
    product_id: str
    purchase_token: str
