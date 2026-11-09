import 'package:flutter/material.dart';

import '../core/format.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.year, required this.month, required this.onChanged});

  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  void _shift(int delta) {
    final d = DateTime(year, month + delta);
    onChanged(d.year, d.month);
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Mês anterior'),
      SizedBox(
        width: 160,
        child: Text(monthName(year, month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right), tooltip: 'Próximo mês'),
    ]);
  }
}
