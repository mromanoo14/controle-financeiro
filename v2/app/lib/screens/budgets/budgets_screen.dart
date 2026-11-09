import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  int _reload = 0;

  Future<void> _edit({Budget? budget}) async {
    final api = context.read<FinanceApi>();
    final categories = await api.categories(kind: TxKind.expense);
    if (!mounted) return;
    int? categoryId = budget?.category.id ?? (categories.isEmpty ? null : categories.first.id);
    final controller = TextEditingController(text: budget?.limit.toStringAsFixed(2).replaceAll('.', ','));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(budget == null ? 'Novo orçamento' : 'Editar orçamento'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: categoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Departamento'),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: budget != null ? null : (v) => setLocal(() => categoryId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Limite mensal', prefixText: 'R\$ '),
            ),
          ]),
          actions: [
            if (budget != null)
              TextButton(
                onPressed: () async {
                  await api.deleteBudget(budget.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Excluir'),
              ),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final value = parseMoney(controller.text);
                if (value == null || value <= 0 || categoryId == null) return;
                try {
                  await api.saveBudget(categoryId!, value);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _reload++);
      context.read<DataVersion>().bump();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos do mês')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
      body: AsyncView<List<Budget>>(
        reloadKey: _reload,
        load: api.budgets,
        builder: (context, budgets, reload) {
          if (budgets.isEmpty) {
            return const EmptyState(icon: Icons.savings_outlined, message: 'Defina um limite mensal para os departamentos que quer controlar.');
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final b in budgets)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _edit(budget: b),
                  leading: CategoryAvatar.of(b.category),
                  title: Text(b.category.name),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: b.progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        color: b.progress > 1 ? AppColors.expense : (b.progress > 0.8 ? AppColors.warning : AppColors.income),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${money(b.spent)} de ${money(b.limit)}'),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
