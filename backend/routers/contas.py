from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from models import Conta, Usuario
from schemas import ContaCreate, ContaResponse
from security.auth import obter_usuario_atual


router = APIRouter(
    prefix="/contas",
    tags=["Contas"],
)


@router.post(
    "/",
    response_model=ContaResponse,
)
def criar_conta(
    dados: ContaCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    conta = Conta(
        usuario_id=usuario.id,
        nome=dados.nome,
        tipo=dados.tipo,
        saldo_inicial=dados.saldo_inicial,
        ativa=dados.ativa,
    )

    db.add(conta)
    db.commit()
    db.refresh(conta)

    return conta


@router.get(
    "/",
    response_model=list[ContaResponse],
)
def listar_contas(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return (
        db.query(Conta)
        .filter(
            Conta.usuario_id == usuario.id
        )
        .all()
    )