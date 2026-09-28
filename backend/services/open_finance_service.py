from sqlalchemy.orm import Session

from models import Conta


def sincronizar_conta(
    db: Session,
    usuario_id: int,
    conta_id: int,
):
    conta = (
        db.query(Conta)
        .filter(
            Conta.id == conta_id,
            Conta.usuario_id == usuario_id,
        )
        .first()
    )

    if conta is None:
        raise ValueError("Conta não encontrada.")

    # Integração real com Open Finance será implementada posteriormente.
    return {
        "conta_id": conta.id,
        "conta": conta.nome,
        "status": "aguardando_integracao",
        "mensagem": "Integração Open Finance ainda não configurada.",
    }