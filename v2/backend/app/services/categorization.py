"""Categorização automática de transações em departamentos."""

import re
import unicodedata

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Category, CategoryRule, Transaction, TransactionKind, User

# Categorias criadas para todo novo usuário: (nome, tipo, ícone, cor)
DEFAULT_CATEGORIES: list[tuple[str, TransactionKind, str, str]] = [
    ("Alimentação", TransactionKind.EXPENSE, "restaurant", "#FF7043"),
    ("Mercado", TransactionKind.EXPENSE, "shopping_cart", "#8D6E63"),
    ("Transporte", TransactionKind.EXPENSE, "directions_car", "#42A5F5"),
    ("Moradia", TransactionKind.EXPENSE, "home", "#7E57C2"),
    ("Saúde", TransactionKind.EXPENSE, "favorite", "#EF5350"),
    ("Educação", TransactionKind.EXPENSE, "school", "#26A69A"),
    ("Lazer", TransactionKind.EXPENSE, "celebration", "#FFCA28"),
    ("Assinaturas", TransactionKind.EXPENSE, "subscriptions", "#AB47BC"),
    ("Compras", TransactionKind.EXPENSE, "shopping_bag", "#EC407A"),
    ("Contas e serviços", TransactionKind.EXPENSE, "receipt_long", "#78909C"),
    ("Impostos e tarifas", TransactionKind.EXPENSE, "account_balance", "#5D4037"),
    ("Outros", TransactionKind.EXPENSE, "category", "#9E9E9E"),
    ("Salário", TransactionKind.INCOME, "payments", "#43A047"),
    ("Outras receitas", TransactionKind.INCOME, "savings", "#66BB6A"),
]

# Palavras-chave padrão => nome da categoria. Comparadas por palavra inteira.
DEFAULT_KEYWORDS: dict[str, list[str]] = {
    "Alimentação": ["ifood", "restaurante", "lanchonete", "padaria", "rappi", "burger", "pizza",
                    "mcdonalds", "bk", "cafe", "cafeteria", "acai", "subway", "outback"],
    "Mercado": ["mercado", "supermercado", "atacadao", "assai", "carrefour", "pao de acucar",
                "hortifruti", "sacolao",],
    "Transporte": ["uber", "99app", "99 pop", "99pop", "cabify", "posto", "combustivel", "gasolina",
                   "estacionamento", "shell", "ipiranga", "petrobras", "pedagio", "sem parar",
                   "conectcar", "metro", "onibus", "bilhete unico"],
    "Moradia": ["aluguel", "condominio", "iptu", "imobiliaria"],
    "Contas e serviços": ["energia", "enel", "cemig", "copel", "sabesp", "agua",
                          "internet", "vivo", "claro", "tim", "oi fibra", "comgas"],
    "Saúde": ["farmacia", "drogaria", "drogasil", "raia", "pague menos", "hospital", "clinica",
              "consulta", "laboratorio", "unimed", "amil", "odonto", "academia", "smartfit"],
    "Educação": ["escola", "faculdade", "universidade", "curso", "udemy", "alura", "livraria"],
    "Lazer": ["cinema", "ingresso", "show", "teatro", "bar", "steam", "playstation", "xbox",
              "viagem", "hotel", "airbnb", "booking"],
    "Assinaturas": ["netflix", "spotify", "disney", "hbo", "hbo max", "prime video", "amazon prime",
                    "youtube premium", "deezer", "globoplay", "icloud", "google one", "apple com bill"],
    "Compras": ["amazon", "mercado livre", "mercadolivre", "shopee", "magalu", "magazine luiza",
                "americanas", "shein", "aliexpress", "renner", "riachuelo", "c&a", "zara"],
    "Impostos e tarifas": ["tarifa", "iof", "anuidade", "juros", "multa", "darf", "ipva", "taxa"],
    "Salário": ["salario", "folha", "pagamento salario", "proventos"],
}


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-z0-9&]+", " ", text.lower())
    return re.sub(r"\s+", " ", text).strip()


def _contains_word(haystack: str, needle: str) -> bool:
    return re.search(rf"(?<![a-z0-9]){re.escape(needle)}(?![a-z0-9])", haystack) is not None


def keyword_from_description(description: str) -> str | None:
    """Extrai uma palavra-chave estável da descrição para aprender regras.

    Ex.: "UBER *TRIP 8842 SAO PAULO" -> "uber trip sao".
    """
    tokens = [t for t in normalize(description).split() if not t.isdigit() and len(t) >= 2]
    if not tokens:
        return None
    return " ".join(tokens[:3])


def seed_default_categories(db: Session, user: User) -> None:
    for name, kind, icon, color in DEFAULT_CATEGORIES:
        db.add(Category(user_id=user.id, name=name, kind=kind, icon=icon, color=color))


def suggest_category(db: Session, user_id: int, description: str, kind: TransactionKind) -> int | None:
    """Retorna o id da categoria sugerida, ou None."""
    text = normalize(description)
    if not text:
        return None

    categories = db.scalars(select(Category).where(Category.user_id == user_id)).all()
    by_id = {c.id: c for c in categories}

    # 1) Regras aprendidas com as correções do usuário (mais específicas primeiro).
    rules = db.scalars(select(CategoryRule).where(CategoryRule.user_id == user_id)).all()
    for rule in sorted(rules, key=lambda r: len(r.keyword), reverse=True):
        category = by_id.get(rule.category_id)
        if category and category.kind == kind and _contains_word(text, rule.keyword):
            return category.id

    # 2) Palavras-chave padrão.
    by_name = {(normalize(c.name), c.kind): c for c in categories}
    for category_name, keywords in DEFAULT_KEYWORDS.items():
        category = by_name.get((normalize(category_name), kind))
        if category is None:
            continue
        if any(_contains_word(text, normalize(k)) for k in keywords):
            return category.id

    # 3) Categoria genérica do tipo.
    fallback = "outros" if kind == TransactionKind.EXPENSE else "outras receitas"
    category = by_name.get((fallback, kind))
    return category.id if category else None


def learn_rule(db: Session, user_id: int, description: str, category_id: int) -> int:
    """Salva a regra e recategoriza transações parecidas não editadas.

    Retorna quantas transações antigas foram atualizadas.
    """

    keyword = keyword_from_description(description)
    if keyword is None:
        return 0
    rule = db.scalar(
        select(CategoryRule).where(CategoryRule.user_id == user_id, CategoryRule.keyword == keyword)
    )
    if rule is None:
        db.add(CategoryRule(user_id=user_id, keyword=keyword, category_id=category_id))
    else:
        rule.category_id = category_id

    category = db.get(Category, category_id)
    updated = 0
    similar = db.scalars(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.kind == category.kind,
            Transaction.category_locked.is_(False),
            Transaction.category_id.is_distinct_from(category_id),
        )
    )
    for tx in similar:
        if _contains_word(normalize(tx.description), keyword):
            tx.category_id = category_id
            updated += 1
    return updated
