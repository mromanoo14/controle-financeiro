class Transacao {
  int? id;
  int contaId;
  int? categoriaId;
  String descricao;
  String tipo;
  double valor;
  DateTime data;
  String formaPagamento;
  String? observacao;
  bool recorrente;

  Transacao({
    this.id,
    required this.contaId,
    this.categoriaId,
    required this.descricao,
    required this.tipo,
    required this.valor,
    required this.data,
    required this.formaPagamento,
    this.observacao,
    required this.recorrente,
  });
}