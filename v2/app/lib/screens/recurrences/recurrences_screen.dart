import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';
import 'recurrence_form_screen.dart';

/// Gastos/receitas fixos e compras parceladas — base da previsão.
class RecurrencesScreen extends StatefulWidget {
  const RecurrencesScreen({super.key});

  @override
  State<RecurrencesScreen> createState() => _RecurrencesScreenState();
}

class _RecurrencesScreenState extends State<RecurrencesScreen> {
  int _reload = 0;

  void _changed() {
    setState(() => _reload++);
    context.read<DataVersion>().bump();
  }

  Future<void> _edit([Recurrence? rec]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => RecurrenceFormScreen(recurrence: rec)));
    if (saved == true && mounted) _changed();
  }

  Future<void> _pay(Recurrence rec) async {
    try {
      final api = context.read<FinanceApi>();
      int? accountId = rec.accountId;
      if (accountId == null) {
        final accounts = await api.accounts();
        if (!mounted) return;
        accountId = await showDialog<int>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('De qual conta saiu/entrou?'),
            children: [for (final a in accounts) SimpleDialogOption(onPressed: () => Navigator.pop(context, a.id), child: Text(a.name))],
          ),
        );
        if (accountId == null) return;
      }
      await api.payRecurrence(rec.id, date: rec.nextDate, accountId: accountId);
      if (!mounted) return;
      showMessage(context, rec.kind == TxKind.expense ? 'Pagamento registrado.' : 'Recebimento registrado.');
      _changed();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    return Scaffold(
      appBar: AppBar(title: const Text('Contas fixas e parcelas')),
      floatingActionButton: FloatingActionButton(onPressed: _edit, tooltip: 'Nova', child: const Icon(Icons.add)),
      body: AsyncView<List<Recurrence>>(
        reloadKey: _reload,
        load: api.recurrences,
        builder: (context, items, reload) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat,
              message: 'Cadastre aluguel, salário, assinaturas e compras parceladas para o app prever seus gastos.',
            );
          }
          final monthlyOut = items.where((r) => r.kind == TxKind.expense && r.frequency == Frequency.monthly).fold<double>(0, (s, r) => s + r.amount);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            Text('Fixos mensais: ${money(monthlyOut)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                for (final r in items)
                  ListTile(
                    leading: CategoryAvatar.of(r.category),
                    title: Text(r.description),
                    subtitle: Text([
                      r.frequency.label,
                      if (r.installments != null) '${r.installments}x',
                      if (r.nextDate != null) 'próximo ${formatDate(r.nextDate!)}' else 'encerrada',
                    ].join(' · ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      MoneyText(r.kind == TxKind.expense ? -r.amount : r.amount),
                      if (r.nextDate != null)
                        IconButton(
                          tooltip: r.kind == TxKind.expense ? 'Marcar como pago' : 'Marcar como recebido',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _pay(r),
                        ),
                    ]),
                    onTap: () => _edit(r),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
