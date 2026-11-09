import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/auth_controller.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';
import '../recurrences/recurrences_screen.dart';
import '../subscription/subscription_screen.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    final version = context.watch<DataVersion>().value;
    final premium = context.select<AuthController, bool>((a) => a.user?.isPremium ?? false);

    return AsyncView<List<MonthForecast>>(
      reloadKey: Object.hash(version, premium),
      load: () async {
        try {
          return await api.forecast(months: premium ? 3 : 1);
        } on ApiException catch (e) {
          if (e.requiresPremium) return api.forecast(months: 1);
          rethrow;
        }
      },
      builder: (context, months, reload) {
        final current = months.first;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('Previsão', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Baseada nos seus gastos fixos e na média dos últimos 3 meses.'),
              const SizedBox(height: 16),
              _Summary(forecast: current),
              if (current.upcoming.isNotEmpty) ...[
                SectionTitle('Próximos vencimentos',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurrencesScreen())),
                      child: const Text('Gerenciar'),
                    )),
                Card(
                  child: Column(children: [
                    for (final item in current.upcoming)
                      ListTile(
                        leading: Icon(item.kind == TxKind.expense ? Icons.event : Icons.payments,
                            color: item.kind == TxKind.expense ? AppColors.expense : AppColors.income),
                        title: Text(item.description),
                        subtitle: Text(formatDate(item.date)),
                        trailing: MoneyText(item.kind == TxKind.expense ? -item.amount : item.amount, showSign: true),
                      ),
                  ]),
                ),
              ],
              const SectionTitle('Por departamento'),
              if (current.byCategory.isEmpty)
                const Card(child: EmptyState(icon: Icons.insights, message: 'Lance alguns gastos ou cadastre contas fixas para ver a previsão.'))
              else
                Card(child: Column(children: [for (final c in current.byCategory) _CategoryRow(item: c)])),
              if (months.length > 1) ...[
                const SectionTitle('Próximos meses'),
                for (final m in months.skip(1))
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(monthName(m.year, m.month)),
                      subtitle: Text('Gastos previstos ${money(m.projectedExpense)} · Renda ${money(m.expectedIncome)}'),
                      trailing: MoneyText(m.projectedBalance, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 16),
                PremiumBanner(
                  message: 'Veja a previsão dos próximos meses no Premium',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.forecast});

  final MonthForecast forecast;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, double value, {bool bold = false, bool colored = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
            MoneyText(value, colored: colored, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(monthName(forecast.year, forecast.month), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          row('Renda esperada', forecast.expectedIncome),
          row('Já gasto', forecast.spentSoFar),
          row('Gasto total previsto', forecast.projectedExpense),
          const Divider(),
          row('Saldo previsto no fim do mês', forecast.projectedBalance, bold: true, colored: true),
          if (forecast.expectedIncome == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Dica: informe seu salário em Mais > Perfil para uma previsão mais precisa.', style: TextStyle(fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final CategoryForecast item;

  @override
  Widget build(BuildContext context) {
    final limit = item.budget ?? item.projected;
    final progress = limit == 0 ? 0.0 : (item.spent / limit).clamp(0.0, 1.0);
    final color = item.overBudget ? AppColors.expense : hexColor(item.color);
    final details = [
      'gasto ${money(item.spent)}',
      if (item.fixed > 0) 'fixos ${money(item.fixed)}',
      if (item.variable > 0) 'estimado ${money(item.variable)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        CategoryAvatar(icon: item.icon, color: item.color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(money(item.projected), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, color: color, backgroundColor: color.withValues(alpha: 0.15)),
            ),
            const SizedBox(height: 4),
            Text(details, style: Theme.of(context).textTheme.bodySmall),
            if (item.budget != null)
              Text(
                item.overBudget ? 'Previsão acima do orçamento de ${money(item.budget!)}' : 'Orçamento ${money(item.budget!)}',
                style: TextStyle(fontSize: 12, color: item.overBudget ? AppColors.expense : null),
              ),
          ]),
        ),
      ]),
    );
  }
}
