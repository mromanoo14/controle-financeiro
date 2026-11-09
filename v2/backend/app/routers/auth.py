from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.security import create_access_token, hash_password, verify_password
from app.deps import DB, CurrentUser
from app.models import User
from app.schemas import LoginIn, PasswordChange, RegisterIn, TokenOut, UserOut, UserUpdate
from app.services.categorization import seed_default_categories
from app.services.subscription import is_premium, start_trial

router = APIRouter(tags=["Autenticação e perfil"])


def user_out(user: User) -> UserOut:
    out = UserOut.model_validate(user)
    out.is_premium = is_premium(user)
    return out


@router.post("/auth/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(data: RegisterIn, db: DB):
    email = data.email.lower()
    if db.scalar(select(User.id).where(User.email == email)):
        raise HTTPException(status_code=409, detail="Este e-mail já está cadastrado.")
    user = User(name=data.name.strip(), email=email, password_hash=hash_password(data.password))
    start_trial(user)
    db.add(user)
    db.flush()
    seed_default_categories(db, user)
    db.commit()
    return TokenOut(access_token=create_access_token(user.id))


@router.post("/auth/login", response_model=TokenOut)
def login(data: LoginIn, db: DB):
    user = db.scalar(select(User).where(User.email == data.email.lower()))
    if user is None or not user.is_active or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="E-mail ou senha inválidos.")
    return TokenOut(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser):
    return user_out(user)


@router.patch("/me", response_model=UserOut)
def update_me(data: UserUpdate, user: CurrentUser, db: DB):
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.commit()
    return user_out(user)


@router.post("/me/password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(data: PasswordChange, user: CurrentUser, db: DB):
    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Senha atual incorreta.")
    user.password_hash = hash_password(data.new_password)
    db.commit()


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(user: CurrentUser, db: DB):
    """Exclui a conta e todos os dados do usuário (direito previsto na LGPD)."""
    db.delete(user)
    db.commit()
