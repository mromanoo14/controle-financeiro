from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.deps import DB, CurrentUser, get_owned
from app.models import Category, TransactionKind
from app.schemas import CategoryIn, CategoryOut, CategoryUpdate

router = APIRouter(prefix="/categories", tags=["Categorias (departamentos)"])


@router.get("", response_model=list[CategoryOut])
def list_categories(user: CurrentUser, db: DB, kind: TransactionKind | None = None):
    query = select(Category).where(Category.user_id == user.id).order_by(Category.kind, Category.name)
    if kind:
        query = query.where(Category.kind == kind)
    return db.scalars(query).all()


def _commit(db):
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Já existe uma categoria com esse nome.")


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def create_category(data: CategoryIn, user: CurrentUser, db: DB):
    category = Category(user_id=user.id, **data.model_dump())
    db.add(category)
    _commit(db)
    return category


@router.patch("/{category_id}", response_model=CategoryOut)
def update_category(category_id: int, data: CategoryUpdate, user: CurrentUser, db: DB):
    category = get_owned(db, Category, category_id, user, "Categoria")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(category, field, value)
    _commit(db)
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(category_id: int, user: CurrentUser, db: DB):
    """As transações dessa categoria ficam 'sem categoria'."""
    db.delete(get_owned(db, Category, category_id, user, "Categoria"))
    db.commit()
