class Conta {
  int? id;
  String nome;
  String tipo;
  double saldoInicial;
  bool ativa;

  Conta({
    this.id,
    required this.nome,
    required this.tipo,
    required this.saldoInicial,
    required this.ativa,
  });
}