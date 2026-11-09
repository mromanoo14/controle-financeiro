import 'package:flutter/foundation.dart';

/// Configurações do app.
///
/// A URL da API pode ser definida no build:
///   flutter run --dart-define=API_URL=http://192.168.0.10:8000
///   flutter build apk --dart-define=API_URL=https://api.seudominio.com.br
class AppConfig {
  static const String _fromEnv = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    // O emulador Android enxerga o computador em 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static const appName = 'Controle Financeiro';
}
