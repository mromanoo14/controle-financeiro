import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/finance_api.dart';
import '../../state/auth_controller.dart';
import '../../widgets/common.dart';

/// Tela de assinatura (paywall).
///
/// Em desenvolvimento usa o provedor simulado do backend. Para publicar nas
/// lojas, troque `_buy` pela compra via Google Play Billing / Apple IAP
/// (pacote `in_app_purchase` ou RevenueCat) e envie o comprovante ao backend.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _reload = 0;
  bool _busy = false;

  Future<void> _buy(Plan plan) async {
    setState(() => _busy = true);
    try {
      await context.read<FinanceApi>().purchase(
            platform: 'mock',
            productId: plan.id,
            token: 'mock-${DateTime.now().millisecondsSinceEpoch}',
          );
      if (!mounted) return;
      await context.read<AuthController>().refreshUser();
      if (!mounted) return;
      showMessage(context, 'Assinatura ativada!');
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (!await confirm(context, 'Cancelar assinatura', 'Você continua com acesso Premium até o fim do período pago.', action: 'Cancelar assinatura')) {
      return;
    }
    if (!mounted) return;
    try {
      await context.read<FinanceApi>().cancelSubscription();
      if (!mounted) return;
      await context.read<AuthController>().refreshUser();
      setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<FinanceApi>();
    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura')),
      body: AsyncView<(SubscriptionInfo, List<Plan>)>(
        reloadKey: _reload,
        load: () async => (await api.subscription(), await api.plans()),
        builder: (context, data, reload) {
          final (sub, plans) = data;
          final scheme = Theme.of(context).colorScheme;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              color: sub.isPremium ? scheme.primaryContainer : null,
              child: ListTile(
                leading: Icon(sub.isPremium ? Icons.workspace_premium : Icons.lock_outline),
                title: Text(switch (sub.status) {
                  'trial' => sub.isPremium ? 'Período de teste' : 'Teste encerrado',
                  'active' => 'Premium ativo',
                  'canceled' => 'Assinatura cancelada',
                  _ => 'Plano gratuito',
                }),
                subtitle: Text(switch (sub.status) {
                  'trial' when sub.trialEndsAt != null => 'Até ${formatDate(sub.trialEndsAt!)}',
                  'active' || 'canceled' when sub.endsAt != null => 'Acesso até ${formatDate(sub.endsAt!)}',
                  _ => 'Lançamentos manuais e previsão do mês',
                }),
              ),
            ),
            const SizedBox(height: 16),
            for (final plan in plans)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('${money(plan.priceCents / 100)} / mês', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    for (final f in plan.features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [Icon(Icons.check, color: scheme.primary, size: 20), const SizedBox(width: 8), Expanded(child: Text(f))]),
                      ),
                    const SizedBox(height: 16),
                    if (sub.status != 'active')
                      FilledButton(onPressed: _busy ? null : () => _buy(plan), child: const Text('Assinar')),
                  ]),
                ),
              ),
            if (sub.status == 'active') ...[
              const SizedBox(height: 8),
              TextButton(onPressed: _cancel, child: const Text('Cancelar assinatura')),
            ],
            const SizedBox(height: 8),
            Text('Cobrança mensal pela loja de aplicativos. Cancele quando quiser.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ]);
        },
      ),
    );
  }
}
