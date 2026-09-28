from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Usuario
from schemas import UsuarioCreate, UsuarioResponse
from services.auth_service import criar_usuario


router = APIRouter(
    prefix="/usuarios",
    tags=["Usuários"],
)


@router.post(
    "/",
    response_model=UsuarioResponse,
)
def criar(
    dados: UsuarioCreate,
    db: Session = Depends(get_db),
):
    usuario_existente = (
        db.query(Usuario)
        .filter(Usuario.email == dados.email)
        .first()
    )

    if usuario_existente:
        raise HTTPException(
            status_code=400,
            detail="E-mail já cadastrado.",
        )

    return criar_usuario(
        db=db,
        nome=dados.nome,
        email=dados.email,
        senha=dados.senha,
    )