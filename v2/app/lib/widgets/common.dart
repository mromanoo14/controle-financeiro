import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Valor em reais colorido (verde receita / vermelho despesa).
class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.style, this.colored = true, this.showSign = false});

  final double value;
  final TextStyle? style;
  final bool colored;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final color = !colored ? null : (value < 0 ? AppColors.expense : AppColors.income);
    final prefix = showSign && value > 0 ? '+ ' : (showSign && value < 0 ? '- ' : '');
    final text = showSign ? '$prefix${money(value.abs())}' : money(value);
    return Text(text, style: (style ?? const TextStyle()).copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.icon, required this.color, this.size = 40});

  CategoryAvatar.of(Category? c, {super.key, this.size = 40})
      : icon = c?.icon ?? 'help_outline',
        color = c?.color ?? '#9E9E9E';

  final String icon;
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = hexColor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(size / 3)),
      child: Icon(iconFor(icon), color: c, size: size * 0.55),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: color)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? error.toString() : 'Algo deu errado.';
    return EmptyState(
      icon: Icons.cloud_off,
      message: message,
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar de novo')),
    );
  }
}

/// Carrega dados com `load` e mostra carregando / erro / conteúdo.
/// Recarrega quando `reloadKey` muda.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder, this.reloadKey});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Object? reloadKey;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();
  T? _last;

  @override
  void didUpdateWidget(covariant AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _future = widget.load();
  }

  Future<void> _reload() async {
    final future = widget.load();
    setState(() => _future = future);
    await future.catchError((_) => _last as T);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) _last = snap.data;
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        // Mantém o conteúdo anterior enquanto recarrega (evita "piscar").
        final data = snap.data ?? _last;
        if (data == null) return const Center(child: CircularProgressIndicator());
        return widget.builder(context, data, _reload);
      },
    );
  }
}

Future<void> showError(BuildContext context, Object error) async {
  final message = error is ApiException ? error.message : 'Algo deu errado.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Excluir'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
        ?trailing,
      ]),
    );
  }
}

/// Aviso de recurso Premium com botão para a tela de assinatura.
class PremiumBanner extends StatelessWidget {
  const PremiumBanner({super.key, required this.message, required this.onTap});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.workspace_premium, color: scheme.onTertiaryContainer),
        title: Text(message, style: TextStyle(color: scheme.onTertiaryContainer)),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: onTap,
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, this.onTap});

  final Transaction tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar.of(tx.category),
      title: Text(tx.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        tx.category?.name ?? 'Sem categoria',
        shortDate(tx.date),
        if (tx.fromOpenFinance) 'banco',
      ].join(' · ')),
      trailing: MoneyText(tx.signedAmount, showSign: true, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
