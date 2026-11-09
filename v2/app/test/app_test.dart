import 'dart:convert';

import 'package:controle_financeiro/core/api_client.dart';
import 'package:controle_financeiro/core/format.dart';
import 'package:controle_financeiro/core/token_storage.dart';
import 'package:controle_financeiro/main.dart';
import 'package:controle_financeiro/services/finance_api.dart';
import 'package:controle_financeiro/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Backend falso: responde às rotas usadas pelo app.
http.Response fakeBackend(http.Request req) {
  final path = req.url.path;
  Map<String, dynamic> month = {'year': 2026, 'month': 11, 'income': '5000.00', 'expense': '1200.00', 'balance': '3800.00', 'by_category': [
    {'category_id': 1, 'name': 'Alimentação', 'color': '#FF7043', 'icon': 'restaurant', 'total': '800.00'},
    {'category_id': 2, 'name': 'Transporte', 'color': '#42A5F5', 'icon': 'directions_car', 'total': '400.00'},
  ]};
  final responses = <String, Object>{
    '/auth/login': {'access_token': 'token-123', 'token_type': 'bearer'},
    '/me': {
      'id': 1, 'name': 'Ana Souza', 'email': 'ana@example.com', 'monthly_income': '5000.00', 'plan': 'free',
      'subscription_status': 'trial', 'trial_ends_at': '2026-11-23T00:00:00Z', 'subscription_ends_at': null, 'is_premium': true,
    },
    '/dashboard': {
      'total_balance': '3800.00',
      'accounts': [],
      'month': month,
      'forecast': {
        'year': 2026, 'month': 11, 'expected_income': '5000.00', 'income_so_far': '5000.00', 'spent_so_far': '1200.00',
        'projected_expense': '2500.00', 'projected_balance': '2500.00', 'by_category': [], 'upcoming': [],
      },
      'recent_transactions': [
        {'id': 1, 'account_id': 1, 'category_id': 1, 'category': {'id': 1, 'name': 'Alimentação', 'kind': 'expense', 'icon': 'restaurant', 'color': '#FF7043'},
         'kind': 'expense', 'amount': '45.90', 'description': 'iFood', 'date': '2026-11-08', 'notes': null, 'source': 'manual', 'category_locked': false},
      ],
    },
    '/reports/monthly': [month],
  };
  final body = responses[path];
  if (body == null) return json({'detail': 'não encontrado'}, 404);
  if (path == '/auth/login') {
    final data = jsonDecode(req.body);
    if (data['password'] != 'senha-certa') return json({'detail': 'E-mail ou senha inválidos.'}, 401);
  }
  return json(body, 200);
}

http.Response json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Future<AuthController> pumpApp(WidgetTester tester) async {
    final api = FinanceApi(ApiClient(baseUrl: 'http://api', httpClient: MockClient((r) async => fakeBackend(r))));
    final auth = AuthController(api: api, storage: MemoryTokenStorage());
    await auth.restore();
    await tester.pumpWidget(ControleFinanceiroApp(api: api, auth: auth));
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('mostra a tela de login quando não há token salvo', (tester) async {
    await pumpApp(tester);
    expect(find.text('Entre na sua conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('login com senha errada mostra a mensagem da API', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'errada');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
  });

  testWidgets('login abre o painel com saldo e previsão', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final auth = await pumpApp(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-certa');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(auth.status, AuthStatus.signedIn);
    expect(find.text('Olá, Ana!'), findsOneWidget);
    expect(find.text(money(3800)), findsWidgets);
    expect(find.textContaining('Deve sobrar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('iFood'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('iFood'), findsOneWidget);
  });

  test('resposta que não é JSON vira mensagem amigável', () async {
    final client = ApiClient(baseUrl: 'http://api', httpClient: MockClient((_) async => http.Response('<html>502</html>', 502)));
    expect(() => client.get('/x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
  });

  test('parseMoney aceita formatos brasileiro e internacional', () {
    expect(parseMoney('1.234,56'), 1234.56);
    expect(parseMoney('R\$ 10,5'), 10.5);
    expect(parseMoney('99.90'), 99.90);
    expect(parseMoney(''), isNull);
  });

  test('ApiClient traduz erros de validação do FastAPI', () async {
    final client = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((_) async => json({'detail': [{'loc': ['body', 'amount'], 'msg': 'deve ser maior que 0'}]}, 422)),
    );
    expect(
      () => client.get('/x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Campo "amount": deve ser maior que 0')),
    );
  });
}
