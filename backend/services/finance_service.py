from sqlalchemy.orm import Session

from models import Conta, Transacao


def criar_transacao(
    db: Session,
    usuario_id: int,
    conta_id: int,
    categoria_id: int | None,
    descricao: str,
    tipo: str,
    valor: float,
    data,
    forma_pagamento: str,
    observacao: str | None = None,
    recorrente: bool = False,
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

    transacao = Transacao(
        usuario_id=usuario_id,
        conta_id=conta_id,
        categoria_id=categoria_id,
        descricao=descricao,
        tipo=tipo,
        valor=valor,
        data=data,
        forma_pagamento=forma_pagamento,
        observacao=observacao,
        recorrente=recorrente,
    )

    db.add(transacao)
    db.commit()
    db.refresh(transacao)

    return transacao


def listar_transacoes(
    db: Session,
    usuario_id: int,
):
    return (
        db.query(Transacao)
        .filter(Transacao.usuario_id == usuario_id)
        .order_by(Transacao.data.desc())
        .all()
    )


def buscar_transacao(
    db: Session,
    usuario_id: int,
    transacao_id: int,
):
    return (
        db.query(Transacao)
        .filter(
            Transacao.id == transacao_id,
            Transacao.usuario_id == usuario_id,
        )
        .first()
    )


def excluir_transacao(
    db: Session,
    usuario_id: int,
    transacao_id: int,
):
    transacao = buscar_transacao(
        db,
        usuario_id,
        transacao_id,
    )

    if transacao is None:
        return None

    db.delete(transacao)
    db.commit()

    return transacao