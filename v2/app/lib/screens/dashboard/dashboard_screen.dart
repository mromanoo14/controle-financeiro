import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/auth_controller.dart';
import '../../state/data_version.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../transactions/transaction_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSeeAll, required this.onSeeForecast});

  final VoidCallback onSeeAll;
  final VoidCallback onSeeForecast;

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    final version = context.watch<DataVersion>().value;
    final name = context.select<AuthController, String?>((a) => a.user?.name.split(' ').first);

    return AsyncView<(Dashboard, List<MonthSummary>)>(
      reloadKey: version,
      load: () async => (await api.dashboard(), await api.monthlyHistory(months: 6)),
      builder: (context, data, reload) {
        final (dash, history) = data;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text('Olá${name != null ? ', $name' : ''}!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(monthName(dash.month.year, dash.month.month), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              _BalanceCard(dash: dash),
              const SizedBox(height: 12),
              _ForecastCard(forecast: dash.forecast, onTap: onSeeForecast),
              SectionTitle('Gastos por departamento'),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: CategoryDonut(items: dash.month.byCategory))),
              if (history.any((m) => m.income > 0 || m.expense > 0)) ...[
                const SectionTitle('Receitas x despesas'),
                Card(child: Padding(padding: const EdgeInsets.fromLTRB(8, 16, 8, 8), child: IncomeExpenseBars(months: history))),
              ],
              SectionTitle('Últimos lançamentos', trailing: TextButton(onPressed: onSeeAll, child: const Text('Ver todos'))),
              Card(
                child: dash.recent.isEmpty
                    ? const EmptyState(icon: Icons.receipt_long, message: 'Toque em "Lançar" para registrar seu primeiro gasto.')
                    : Column(children: [
                        for (final tx in dash.recent)
                          TransactionTile(
                            tx: tx,
                            onTap: () async {
                              final saved = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: tx)),
                              );
                              if (saved == true && context.mounted) context.read<DataVersion>().bump();
                            },
                          ),
                      ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.dash});

  final Dashboard dash;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saldo total', style: TextStyle(color: onPrimary.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(money(dash.totalBalance), style: TextStyle(color: onPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Mini(label: 'Receitas do mês', value: dash.month.income, icon: Icons.arrow_downward, color: onPrimary)),
            Expanded(child: _Mini(label: 'Despesas do mês', value: dash.month.expense, icon: Icons.arrow_upward, color: onPrimary)),
          ]),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final double value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      CircleAvatar(radius: 14, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 8),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
          Text(money(value), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.onTap});

  final MonthForecast forecast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = forecast.projectedBalance >= 0;
    final progress = forecast.projectedExpense == 0 ? 0.0 : (forecast.spentSoFar / forecast.projectedExpense).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Previsão para o fim do mês', style: TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right),
            ]),
            const SizedBox(height: 12),
            Text('Gasto até agora ${money(forecast.spentSoFar)} de ${money(forecast.projectedExpense)} previstos'),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 8)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(positive ? Icons.check_circle : Icons.warning_amber, size: 18, color: positive ? AppColors.income : AppColors.expense),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  positive
                      ? 'Deve sobrar ${money(forecast.projectedBalance)}'
                      : 'Pode faltar ${money(forecast.projectedBalance.abs())}',
                  style: TextStyle(color: positive ? AppColors.income : AppColors.expense, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
