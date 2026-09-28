from sqlalchemy.orm import Session

from models import Categoria, Transacao


def calcular_orcamento(
    db: Session,
    usuario_id: int,
):
    categorias = (
        db.query(Categoria)
        .filter(
            Categoria.usuario_id == usuario_id,
            Categoria.ativa == True,
        )
        .all()
    )

    resultado = []

    for categoria in categorias:
        total_gasto = (
            db.query(Transacao)
            .filter(
                Transacao.usuario_id == usuario_id,
                Transacao.categoria_id == categoria.id,
                Transacao.tipo == "despesa",
            )
            .all()
        )

        gasto = sum(transacao.valor for transacao in total_gasto)

        resultado.append(
            {
                "categoria_id": categoria.id,
                "categoria": categoria.nome,
                "orcamento": categoria.orcamento,
                "gasto": gasto,
                "disponivel": categoria.orcamento - gasto,
            }
        )

    return resultado