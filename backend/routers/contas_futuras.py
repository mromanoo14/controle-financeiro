from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import ContaFutura, Usuario
from schemas import ContaFuturaCreate, ContaFuturaResponse
from security.auth import obter_usuario_atual


router = APIRouter(
    prefix="/contas-futuras",
    tags=["Contas Futuras"],
)


@router.post(
    "/",
    response_model=ContaFuturaResponse,
)
def criar_conta_futura(
    dados: ContaFuturaCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    conta = ContaFutura(
        usuario_id=usuario.id,
        descricao=dados.descricao,
        valor=dados.valor,
        vencimento=dados.vencimento,
        categoria_id=dados.categoria_id,
        paga=dados.paga,
        recorrente=dados.recorrente,
    )

    db.add(conta)
    db.commit()
    db.refresh(conta)

    return conta


@router.get(
    "/",
    response_model=list[ContaFuturaResponse],
)
def listar_contas_futuras(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return (
        db.query(ContaFutura)
        .filter(
            ContaFutura.usuario_id == usuario.id
        )
        .order_by(ContaFutura.vencimento.asc())
        .all()
    )


@router.put(
    "/{conta_id}/pagar",
    response_model=ContaFuturaResponse,
)
def marcar_como_paga(
    conta_id: int,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    conta = (
        db.query(ContaFutura)
        .filter(
            ContaFutura.id == conta_id,
            ContaFutura.usuario_id == usuario.id,
        )
        .first()
    )

    if conta is None:
        raise HTTPException(
            status_code=404,
            detail="Conta futura não encontrada.",
        )

    conta.paga = True

    db.commit()
    db.refresh(conta)

    return conta