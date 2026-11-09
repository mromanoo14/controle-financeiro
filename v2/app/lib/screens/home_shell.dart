import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/data_version.dart';
import 'dashboard/dashboard_screen.dart';
import 'forecast/forecast_screen.dart';
import 'more/more_screen.dart';
import 'transactions/transaction_form_screen.dart';
import 'transactions/transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transações'),
    NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Previsão'),
    NavigationDestination(icon: Icon(Icons.menu), label: 'Mais'),
  ];

  Future<void> _addTransaction() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const TransactionFormScreen()),
    );
    if (saved == true && mounted) context.read<DataVersion>().bump();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onSeeAll: () => setState(() => _index = 1), onSeeForecast: () => setState(() => _index = 2)),
      const TransactionsScreen(),
      const ForecastScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: _index < 2
          ? FloatingActionButton.extended(
              onPressed: _addTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Lançar'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
