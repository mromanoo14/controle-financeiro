from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Usuario
from security.auth import obter_usuario_atual
from services.open_finance_service import sincronizar_conta


router = APIRouter(
    prefix="/open-finance",
    tags=["Open Finance"],
)


@router.post(
    "/contas/{conta_id}/sincronizar",
)
def sincronizar(
    conta_id: int,
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(obter_usuario_atual),
):
    try:
        return sincronizar_conta(
            db=db,
            usuario_id=usuario.id,
            conta_id=conta_id,
        )

    except ValueError as erro:
        raise HTTPException(
            status_code=404,
            detail=str(erro),
        )