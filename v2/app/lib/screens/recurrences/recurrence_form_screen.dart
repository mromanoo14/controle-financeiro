import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../widgets/common.dart';

class RecurrenceFormScreen extends StatefulWidget {
  const RecurrenceFormScreen({super.key, this.recurrence});

  final Recurrence? recurrence;

  @override
  State<RecurrenceFormScreen> createState() => _RecurrenceFormScreenState();
}

class _RecurrenceFormScreenState extends State<RecurrenceFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Recurrence? _r = widget.recurrence;
  late final _description = TextEditingController(text: _r?.description);
  late final _amount = TextEditingController(text: _r == null ? '' : _r.amount.toStringAsFixed(2).replaceAll('.', ','));
  late final _installments = TextEditingController(text: _r?.installments?.toString() ?? '');
  late TxKind _kind = _r?.kind ?? TxKind.expense;
  late Frequency _frequency = _r?.frequency ?? Frequency.monthly;
  late DateTime _start = _r?.startDate ?? DateTime.now();
  late int? _categoryId = _r?.category?.id;
  late int? _accountId = _r?.accountId;
  late bool _parcelado = _r?.installments != null;
  late final Future<(List<Account>, List<Category>)> _options = () async {
    final api = context.read<FinanceApi>();
    return (await api.accounts(), await api.categories());
  }();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await context.read<FinanceApi>().saveRecurrence(
            id: _r?.id,
            accountId: _accountId,
            categoryId: _categoryId,
            kind: _kind,
            description: _description.text.trim(),
            amount: parseMoney(_amount.text)!,
            frequency: _frequency,
            startDate: _start,
            installments: _parcelado ? int.tryParse(_installments.text) : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir', 'Os lançamentos já registrados serão mantidos.')) return;
    if (!mounted) return;
    try {
      await context.read<FinanceApi>().deleteRecurrence(_r!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_r == null ? 'Nova conta fixa' : 'Editar conta fixa'),
        actions: [if (_r != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: FutureBuilder(
        future: _options,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (accounts, all) = snap.data!;
          final categories = all.where((c) => c.kind == _kind).toList();
          if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;
          return Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_r == null) ...[
                SegmentedButton<TxKind>(
                  segments: const [
                    ButtonSegment(value: TxKind.expense, label: Text('Gasto')),
                    ButtonSegment(value: TxKind.income, label: Text('Receita')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: 'Descrição', hintText: _kind == TxKind.expense ? 'Ex.: Aluguel, Netflix' : 'Ex.: Salário'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _parcelado ? 'Valor da parcela' : 'Valor', prefixText: 'R\$ '),
                validator: (v) => ((parseMoney(v ?? '') ?? 0) <= 0) ? 'Informe o valor' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Repete'),
                items: [for (final f in Frequency.values) DropdownMenuItem(value: f, child: Text(f.label))],
                onChanged: (v) => setState(() => _frequency = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(_r == null ? 'Primeiro vencimento' : 'Início'),
                subtitle: Text(formatDate(_start)),
                enabled: _r == null,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _start = d);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compra parcelada'),
                value: _parcelado,
                onChanged: (v) => setState(() => _parcelado = v),
              ),
              if (_parcelado)
                TextFormField(
                  controller: _installments,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Número de parcelas'),
                  validator: (v) => ((int.tryParse(v ?? '') ?? 0) < 1) ? 'Informe as parcelas' : null,
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Departamento'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem departamento')),
                  for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Conta (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Escolher ao pagar')),
                  for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Salvar')),
            ]),
          );
        },
      ),
    );
  }
}
