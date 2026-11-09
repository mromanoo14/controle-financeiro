import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'core/token_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/finance_api.dart';
import 'state/auth_controller.dart';
import 'state/data_version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final api = FinanceApi(ApiClient(baseUrl: AppConfig.apiUrl));
  final auth = AuthController(api: api, storage: SecureTokenStorage());
  auth.restore();
  runApp(ControleFinanceiroApp(api: api, auth: auth));
}

class ControleFinanceiroApp extends StatelessWidget {
  const ControleFinanceiroApp({super.key, required this.api, required this.auth});

  final FinanceApi api;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => DataVersion()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide entre a tela de login e o app conforme o estado de autenticação.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((a) => a.status);
    return switch (status) {
      AuthStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => const HomeShell(),
    };
  }
}
