import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icons.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _reload = 0;
  TxKind _kind = TxKind.expense;

  Future<void> _edit([Category? category]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(category: category, kind: _kind),
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
      appBar: AppBar(title: const Text('Departamentos')),
      floatingActionButton: FloatingActionButton(onPressed: _edit, tooltip: 'Novo departamento', child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<TxKind>(
            segments: const [
              ButtonSegment(value: TxKind.expense, label: Text('Despesas')),
              ButtonSegment(value: TxKind.income, label: Text('Receitas')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
        ),
        Expanded(
          child: AsyncView<List<Category>>(
            reloadKey: Object.hash(_reload, _kind),
            load: () => api.categories(kind: _kind),
            builder: (context, categories, reload) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                Card(
                  child: Column(children: [
                    for (final c in categories)
                      ListTile(leading: CategoryAvatar.of(c), title: Text(c.name), onTap: () => _edit(c)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category, required this.kind});

  final Category? category;
  final TxKind kind;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final _name = TextEditingController(text: widget.category?.name);
  late String _icon = widget.category?.icon ?? 'category';
  late String _color = widget.category?.color ?? categoryColors.first;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    try {
      await context.read<FinanceApi>().saveCategory(
            id: widget.category?.id,
            name: _name.text.trim(),
            kind: widget.category?.kind ?? widget.kind,
            icon: _icon,
            color: _color,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir departamento', 'Os lançamentos ficarão sem departamento.')) return;
    if (!mounted) return;
    try {
      await context.read<FinanceApi>().deleteCategory(widget.category!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.category == null ? 'Novo departamento' : 'Editar departamento', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 16),
          const Text('Ícone'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in categoryIcons.entries.where((e) => e.key != 'help_outline'))
              ChoiceChip(
                label: Icon(entry.value, size: 20),
                selected: _icon == entry.key,
                onSelected: (_) => setState(() => _icon = entry.key),
              ),
          ]),
          const SizedBox(height: 16),
          const Text('Cor'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in categoryColors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: hexColor(c),
                  child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              ),
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Salvar')),
          if (widget.category != null) TextButton(onPressed: _delete, child: const Text('Excluir departamento')),
        ]),
      ),
    );
  }
}
