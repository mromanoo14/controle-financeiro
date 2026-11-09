import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../../widgets/common.dart';
import '../accounts/accounts_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../open_finance/connections_screen.dart';
import '../profile/profile_screen.dart';
import '../recurrences/recurrences_screen.dart';
import '../subscription/subscription_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    Widget item(IconData icon, String title, Widget page, {String? subtitle}) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(page),
        );

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (user != null)
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase())),
            title: Text(user.name),
            subtitle: Text(user.email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(const ProfileScreen()),
          ),
        ),
      const SizedBox(height: 12),
      if (user != null && !user.isPremium)
        PremiumBanner(message: 'Assine o Premium e conecte seus bancos', onTap: () => go(const SubscriptionScreen())),
      const SectionTitle('Organização'),
      Card(
        child: Column(children: [
          item(Icons.account_balance_wallet_outlined, 'Contas e cartões', const AccountsScreen()),
          item(Icons.category_outlined, 'Departamentos (categorias)', const CategoriesScreen()),
          item(Icons.event_repeat, 'Contas fixas e parcelas', const RecurrencesScreen(), subtitle: 'Aluguel, salário, assinaturas...'),
          item(Icons.savings_outlined, 'Orçamentos', const BudgetsScreen(), subtitle: 'Limite mensal por departamento'),
        ]),
      ),
      const SectionTitle('Automação'),
      Card(
        child: Column(children: [
          item(Icons.link, 'Conectar bancos (Open Finance)', const ConnectionsScreen()),
          item(Icons.workspace_premium_outlined, 'Assinatura', const SubscriptionScreen(),
              subtitle: user == null ? null : (user.isPremium ? (user.onTrial ? 'Período de teste' : 'Premium ativo') : 'Plano gratuito')),
        ]),
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sair'),
          onTap: () async {
            if (await confirm(context, 'Sair', 'Deseja sair da sua conta?', action: 'Sair')) {
              await auth.signOut();
            }
          },
        ),
      ),
    ]);
  }
}
