from sqlalchemy.orm import Session

from models import Usuario
from security.password import gerar_hash, verificar_senha
from security.jwt import criar_token


def criar_usuario(
    db: Session,
    nome: str,
    email: str,
    senha: str,
):
    usuario = Usuario(
        nome=nome,
        email=email,
        senha_hash=gerar_hash(senha),
    )

    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    return usuario


def buscar_usuario_por_email(
    db: Session,
    email: str,
):
    return (
        db.query(Usuario)
        .filter(Usuario.email == email)
        .first()
    )


def buscar_usuario_por_id(
    db: Session,
    usuario_id: int,
):
    return (
        db.query(Usuario)
        .filter(Usuario.id == usuario_id)
        .first()
    )


def autenticar_usuario(
    db: Session,
    email: str,
    senha: str,
):
    usuario = buscar_usuario_por_email(
        db,
        email,
    )

    if usuario is None:
        return None

    if not verificar_senha(
        senha,
        usuario.senha_hash,
    ):
        return None

    return {
        "usuario": usuario,
        "access_token": criar_token(usuario.id),
        "token_type": "bearer",
    }