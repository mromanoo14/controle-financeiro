import 'package:flutter/material.dart';
import '../models/gastos.dart';
import '../theme/app_theme.dart';

class CategoriaCard extends StatelessWidget {
  final String categoria;
  final IconData icone;
  final double totalGasto;
  final double orcamento;
  final List<Gasto> gastos;
  final String Function(double) formatarDinheiro;
  final void Function(Gasto) onExcluir;
  final void Function(Gasto) onEditar;

  const CategoriaCard({
    super.key,
    required this.categoria,
    required this.icone,
    required this.totalGasto,
    required this.orcamento,
    required this.gastos,
    required this.formatarDinheiro,
    required this.onExcluir,
    required this.onEditar,
  });

  double get progresso {
    if (orcamento <= 0) return 0;

    final valor = totalGasto / orcamento;

    if (valor > 1) return 1;

    return valor;
  }

  double get restante {
    return orcamento - totalGasto;
  }

  Color get corProgresso {
    if (orcamento <= 0) {
      return AppTheme.textSecondary;
    }

    if (totalGasto > orcamento) {
      return AppTheme.danger;
    }

    if (totalGasto >= orcamento * 0.8) {
      return AppTheme.warning;
    }

    return AppTheme.primary;
  }

  String formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // CABEÇALHO
          // ==========================================

          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icone,
                  color: AppTheme.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoria,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${gastos.length} movimentação${gastos.length == 1 ? '' : 'ões'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                formatarDinheiro(totalGasto),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ==========================================
          // ORÇAMENTO
          // ==========================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orçamento utilizado',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),

              Text(
                '${(progresso * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: corProgresso,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ==========================================
          // BARRA DE PROGRESSO
          // ==========================================

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor:
                  const Color(0xFFE5E7EB),
              color: corProgresso,
            ),
          ),

          const SizedBox(height: 10),

          // ==========================================
          // RESTANTE
          // ==========================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                restante >= 0
                    ? 'Disponível'
                    : 'Acima do orçamento',
                style: TextStyle(
                  fontSize: 13,
                  color: restante >= 0
                      ? AppTheme.textSecondary
                      : AppTheme.danger,
                ),
              ),

              Text(
                formatarDinheiro(restante.abs()),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: restante >= 0
                      ? AppTheme.success
                      : AppTheme.danger,
                ),
              ),
            ],
          ),

          // ==========================================
          // MOVIMENTAÇÕES
          // ==========================================

          if (gastos.isNotEmpty) ...[
            const SizedBox(height: 16),

            const Divider(
              height: 1,
              color: Color(0xFFE5E7EB),
            ),

            const SizedBox(height: 8),

            ...gastos.map(
              (gasto) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,

                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FB),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 19,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  title: Text(
                    gasto.descricao,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  subtitle: Text(
                    '${formatarData(gasto.data)} • ${gasto.formaPagamento}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatarDinheiro(gasto.valor),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                        ),
                        onSelected: (opcao) {
                          if (opcao == 'editar') {
                            onEditar(gasto);
                          }

                          if (opcao == 'excluir') {
                            onExcluir(gasto);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'excluir',
                            child: Row(
                              children: [
                                Icon(Icons.delete),
                                SizedBox(width: 8),
                                Text('Excluir'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}