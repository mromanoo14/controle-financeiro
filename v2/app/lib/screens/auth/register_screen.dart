import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../state/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Aceite os termos de uso e a política de privacidade.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().register(_name.text, _email.text, _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Teste grátis por 14 dias todos os recursos Premium.', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Informe seu nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      helperText: 'Mínimo de 8 caracteres',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.length < 8) ? 'Use pelo menos 8 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _accepted,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Li e aceito os Termos de Uso e a Política de Privacidade'),
                  ),
                  if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Criar conta'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
