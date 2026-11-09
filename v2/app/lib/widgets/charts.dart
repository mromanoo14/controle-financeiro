import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Rosca de gastos por categoria com legenda.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({super.key, required this.items});

  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, i) => s + i.total);
    if (total == 0) {
      return const SizedBox(height: 120, child: EmptyState(icon: Icons.pie_chart_outline, message: 'Nenhum gasto neste mês.'));
    }
    final top = items.take(6).toList();
    final rest = items.skip(6).fold<double>(0, (s, i) => s + i.total);
    return Row(children: [
      SizedBox(
        width: 140,
        height: 140,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 42,
          sections: [
            for (final i in top)
              PieChartSectionData(value: i.total, color: hexColor(i.color), radius: 24, showTitle: false),
            if (rest > 0) PieChartSectionData(value: rest, color: Colors.grey, radius: 24, showTitle: false),
          ],
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final i in top) _Legend(color: hexColor(i.color), name: i.name, value: i.total, pct: i.total / total),
          if (rest > 0) _Legend(color: Colors.grey, name: 'Outras', value: rest, pct: rest / total),
        ]),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.name, required this.value, required this.pct});

  final Color color;
  final String name;
  final double value;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: small, overflow: TextOverflow.ellipsis)),
        Text('${(pct * 100).round()}%', style: small),
      ]),
    );
  }
}

/// Barras de receitas x despesas dos últimos meses.
class IncomeExpenseBars extends StatelessWidget {
  const IncomeExpenseBars({super.key, required this.months});

  final List<MonthSummary> months;

  @override
  Widget build(BuildContext context) {
    final maxY = months.fold<double>(0, (m, s) => [m, s.income, s.expense].reduce((a, b) => a > b ? a : b));
    final outline = Theme.of(context).colorScheme.outline;
    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, _, rod, _) => BarTooltipItem(money(rod.toY), const TextStyle(color: Colors.white))),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final m = months[v.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(monthShort(m.year, m.month), style: TextStyle(fontSize: 11, color: outline)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(x: i, barsSpace: 4, barRods: [
              BarChartRodData(toY: months[i].income, color: AppColors.income, width: 10, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: months[i].expense, color: AppColors.expense, width: 10, borderRadius: BorderRadius.circular(3)),
            ]),
        ],
      )),
    );
  }
}
