from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from models import Usuario
from security.auth import obter_usuario_atual
from services.budget_service import calcular_orcamento


router = APIRouter(
    prefix="/orcamentos",
    tags=["Orçamentos"],
)


@router.get("/")
def consultar_orcamento(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return calcular_orcamento(
        db=db,
        usuario_id=usuario.id,
    )