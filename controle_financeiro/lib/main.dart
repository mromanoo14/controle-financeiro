import 'package:flutter/material.dart';

import 'screens/autenticacao/login_page.dart';
import 'screens/home_page.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  final apiService = ApiService();

  runApp(
    MyApp(
      apiService: apiService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final ApiService apiService;

  MyApp({
    super.key,
    ApiService? apiService,
  }) : apiService = apiService ?? ApiService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle Financeiro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginPage(
              apiService: apiService,
            ),

        '/home': (context) => HomePage(
              apiService: apiService,
            ),
      },
    );
  }
}