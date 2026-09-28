from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Categoria, Usuario
from schemas import CategoriaCreate, CategoriaResponse
from security.auth import obter_usuario_atual


router = APIRouter(
    prefix="/categorias",
    tags=["Categorias"],
)


@router.post(
    "/",
    response_model=CategoriaResponse,
)
def criar_categoria(
    dados: CategoriaCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    existente = (
        db.query(Categoria)
        .filter(
            Categoria.usuario_id == usuario.id,
            Categoria.nome == dados.nome,
        )
        .first()
    )

    if existente:
        raise HTTPException(
            status_code=400,
            detail="Categoria já existe.",
        )

    categoria = Categoria(
        usuario_id=usuario.id,
        nome=dados.nome,
        orcamento=dados.orcamento,
        ativa=dados.ativa,
    )

    db.add(categoria)
    db.commit()
    db.refresh(categoria)

    return categoria


@router.get(
    "/",
    response_model=list[CategoriaResponse],
)
def listar_categorias(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    return (
        db.query(Categoria)
        .filter(
            Categoria.usuario_id == usuario.id
        )
        .all()
    )


@router.put(
    "/{categoria_id}",
    response_model=CategoriaResponse,
)
def editar_categoria(
    categoria_id: int,
    dados: CategoriaCreate,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    categoria = (
        db.query(Categoria)
        .filter(
            Categoria.id == categoria_id,
            Categoria.usuario_id == usuario.id,
        )
        .first()
    )

    if categoria is None:
        raise HTTPException(
            status_code=404,
            detail="Categoria não encontrada.",
        )

    categoria.nome = dados.nome
    categoria.orcamento = dados.orcamento
    categoria.ativa = dados.ativa

    db.commit()
    db.refresh(categoria)

    return categoria