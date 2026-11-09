import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../widgets/common.dart';
import '../accounts/accounts_screen.dart';

/// Cadastro/edição manual de gasto ou receita.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.transaction?.description);
  late final _amount = TextEditingController(
      text: widget.transaction == null ? '' : widget.transaction!.amount.toStringAsFixed(2).replaceAll('.', ','));
  late final _notes = TextEditingController(text: widget.transaction?.notes);
  late TxKind _kind = widget.transaction?.kind ?? TxKind.expense;
  late DateTime _date = widget.transaction?.date ?? DateTime.now();
  late int? _accountId = widget.transaction?.accountId;
  late int? _categoryId = widget.transaction?.category?.id;
  bool _saving = false;

  late Future<(List<Account>, List<Category>)> _options = _loadOptions();

  bool get _editing => widget.transaction != null;

  Future<(List<Account>, List<Category>)> _loadOptions() async {
    final api = context.read<FinanceApi>();
    final accounts = await api.accounts();
    final categories = await api.categories();
    if (_accountId == null && accounts.isNotEmpty) _accountId = accounts.first.id;
    return (accounts, categories);
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<FinanceApi>().saveTransaction(
            id: widget.transaction?.id,
            accountId: _accountId!,
            categoryId: _categoryId,
            kind: _kind,
            amount: parseMoney(_amount.text)!,
            description: _description.text.trim(),
            date: _date,
            notes: _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir lançamento', 'Deseja excluir "${widget.transaction!.description}"?')) return;
    if (!mounted) return;
    try {
      await context.read<FinanceApi>().deleteTransaction(widget.transaction!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [if (_editing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Excluir')],
      ),
      body: FutureBuilder(
        future: _options,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _options = _loadOptions()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (accounts, allCategories) = snap.data!;
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance,
              message: 'Cadastre uma conta (ex.: Nubank, Carteira) antes de lançar.',
              action: FilledButton(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen()));
                  setState(() => _options = _loadOptions());
                },
                child: const Text('Cadastrar conta'),
              ),
            );
          }
          final categories = allCategories.where((c) => c.kind == _kind).toList();
          if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;

          return Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              SegmentedButton<TxKind>(
                segments: const [
                  ButtonSegment(value: TxKind.expense, label: Text('Despesa'), icon: Icon(Icons.arrow_upward)),
                  ButtonSegment(value: TxKind.income, label: Text('Receita'), icon: Icon(Icons.arrow_downward)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: !_editing,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                validator: (v) {
                  final value = parseMoney(v ?? '');
                  return (value == null || value <= 0) ? 'Informe um valor maior que zero' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Mercado, Uber, Aluguel'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe uma descrição' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Departamento'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Automático (pela descrição)')),
                  for (final c in categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(children: [CategoryAvatar.of(c, size: 24), const SizedBox(width: 8), Text(c.name)]),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              if (_editing && _categoryId != widget.transaction!.category?.id)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text('O app vai lembrar dessa escolha para lançamentos parecidos.', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Conta'),
                items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Escolha a conta' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Data'),
                subtitle: Text(formatDate(_date)),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações (opcional)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar'),
              ),
            ]),
          );
        },
      ),
    );
  }
}
