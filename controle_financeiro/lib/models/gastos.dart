class Gasto {
  int? id;
  String descricao;
  String categoria;
  double valor;
  DateTime data;
  String formaPagamento;

  Gasto({
    this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    required this.formaPagamento,
  });
}