from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
from services.auth_service import autenticar_usuario


router = APIRouter(
    prefix="/auth",
    tags=["Autenticação"],
)


class LoginRequest(BaseModel):
    email: str
    senha: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str


@router.post(
    "/login",
    response_model=LoginResponse,
)
def login(
    dados: LoginRequest,
    db: Session = Depends(get_db),
):
    resultado = autenticar_usuario(
        db=db,
        email=dados.email,
        senha=dados.senha,
    )

    if resultado is None:
        raise HTTPException(
            status_code=401,
            detail="E-mail ou senha inválidos.",
        )

    return {
        "access_token": resultado["access_token"],
        "token_type": resultado["token_type"],
    }