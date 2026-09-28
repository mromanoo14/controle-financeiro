from sqlalchemy.orm import Session

from models import Investimento


def calcular_investimentos(
    db: Session,
    usuario_id: int,
):
    investimentos = (
        db.query(Investimento)
        .filter(
            Investimento.usuario_id == usuario_id,
            Investimento.ativo == True,
        )
        .all()
    )

    total_investido = sum(
        investimento.valor_investido
        for investimento in investimentos
    )

    return {
        "total_investido": total_investido,
        "investimentos": [
            {
                "id": investimento.id,
                "nome": investimento.nome,
                "tipo": investimento.tipo,
                "valor_investido": investimento.valor_investido,
            }
            for investimento in investimentos
        ],
    }