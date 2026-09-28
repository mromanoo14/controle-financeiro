from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Transacao, Usuario
from schemas import TransacaoCreate, TransacaoResponse
from security.auth import obter_usuario_atual

from services.finance_service import (
    criar_transacao,
    listar_transacoes,
    buscar_transacao,
    excluir_transacao,
)


router = APIRouter(
    prefix="/transacoes",
    tags=["Transações"],
)


@router.post(
    "/",
    response_model=TransacaoResponse,
)
def criar(
    dados: TransacaoCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    try:
        return criar_transacao(
            db=db,
            usuario_id=usuario.id,
            conta_id=dados.conta_id,
            categoria_id=dados.categoria_id,
            descricao=dados.descricao,
            tipo=dados.tipo,
            valor=dados.valor,
            data=dados.data,
            forma_pagamento=dados.forma_pagamento,
            observacao=dados.observacao,
            recorrente=dados.recorrente,
        )

    except ValueError as erro:
        raise HTTPException(
            status_code=400,
            detail=str(erro),
        )


@router.get(
    "/",
    response_model=list[TransacaoResponse],
)
def listar(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return listar_transacoes(
        db=db,
        usuario_id=usuario.id,
    )


@router.get(
    "/{transacao_id}",
    response_model=TransacaoResponse,
)
def buscar(
    transacao_id: int,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    transacao = buscar_transacao(
        db=db,
        usuario_id=usuario.id,
        transacao_id=transacao_id,
    )

    if transacao is None:
        raise HTTPException(
            status_code=404,
            detail="Transação não encontrada.",
        )

    return transacao


@router.delete(
    "/{transacao_id}",
)
def excluir(
    transacao_id: int,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    transacao = excluir_transacao(
        db=db,
        usuario_id=usuario.id,
        transacao_id=transacao_id,
    )

    if transacao is None:
        raise HTTPException(
            status_code=404,
            detail="Transação não encontrada.",
        )

    return {
        "message": "Transação excluída com sucesso."
    }