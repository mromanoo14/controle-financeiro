import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Abre o widget Pluggy Connect e devolve o `itemId` criado.
///
/// O widget envia eventos via `postMessage`. Repassamos todas as mensagens
/// para o Flutter e procuramos o id do item nelas.
/// Confira o formato atual dos eventos na documentação da Pluggy
/// (https://docs.pluggy.ai) ao ativar o provedor real.
class PluggyConnectScreen extends StatefulWidget {
  const PluggyConnectScreen({super.key, required this.connectToken});

  final String connectToken;

  @override
  State<PluggyConnectScreen> createState() => _PluggyConnectScreenState();
}

class _PluggyConnectScreenState extends State<PluggyConnectScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _loading = false);
          _controller.runJavaScript('''
            window.addEventListener("message", function (e) {
              try { FlutterBridge.postMessage(typeof e.data === "string" ? e.data : JSON.stringify(e.data)); } catch (_) {}
            });
          ''');
        },
      ))
      ..loadRequest(Uri.parse('https://connect.pluggy.ai/?connect_token=${Uri.encodeComponent(widget.connectToken)}'));
  }

  void _onMessage(String raw) {
    dynamic data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (data is! Map) return;
    final event = (data['event'] ?? data['type'] ?? '').toString().toLowerCase();
    final item = data['item'] ?? (data['data'] is Map ? data['data']['item'] : null);
    final itemId = (item is Map ? item['id'] : null) ?? data['itemId'];
    if (itemId != null && (event.contains('success') || event.isEmpty)) {
      Navigator.pop(context, itemId.toString());
    } else if (event.contains('close') || event.contains('exit')) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar banco')),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
