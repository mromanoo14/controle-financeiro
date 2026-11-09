import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  int _reload = 0;

  Future<void> _edit([Account? account]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountForm(account: account),
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
      appBar: AppBar(title: const Text('Contas e cartões')),
      floatingActionButton: FloatingActionButton(onPressed: _edit, tooltip: 'Nova conta', child: const Icon(Icons.add)),
      body: AsyncView<List<Account>>(
        reloadKey: _reload,
        load: api.accounts,
        builder: (context, accounts, reload) {
          if (accounts.isEmpty) {
            return const EmptyState(icon: Icons.account_balance, message: 'Cadastre suas contas, cartões e carteira.');
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Column(children: [
                for (final a in accounts)
                  ListTile(
                    leading: Icon(_icon(a.type)),
                    title: Text(a.name),
                    subtitle: Text([a.type.label, if (a.institution != null) a.institution!, if (a.fromOpenFinance) 'sincronizada'].join(' · ')),
                    trailing: MoneyText(a.balance, style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => _edit(a),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  static IconData _icon(AccountType t) => switch (t) {
        AccountType.checking => Icons.account_balance,
        AccountType.savings => Icons.savings,
        AccountType.creditCard => Icons.credit_card,
        AccountType.wallet => Icons.account_balance_wallet,
        AccountType.investment => Icons.trending_up,
      };
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.account});

  final Account? account;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account?.name);
  late final _institution = TextEditingController(text: widget.account?.institution);
  late final _balance = TextEditingController(
      text: widget.account == null ? '0,00' : widget.account!.initialBalance.toStringAsFixed(2).replaceAll('.', ','));
  late AccountType _type = widget.account?.type ?? AccountType.checking;
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<FinanceApi>().saveAccount(
            id: widget.account?.id,
            name: _name.text.trim(),
            type: _type,
            institution: _institution.text.trim().isEmpty ? null : _institution.text.trim(),
            initialBalance: parseMoney(_balance.text) ?? 0,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir conta', 'Todas as transações desta conta também serão excluídas.')) return;
    if (!mounted) return;
    try {
      await context.read<FinanceApi>().deleteAccount(widget.account!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.account == null ? 'Nova conta' : 'Editar conta', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Nubank, Carteira'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [for (final t in AccountType.values) DropdownMenuItem(value: t, child: Text(t.label))],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _institution, decoration: const InputDecoration(labelText: 'Banco (opcional)')),
          const SizedBox(height: 12),
          TextFormField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Saldo inicial', prefixText: 'R\$ '),
            validator: (v) => parseMoney(v ?? '') == null ? 'Valor inválido' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Salvar')),
          if (widget.account != null)
            TextButton(onPressed: _delete, child: const Text('Excluir conta')),
        ]),
      ),
    );
  }
}
