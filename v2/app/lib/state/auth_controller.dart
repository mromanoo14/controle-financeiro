import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/models.dart';
import '../services/finance_api.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Estado de login do app. Restaura o token salvo ao abrir.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.storage}) {
    api.client.onUnauthorized = () => signOut();
  }

  final FinanceApi api;
  final TokenStorage storage;

  AuthStatus status = AuthStatus.unknown;
  User? user;

  Future<void> restore() async {
    final token = await storage.read();
    if (token == null) {
      _setSignedOut();
      return;
    }
    api.client.token = token;
    try {
      user = await api.me();
      status = AuthStatus.signedIn;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
      } else {
        // Sem internet: entra mesmo assim; as telas mostram o erro e permitem tentar de novo.
        status = AuthStatus.signedIn;
        notifyListeners();
      }
    }
  }

  Future<void> login(String email, String password) => _authenticate(api.login(email.trim(), password));

  Future<void> register(String name, String email, String password) =>
      _authenticate(api.register(name.trim(), email.trim(), password));

  Future<void> _authenticate(Future<String> request) async {
    final token = await request;
    api.client.token = token;
    await storage.write(token);
    user = await api.me();
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = await api.me();
    notifyListeners();
  }

  Future<void> signOut() async {
    await storage.clear();
    _setSignedOut();
  }

  void _setSignedOut() {
    api.client.token = null;
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
