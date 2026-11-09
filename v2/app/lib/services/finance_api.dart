import '../core/api_client.dart';
import '../core/format.dart';
import '../models/models.dart';

/// Todas as chamadas à API do backend.
class FinanceApi {
  FinanceApi(this.client);

  final ApiClient client;

  // ------------------------------------------------------------ Auth / perfil

  Future<String> login(String email, String password) async {
    final data = await client.post('/auth/login', body: {'email': email, 'password': password});
    return data['access_token'];
  }

  Future<String> register(String name, String email, String password) async {
    final data = await client.post('/auth/register', body: {'name': name, 'email': email, 'password': password});
    return data['access_token'];
  }

  Future<User> me() async => User.fromJson(await client.get('/me'));

  Future<User> updateMe({String? name, double? monthlyIncome}) async => User.fromJson(await client.patch('/me', body: {
        'name': ?name,
        if (monthlyIncome != null) 'monthly_income': apiMoney(monthlyIncome),
      }));

  Future<void> changePassword(String current, String newPassword) =>
      client.post('/me/password', body: {'current_password': current, 'new_password': newPassword});

  Future<void> deleteMe() => client.delete('/me');

  // ------------------------------------------------------------ Painel / relatórios

  Future<Dashboard> dashboard() async => Dashboard.fromJson(await client.get('/dashboard'));

  Future<List<MonthSummary>> monthlyHistory({int months = 6}) async {
    final data = await client.get('/reports/monthly', query: {'months': months}) as List;
    return data.map((e) => MonthSummary.fromJson(e)).toList();
  }

  Future<List<MonthForecast>> forecast({int months = 1}) async {
    final data = await client.get('/forecast', query: {'months': months}) as List;
    return data.map((e) => MonthForecast.fromJson(e)).toList();
  }

  // ------------------------------------------------------------ Contas

  Future<List<Account>> accounts() async {
    final data = await client.get('/accounts') as List;
    return data.map((e) => Account.fromJson(e)).toList();
  }

  Future<void> saveAccount({int? id, required String name, required AccountType type, String? institution, required double initialBalance}) {
    final body = {
      'name': name,
      'type': type.api,
      'institution': institution,
      'initial_balance': apiMoney(initialBalance),
    };
    return id == null ? client.post('/accounts', body: body) : client.patch('/accounts/$id', body: body);
  }

  Future<void> deleteAccount(int id) => client.delete('/accounts/$id');

  // ------------------------------------------------------------ Categorias

  Future<List<Category>> categories({TxKind? kind}) async {
    final data = await client.get('/categories', query: {'kind': kind?.api}) as List;
    return data.map((e) => Category.fromJson(e)).toList();
  }

  Future<void> saveCategory({int? id, required String name, required TxKind kind, required String icon, required String color}) {
    return id == null
        ? client.post('/categories', body: {'name': name, 'kind': kind.api, 'icon': icon, 'color': color})
        : client.patch('/categories/$id', body: {'name': name, 'icon': icon, 'color': color});
  }

  Future<void> deleteCategory(int id) => client.delete('/categories/$id');

  // ------------------------------------------------------------ Transações

  Future<TransactionPage> transactions({
    int? year,
    int? month,
    int? categoryId,
    int? accountId,
    TxKind? kind,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await client.get('/transactions', query: {
      'year': year,
      'month': month,
      'category_id': categoryId,
      'account_id': accountId,
      'kind': kind?.api,
      'search': (search?.isEmpty ?? true) ? null : search,
      'limit': limit,
      'offset': offset,
    });
    return TransactionPage.fromJson(data);
  }

  Future<Transaction> saveTransaction({
    int? id,
    required int accountId,
    int? categoryId,
    required TxKind kind,
    required double amount,
    required String description,
    required DateTime date,
    String? notes,
  }) async {
    final body = {
      'account_id': accountId,
      'category_id': ?categoryId,
      'kind': kind.api,
      'amount': apiMoney(amount),
      'description': description,
      'date': apiDate(date),
      'notes': (notes?.isEmpty ?? true) ? null : notes,
    };
    final data = id == null ? await client.post('/transactions', body: body) : await client.patch('/transactions/$id', body: body);
    return Transaction.fromJson(data);
  }

  Future<void> deleteTransaction(int id) => client.delete('/transactions/$id');

  // ------------------------------------------------------------ Recorrências

  Future<List<Recurrence>> recurrences() async {
    final data = await client.get('/recurrences') as List;
    return data.map((e) => Recurrence.fromJson(e)).toList();
  }

  Future<void> saveRecurrence({
    int? id,
    int? accountId,
    int? categoryId,
    required TxKind kind,
    required String description,
    required double amount,
    required Frequency frequency,
    required DateTime startDate,
    int? installments,
  }) {
    final body = {
      'account_id': accountId,
      'category_id': categoryId,
      'description': description,
      'amount': apiMoney(amount),
      'frequency': frequency.api,
      'installments': installments,
    };
    if (id == null) {
      return client.post('/recurrences', body: {...body, 'kind': kind.api, 'start_date': apiDate(startDate)});
    }
    return client.patch('/recurrences/$id', body: body);
  }

  Future<void> deleteRecurrence(int id) => client.delete('/recurrences/$id');

  Future<void> payRecurrence(int id, {DateTime? date, int? accountId}) => client.post('/recurrences/$id/pay', body: {
        if (date != null) 'date': apiDate(date),
        'account_id': ?accountId,
      });

  // ------------------------------------------------------------ Orçamentos

  Future<List<Budget>> budgets() async {
    final data = await client.get('/budgets') as List;
    return data.map((e) => Budget.fromJson(e)).toList();
  }

  Future<void> saveBudget(int categoryId, double limit) =>
      client.put('/budgets', body: {'category_id': categoryId, 'monthly_limit': apiMoney(limit)});

  Future<void> deleteBudget(int id) => client.delete('/budgets/$id');

  // ------------------------------------------------------------ Open Finance

  Future<({String provider, String token})> connectToken({String? itemId}) async {
    final data = await client.post('/open-finance/connect-token', query: {'item_id': itemId});
    return (provider: data['provider'] as String, token: data['connect_token'] as String);
  }

  Future<List<BankConnection>> connections() async {
    final data = await client.get('/open-finance/connections') as List;
    return data.map((e) => BankConnection.fromJson(e)).toList();
  }

  Future<SyncResult> addConnection(String externalId) async =>
      SyncResult.fromJson(await client.post('/open-finance/connections', body: {'external_id': externalId}));

  Future<SyncResult> syncConnection(int id) async =>
      SyncResult.fromJson(await client.post('/open-finance/connections/$id/sync'));

  Future<void> deleteConnection(int id) => client.delete('/open-finance/connections/$id');

  // ------------------------------------------------------------ Assinatura

  Future<List<Plan>> plans() async {
    final data = await client.get('/subscription/plans') as List;
    return data.map((e) => Plan.fromJson(e)).toList();
  }

  Future<SubscriptionInfo> subscription() async => SubscriptionInfo.fromJson(await client.get('/subscription'));

  Future<SubscriptionInfo> purchase({required String platform, required String productId, required String token}) async =>
      SubscriptionInfo.fromJson(await client.post('/subscription/purchase',
          body: {'platform': platform, 'product_id': productId, 'purchase_token': token}));

  Future<SubscriptionInfo> cancelSubscription() async => SubscriptionInfo.fromJson(await client.post('/subscription/cancel'));
}
