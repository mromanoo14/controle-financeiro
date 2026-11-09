import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../services/finance_api.dart';
import '../../state/auth_controller.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _user = context.read<AuthController>().user;
  late final _name = TextEditingController(text: _user?.name);
  late final _income = TextEditingController(text: _user?.monthlyIncome?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<FinanceApi>().updateMe(name: _name.text.trim(), monthlyIncome: parseMoney(_income.text));
      if (!mounted) return;
      await context.read<AuthController>().refreshUser();
      if (!mounted) return;
      context.read<DataVersion>().bump();
      showMessage(context, 'Perfil atualizado.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Senha atual')),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Nova senha (mín. 8)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Alterar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FinanceApi>().changePassword(current.text, next.text);
      if (mounted) showMessage(context, 'Senha alterada.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteAccount() async {
    if (!await confirm(context, 'Excluir minha conta',
        'Todos os seus dados serão apagados permanentemente. Essa ação não pode ser desfeita.', action: 'Excluir tudo')) {
      return;
    }
    if (!mounted) return;
    final auth = context.read<AuthController>();
    try {
      await context.read<FinanceApi>().deleteMe();
      await auth.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome')),
        const SizedBox(height: 12),
        TextField(
          controller: _income,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Salário / renda mensal',
            prefixText: 'R\$ ',
            helperText: 'Usado para prever quanto vai sobrar no fim do mês',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Salvar')),
        const SizedBox(height: 24),
        Text(_user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lock_reset), title: const Text('Alterar senha'), onTap: _changePassword),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
          title: Text('Excluir minha conta e dados', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: _deleteAccount,
        ),
      ]),
    );
  }
}
