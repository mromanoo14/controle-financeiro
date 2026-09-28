from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database import get_db
from models import Usuario
from security.jwt import verificar_token


security = HTTPBearer()


def obter_usuario_atual(
    credenciais: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    token = credenciais.credentials

    try:
        usuario_id = verificar_token(token)
    except ValueError:
        raise HTTPException(
            status_code=401,
            detail="Token inválido ou expirado.",
        )

    usuario = (
        db.query(Usuario)
        .filter(
            Usuario.id == usuario_id,
            Usuario.ativo == True,
        )
        .first()
    )

    if usuario is None:
        raise HTTPException(
            status_code=401,
            detail="Usuário não encontrado.",
        )

    return usuario