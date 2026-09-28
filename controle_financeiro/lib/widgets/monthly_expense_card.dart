import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MonthlyExpenseCard extends StatelessWidget {
  final String mes;
  final double totalGasto;
  final double orcamentoTotal;
  final String Function(double) formatarDinheiro;

  const MonthlyExpenseCard({
    super.key,
    required this.mes,
    required this.totalGasto,
    required this.orcamentoTotal,
    required this.formatarDinheiro,
  });

  @override
  Widget build(BuildContext context) {
    double progresso = 0;

    if (orcamentoTotal > 0) {
      progresso = totalGasto / orcamentoTotal;
    }

    if (progresso > 1) {
      progresso = 1;
    }

    final percentual = orcamentoTotal > 0
        ? (totalGasto / orcamentoTotal * 100).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gastos de $mes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            formatarDinheiro(totalGasto),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'de ${formatarDinheiro(orcamentoTotal)} planejados',
            style: const TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            '$percentual% do orçamento utilizado',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}