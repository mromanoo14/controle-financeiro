import 'package:flutter_test/flutter_test.dart';

import 'package:controle_financeiro/main.dart';

void main() {
  testWidgets(
    'Aplicativo inicia na tela de login',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MyApp(),
      );

      expect(
        find.text('Controle Financeiro'),
        findsOneWidget,
      );

      expect(
        find.text('Entre na sua conta'),
        findsOneWidget,
      );

      expect(
        find.text('Entrar'),
        findsOneWidget,
      );
    },
  );
}