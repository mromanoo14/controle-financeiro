from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Investimento, Usuario
from schemas import InvestimentoCreate, InvestimentoResponse
from security.auth import obter_usuario_atual


router = APIRouter(
    prefix="/investimentos",
    tags=["Investimentos"],
)


@router.post(
    "/",
    response_model=InvestimentoResponse,
)
def criar_investimento(
    dados: InvestimentoCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    investimento = Investimento(
        usuario_id=usuario.id,
        nome=dados.nome,
        tipo=dados.tipo,
        valor_investido=dados.valor_investido,
        ativo=dados.ativo,
    )

    db.add(investimento)
    db.commit()
    db.refresh(investimento)

    return investimento


@router.get(
    "/",
    response_model=list[InvestimentoResponse],
)
def listar_investimentos(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return (
        db.query(Investimento)
        .filter(
            Investimento.usuario_id == usuario.id,
            Investimento.ativo == True,
        )
        .all()
    )


@router.put(
    "/{investimento_id}",
    response_model=InvestimentoResponse,
)
def atualizar_investimento(
    investimento_id: int,
    dados: InvestimentoCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    investimento = (
        db.query(Investimento)
        .filter(
            Investimento.id == investimento_id,
            Investimento.usuario_id == usuario.id,
        )
        .first()
    )

    if investimento is None:
        raise HTTPException(
            status_code=404,
            detail="Investimento não encontrado.",
        )

    investimento.nome = dados.nome
    investimento.tipo = dados.tipo
    investimento.valor_investido = dados.valor_investido
    investimento.ativo = dados.ativo

    db.commit()
    db.refresh(investimento)

    return investimento