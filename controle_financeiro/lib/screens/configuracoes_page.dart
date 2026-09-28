import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../services/api_service.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() =>
      _ConfiguracoesPageState();
}

class _ConfiguracoesPageState
    extends State<ConfiguracoesPage> {
  final ApiService apiService = ApiService();

  final TextEditingController saldoController =
      TextEditingController();

  List<Categoria> categorias = [];

  // Controllers dos orçamentos
  final Map<int, TextEditingController>
      orcamentoControllers = {};

  bool carregando = true;
  bool salvando = false;

  @override
  void initState() {
    super.initState();

    carregarDados();
  }

  @override
  void dispose() {
    saldoController.dispose();

    for (var controller in orcamentoControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // =========================================================
  // CARREGAR DADOS
  // =========================================================

  Future<void> carregarDados() async {
    try {
      final saldo = await apiService.buscarSaldo();

      final categoriasApi =
          await apiService.listarCategorias();

      saldoController.text = saldo
          .toStringAsFixed(2)
          .replaceAll('.', ',');

      for (var categoria in categoriasApi) {
        if (categoria.id != null) {
          orcamentoControllers[categoria.id!] =
              TextEditingController(
            text: categoria.orcamento
                .toStringAsFixed(2)
                .replaceAll('.', ','),
          );
        }
      }

      setState(() {
        categorias = categoriasApi;
        carregando = false;
      });
    } catch (erro) {
      print('Erro ao carregar configurações: $erro');

      setState(() {
        carregando = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível carregar as configurações.',
          ),
        ),
      );
    }
  }

  // =========================================================
  // CONVERTER VALOR
  // =========================================================

  double? converterValor(String texto) {
    final valor = texto
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();

    return double.tryParse(valor);
  }

  // =========================================================
  // SALVAR ALTERAÇÕES
  // =========================================================

  Future<void> salvarAlteracoes() async {
    final saldo = converterValor(
      saldoController.text,
    );

    if (saldo == null || saldo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Digite um saldo válido.',
          ),
        ),
      );

      return;
    }

    // Valida os orçamentos antes de enviar
    final Map<int, double> novosOrcamentos = {};

    for (var categoria in categorias) {
      if (categoria.id == null) {
        continue;
      }

      final controller =
          orcamentoControllers[categoria.id!];

      if (controller == null) {
        continue;
      }

      final valor = converterValor(
        controller.text,
      );

      if (valor == null || valor < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Digite um orçamento válido para ${categoria.nome}.',
            ),
          ),
        );

        return;
      }

      novosOrcamentos[categoria.id!] = valor;
    }

    setState(() {
      salvando = true;
    });

    try {
      // Atualiza o saldo
      await apiService.atualizarSaldo(saldo);

      // Atualiza os orçamentos
      for (var categoria in categorias) {
        if (categoria.id == null) {
          continue;
        }

        final novoOrcamento =
            novosOrcamentos[categoria.id!];

        if (novoOrcamento == null) {
          continue;
        }

        await apiService.editarCategoria(
          categoria.id!,
          categoria.nome,
          novoOrcamento,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configurações salvas com sucesso!',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (erro) {
      print('Erro ao salvar configurações: $erro');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar as configurações.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  // =========================================================
  // INTERFACE
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações financeiras',
        ),
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
                    'Saldo atual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: saldoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Saldo atual',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Orçamentos por categoria',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Defina quanto você pretende gastar em cada categoria.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 20),

                  ...categorias.map(
                    (categoria) {
                      if (categoria.id == null) {
                        return const SizedBox.shrink();
                      }

                      final controller =
                          orcamentoControllers[
                              categoria.id!];

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child: TextField(
                          controller: controller,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                categoria.nome,
                            prefixText: 'R\$ ',
                            border:
                                const OutlineInputBorder(),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          salvando
                              ? null
                              : salvarAlteracoes,
                      child: salvando
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(),
                            )
                          : const Text(
                              'Salvar alterações',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}