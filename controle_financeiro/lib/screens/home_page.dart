import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/conta.dart';
import '../models/transacao.dart';
import '../services/api_service.dart';
import '../widgets/balance_card.dart';

import '../widgets/monthly_expense_card.dart';
import 'configuracoes_page.dart';

class HomePage extends StatefulWidget {
  final ApiService apiService;

  const HomePage({
    super.key,
    required this.apiService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiService apiService;

  // =========================================================
  // DADOS
  // =========================================================

  double saldoAtual = 0;

  DateTime mesSelecionado = DateTime(2026, 9);

  bool carregando = true;

  List<Categoria> categorias = [];

  List<Conta> contas = [];

  List<Transacao> transacoes = [];

  final List<String> formasPagamento = [
    'Boleto',
    'Cartão de crédito',
    'Débito',
    'Pix',
    'Dinheiro',
  ];

  // =========================================================
  // INICIALIZAÇÃO
  // =========================================================

  @override
  void initState() {
    super.initState();

    apiService = widget.apiService;

    carregarDados();
  }

  // =========================================================
  // CARREGAR DADOS
  // =========================================================

  Future<void> carregarDados() async {
    try {
      final contasApi =
          await apiService.listarContas();

      final transacoesApi =
          await apiService.listarTransacoes();

      final categoriasApi =
          await apiService.listarCategorias();

      double saldo = 0;

      for (final conta in contasApi) {
        saldo += conta.saldoInicial;
      }

      for (final transacao in transacoesApi) {
        if (transacao.tipo == 'receita') {
          saldo += transacao.valor;
        } else if (transacao.tipo == 'despesa') {
          saldo -= transacao.valor;
        }
      }

      if (!mounted) return;

      setState(() {
        contas = contasApi;
        transacoes = transacoesApi;
        categorias = categoriasApi;
        saldoAtual = saldo;
        carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar os dados: $erro',
          ),
        ),
      );
    }
  }

  // =========================================================
  // CATEGORIAS
  // =========================================================

  List<String> obterNomesCategorias() {
    return categorias
        .map((categoria) => categoria.nome)
        .toList();
  }

  IconData obterIcone(String categoria) {
    switch (categoria) {
      case 'Alimentação':
        return Icons.restaurant;

      case 'Lazer':
        return Icons.sports_esports;

      case 'Carro':
        return Icons.directions_car;

      case 'Estudos':
        return Icons.school;

      case 'Contas':
        return Icons.receipt_long;

      case 'Saúde':
        return Icons.health_and_safety;

      default:
        return Icons.category;
    }
  }

  // =========================================================
  // TRANSAÇÕES DO MÊS
  // =========================================================

  List<Transacao> obterTransacoesDoMes() {
    return transacoes.where((transacao) {
      return transacao.data.year == mesSelecionado.year &&
          transacao.data.month == mesSelecionado.month;
    }).toList();
  }

  // =========================================================
  // TOTAL DE DESPESAS
  // =========================================================

  double calcularTotalGastos() {
    double total = 0;

    for (final transacao in obterTransacoesDoMes()) {
      if (transacao.tipo == 'despesa') {
        total += transacao.valor;
      }
    }

    return total;
  }

  // =========================================================
  // TOTAL POR CATEGORIA
  // =========================================================

  double calcularTotalCategoria(String categoria) {
    double total = 0;

    for (final transacao in obterTransacoesDoMes()) {
      if (transacao.tipo != 'despesa') {
        continue;
      }

      final categoriaEncontrada = categorias
          .where(
            (item) => item.id == transacao.categoriaId,
          )
          .firstOrNull;

      if (categoriaEncontrada?.nome == categoria) {
        total += transacao.valor;
      }
    }

    return total;
  }

  // =========================================================
  // TRANSAÇÕES DE UMA CATEGORIA
  // =========================================================

  List<Transacao> obterTransacoesCategoria(
    int? categoriaId,
  ) {
    return obterTransacoesDoMes()
        .where(
          (transacao) =>
              transacao.tipo == 'despesa' &&
              transacao.categoriaId == categoriaId,
        )
        .toList();
  }

  // =========================================================
  // ORÇAMENTO TOTAL
  // =========================================================

  double calcularOrcamentoTotal() {
    double total = 0;

    for (final categoria in categorias) {
      total += categoria.orcamento;
    }

    return total;
  }

  // =========================================================
  // DISPONÍVEL PARA GASTAR
  // =========================================================

  double calcularDisponivel() {
    return saldoAtual - calcularTotalGastos();
  }

  // =========================================================
  // FORMATAÇÃO
  // =========================================================

  String formatarDinheiro(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return meses[mes - 1];
  }

  // =========================================================
  // NAVEGAÇÃO DE MÊS
  // =========================================================

  void mesAnterior() {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month - 1,
      );
    });
  }

  void proximoMes() {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month + 1,
      );
    });
  }

  // =========================================================
  // INTERFACE
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Controle Financeiro',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () async {
              final resultado = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const ConfiguracoesPage(),
                ),
              );

              if (resultado == true) {
                carregarDados();
              }
            },
          ),
        ],
      ),

      body: carregando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Olá! 👋',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // MÊS
                  // =================================================

                  Card(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: mesAnterior,
                          icon: const Icon(
                            Icons.chevron_left,
                          ),
                        ),

                        Text(
                          '${nomeMes(mesSelecionado.month)} '
                          '${mesSelecionado.year}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        IconButton(
                          onPressed: proximoMes,
                          icon: const Icon(
                            Icons.chevron_right,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // SALDO
                  // =================================================

                  BalanceCard(
                    saldo: saldoAtual,
                    disponivel: calcularDisponivel(),
                    formatarDinheiro:
                        formatarDinheiro,
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // GASTOS DO MÊS
                  // =================================================

                  MonthlyExpenseCard(
                    mes: nomeMes(
                      mesSelecionado.month,
                    ),
                    totalGasto:
                        calcularTotalGastos(),
                    orcamentoTotal:
                        calcularOrcamentoTotal(),
                    formatarDinheiro:
                        formatarDinheiro,
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // CATEGORIAS
                  // =================================================

                  const Text(
                    'Gastos por setor',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ...categorias.map(
                    (categoria) {
                      final gastosCategoria =
                          obterTransacoesCategoria(
                        categoria.id,
                      );

                      return Container(
                        margin:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        padding:
                            const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFFE5E7EB,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  obterIcone(
                                    categoria.nome,
                                  ),
                                  color: Colors.blue,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Text(
                                    categoria.nome,
                                    style:
                                        const TextStyle(
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),

                                Text(
                                  formatarDinheiro(
                                    calcularTotalCategoria(
                                      categoria.nome,
                                    ),
                                  ),
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            if (gastosCategoria
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 12,
                              ),

                              ...gastosCategoria.map(
                                (transacao) {
                                  return ListTile(
                                    contentPadding:
                                        EdgeInsets.zero,
                                    title: Text(
                                      transacao
                                          .descricao,
                                    ),
                                    subtitle: Text(
                                      '${transacao.data.day.toString().padLeft(2, '0')}/'
                                      '${transacao.data.month.toString().padLeft(2, '0')}/'
                                      '${transacao.data.year}'
                                      ' • '
                                      '${transacao.formaPagamento}',
                                    ),
                                    trailing: Text(
                                      formatarDinheiro(
                                        transacao.valor,
                                      ),
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}