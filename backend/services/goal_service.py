from sqlalchemy.orm import Session

from models import Meta


def calcular_progresso_meta(
    db: Session,
    usuario_id: int,
):
    metas = (
        db.query(Meta)
        .filter(Meta.usuario_id == usuario_id)
        .all()
    )

    resultado = []

    for meta in metas:
        if meta.valor_objetivo > 0:
            progresso = meta.valor_atual / meta.valor_objetivo
        else:
            progresso = 0

        if progresso > 1:
            progresso = 1

        resultado.append(
            {
                "id": meta.id,
                "nome": meta.nome,
                "valor_objetivo": meta.valor_objetivo,
                "valor_atual": meta.valor_atual,
                "progresso": progresso,
            }
        )

    return resultado