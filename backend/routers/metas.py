from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Meta, Usuario
from schemas import MetaCreate, MetaResponse
from security.auth import obter_usuario_atual


router = APIRouter(
    prefix="/metas",
    tags=["Metas"],
)


@router.post(
    "/",
    response_model=MetaResponse,
)
def criar_meta(
    dados: MetaCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    meta = Meta(
        usuario_id=usuario.id,
        nome=dados.nome,
        valor_objetivo=dados.valor_objetivo,
        valor_atual=dados.valor_atual,
        data_limite=dados.data_limite,
        concluida=dados.concluida,
    )

    db.add(meta)
    db.commit()
    db.refresh(meta)

    return meta


@router.get(
    "/",
    response_model=list[MetaResponse],
)
def listar_metas(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return (
        db.query(Meta)
        .filter(
            Meta.usuario_id == usuario.id
        )
        .order_by(Meta.data_limite.asc())
        .all()
    )


@router.put(
    "/{meta_id}",
    response_model=MetaResponse,
)
def atualizar_meta(
    meta_id: int,
    dados: MetaCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    meta = (
        db.query(Meta)
        .filter(
            Meta.id == meta_id,
            Meta.usuario_id == usuario.id,
        )
        .first()
    )

    if meta is None:
        raise HTTPException(
            status_code=404,
            detail="Meta não encontrada.",
        )

    meta.nome = dados.nome
    meta.valor_objetivo = dados.valor_objetivo
    meta.valor_atual = dados.valor_atual
    meta.data_limite = dados.data_limite
    meta.concluida = dados.concluida

    db.commit()
    db.refresh(meta)

    return meta