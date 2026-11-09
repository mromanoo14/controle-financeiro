import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/auth_controller.dart';
import '../../state/data_version.dart';
import '../../widgets/common.dart';
import '../subscription/subscription_screen.dart';
import 'pluggy_connect_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  int _reload = 0;
  bool _busy = false;

  bool get _webviewSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void _changed(SyncResult result) {
    setState(() => _reload++);
    context.read<DataVersion>().bump();
    showMessage(context, '${result.accounts} conta(s) sincronizada(s), ${result.imported} lançamento(s) importado(s).');
  }

  Future<void> _connect({String? itemId}) async {
    final api = context.read<FinanceApi>();
    setState(() => _busy = true);
    try {
      final token = await api.connectToken(itemId: itemId);
      String? newItemId;
      if (token.provider == 'mock') {
        // Backend em modo simulado: cria uma conexão de exemplo.
        newItemId = itemId ?? 'mock-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        if (!_webviewSupported) {
          if (mounted) showMessage(context, 'A conexão com bancos está disponível no app para celular.');
          return;
        }
        if (!mounted) return;
        newItemId = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => PluggyConnectScreen(connectToken: token.token)),
        );
      }
      if (newItemId == null) return;
      final result = await api.addConnection(newItemId);
      if (mounted) _changed(result);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync(BankConnection c) async {
    setState(() => _busy = true);
    try {
      final result = await context.read<FinanceApi>().syncConnection(c.id);
      if (mounted) _changed(result);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(BankConnection c) async {
    if (!await confirm(context, 'Desconectar banco', 'As contas e lançamentos já importados serão mantidos.', action: 'Desconectar')) return;
    if (!mounted) return;
    await context.read<FinanceApi>().deleteConnection(c.id);
    if (mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    final premium = context.select<AuthController, bool>((a) => a.user?.isPremium ?? false);
    return Scaffold(
      appBar: AppBar(title: const Text('Bancos conectados')),
      floatingActionButton: premium
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _connect,
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_link),
              label: const Text('Conectar banco'),
            )
          : null,
      body: AsyncView<List<BankConnection>>(
        reloadKey: _reload,
        load: api.connections,
        builder: (context, connections, reload) => ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
            'Conecte suas contas via Open Finance e seus gastos entram sozinhos, já separados por departamento. '
            'A conexão é feita em ambiente seguro do banco e você pode revogar quando quiser.',
          ),
          const SizedBox(height: 16),
          if (!premium)
            PremiumBanner(
              message: 'Conexão automática com bancos é um recurso Premium',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
            ),
          if (connections.isEmpty && premium)
            const EmptyState(icon: Icons.account_balance, message: 'Nenhum banco conectado ainda.'),
          for (final c in connections)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(c.status == 'active' ? Icons.check_circle : Icons.error_outline,
                    color: c.status == 'active' ? Colors.green : Colors.orange),
                title: Text(c.institution ?? 'Banco'),
                subtitle: Text(c.error ??
                    (c.lastSyncedAt == null ? 'Aguardando sincronização' : 'Atualizado em ${formatDate(c.lastSyncedAt!)}')),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'sync' => _sync(c),
                    _ => _remove(c),
                  },
                  itemBuilder: (_) => [
                    if (premium) const PopupMenuItem(value: 'sync', child: Text('Sincronizar agora')),
                    const PopupMenuItem(value: 'remove', child: Text('Desconectar')),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
