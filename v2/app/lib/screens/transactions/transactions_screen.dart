import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';
import '../../widgets/month_selector.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _now = DateTime.now();
  late int _year = _now.year;
  late int _month = _now.month;
  TxKind? _kind;
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _search = text));
  }

  Future<void> _open(Transaction tx) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TransactionFormScreen(transaction: tx)));
    if (saved == true && mounted) context.read<DataVersion>().bump();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    final version = context.watch<DataVersion>().value;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          onChanged: _onSearch,
          decoration: const InputDecoration(hintText: 'Buscar lançamentos', prefixIcon: Icon(Icons.search), isDense: true),
        ),
      ),
      MonthSelector(year: _year, month: _month, onChanged: (y, m) => setState(() {
            _year = y;
            _month = m;
          })),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SegmentedButton<TxKind?>(
          segments: const [
            ButtonSegment(value: null, label: Text('Todos')),
            ButtonSegment(value: TxKind.expense, label: Text('Despesas')),
            ButtonSegment(value: TxKind.income, label: Text('Receitas')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: AsyncView<TransactionPage>(
          reloadKey: Object.hash(version, _year, _month, _kind, _search),
          load: () => api.transactions(year: _year, month: _month, kind: _kind, search: _search, limit: 500),
          builder: (context, page, reload) {
            if (page.items.isEmpty) {
              return const EmptyState(icon: Icons.receipt_long, message: 'Nenhum lançamento encontrado.');
            }
            final total = page.items.fold<double>(0, (s, t) => s + t.signedAmount);
            // Agrupa por dia.
            final groups = <DateTime, List<Transaction>>{};
            for (final tx in page.items) {
              groups.putIfAbsent(tx.date, () => []).add(tx);
            }
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      Text('${page.total} lançamentos'),
                      const Spacer(),
                      const Text('Resultado: '),
                      MoneyText(total, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                      child: Text(formatDate(entry.key), style: Theme.of(context).textTheme.labelLarge),
                    ),
                    Card(child: Column(children: [for (final tx in entry.value) TransactionTile(tx: tx, onTap: () => _open(tx))])),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }
}
