// Modelos que espelham os schemas da API.
import '../core/format.dart';

enum TxKind {
  expense('expense', 'Despesa'),
  income('income', 'Receita');

  const TxKind(this.api, this.label);
  final String api;
  final String label;

  static TxKind parse(String v) => TxKind.values.firstWhere((k) => k.api == v);
}

enum AccountType {
  checking('checking', 'Conta corrente'),
  savings('savings', 'Poupança'),
  creditCard('credit_card', 'Cartão de crédito'),
  wallet('wallet', 'Carteira / dinheiro'),
  investment('investment', 'Investimento');

  const AccountType(this.api, this.label);
  final String api;
  final String label;

  static AccountType parse(String v) => AccountType.values.firstWhere((k) => k.api == v);
}

enum Frequency {
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensal'),
  yearly('yearly', 'Anual');

  const Frequency(this.api, this.label);
  final String api;
  final String label;

  static Frequency parse(String v) => Frequency.values.firstWhere((k) => k.api == v);
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);

class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.monthlyIncome,
    required this.isPremium,
    required this.subscriptionStatus,
    required this.trialEndsAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        monthlyIncome: j['monthly_income'] == null ? null : toDouble(j['monthly_income']),
        isPremium: j['is_premium'] ?? false,
        subscriptionStatus: j['subscription_status'],
        trialEndsAt: _date(j['trial_ends_at']),
      );

  final int id;
  final String name;
  final String email;
  final double? monthlyIncome;
  final bool isPremium;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;

  bool get onTrial => subscriptionStatus == 'trial';
}

class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.institution,
    required this.initialBalance,
    required this.balance,
    required this.fromOpenFinance,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'],
        name: j['name'],
        type: AccountType.parse(j['type']),
        institution: j['institution'],
        initialBalance: toDouble(j['initial_balance']),
        balance: toDouble(j['balance']),
        fromOpenFinance: j['source'] == 'open_finance',
      );

  final int id;
  final String name;
  final AccountType type;
  final String? institution;
  final double initialBalance;
  final double balance;
  final bool fromOpenFinance;
}

class Category {
  Category({required this.id, required this.name, required this.kind, required this.icon, required this.color});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        kind: TxKind.parse(j['kind']),
        icon: j['icon'],
        color: j['color'],
      );

  final int id;
  final String name;
  final TxKind kind;
  final String icon;
  final String color;
}

class Transaction {
  Transaction({
    required this.id,
    required this.accountId,
    required this.category,
    required this.kind,
    required this.amount,
    required this.description,
    required this.date,
    required this.notes,
    required this.fromOpenFinance,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'],
        accountId: j['account_id'],
        category: j['category'] == null ? null : Category.fromJson(j['category']),
        kind: TxKind.parse(j['kind']),
        amount: toDouble(j['amount']),
        description: j['description'],
        date: DateTime.parse(j['date']),
        notes: j['notes'],
        fromOpenFinance: j['source'] == 'open_finance',
      );

  final int id;
  final int accountId;
  final Category? category;
  final TxKind kind;
  final double amount;
  final String description;
  final DateTime date;
  final String? notes;
  final bool fromOpenFinance;

  double get signedAmount => kind == TxKind.expense ? -amount : amount;
}

class TransactionPage {
  TransactionPage(this.items, this.total);

  factory TransactionPage.fromJson(Map<String, dynamic> j) => TransactionPage(
        (j['items'] as List).map((e) => Transaction.fromJson(e)).toList(),
        j['total'],
      );

  final List<Transaction> items;
  final int total;
}

class Recurrence {
  Recurrence({
    required this.id,
    required this.accountId,
    required this.category,
    required this.kind,
    required this.description,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.installments,
    required this.nextDate,
  });

  factory Recurrence.fromJson(Map<String, dynamic> j) => Recurrence(
        id: j['id'],
        accountId: j['account_id'],
        category: j['category'] == null ? null : Category.fromJson(j['category']),
        kind: TxKind.parse(j['kind']),
        description: j['description'],
        amount: toDouble(j['amount']),
        frequency: Frequency.parse(j['frequency']),
        startDate: DateTime.parse(j['start_date']),
        installments: j['installments'],
        nextDate: _date(j['next_date']),
      );

  final int id;
  final int? accountId;
  final Category? category;
  final TxKind kind;
  final String description;
  final double amount;
  final Frequency frequency;
  final DateTime startDate;
  final int? installments;
  final DateTime? nextDate;
}

class Budget {
  Budget({required this.id, required this.category, required this.limit, required this.spent});

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'],
        category: Category.fromJson(j['category']),
        limit: toDouble(j['monthly_limit']),
        spent: toDouble(j['spent']),
      );

  final int id;
  final Category category;
  final double limit;
  final double spent;

  double get progress => limit == 0 ? 0 : spent / limit;
}

class CategoryTotal {
  CategoryTotal({required this.categoryId, required this.name, required this.color, required this.icon, required this.total});

  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
        categoryId: j['category_id'],
        name: j['name'],
        color: j['color'],
        icon: j['icon'],
        total: toDouble(j['total']),
      );

  final int? categoryId;
  final String name;
  final String color;
  final String icon;
  final double total;
}

class MonthSummary {
  MonthSummary({required this.year, required this.month, required this.income, required this.expense, required this.byCategory});

  factory MonthSummary.fromJson(Map<String, dynamic> j) => MonthSummary(
        year: j['year'],
        month: j['month'],
        income: toDouble(j['income']),
        expense: toDouble(j['expense']),
        byCategory: (j['by_category'] as List).map((e) => CategoryTotal.fromJson(e)).toList(),
      );

  final int year;
  final int month;
  final double income;
  final double expense;
  final List<CategoryTotal> byCategory;

  double get balance => income - expense;
}

class CategoryForecast {
  CategoryForecast({
    required this.name,
    required this.color,
    required this.icon,
    required this.spent,
    required this.fixed,
    required this.variable,
    required this.projected,
    required this.budget,
  });

  factory CategoryForecast.fromJson(Map<String, dynamic> j) => CategoryForecast(
        name: j['name'],
        color: j['color'],
        icon: j['icon'],
        spent: toDouble(j['spent']),
        fixed: toDouble(j['fixed']),
        variable: toDouble(j['variable']),
        projected: toDouble(j['projected']),
        budget: j['budget'] == null ? null : toDouble(j['budget']),
      );

  final String name;
  final String color;
  final String icon;
  final double spent;
  final double fixed;
  final double variable;
  final double projected;
  final double? budget;

  bool get overBudget => budget != null && projected > budget!;
}

class ForecastItem {
  ForecastItem({required this.date, required this.description, required this.amount, required this.kind, required this.recurrenceId});

  factory ForecastItem.fromJson(Map<String, dynamic> j) => ForecastItem(
        date: DateTime.parse(j['date']),
        description: j['description'],
        amount: toDouble(j['amount']),
        kind: TxKind.parse(j['kind']),
        recurrenceId: j['recurrence_id'],
      );

  final DateTime date;
  final String description;
  final double amount;
  final TxKind kind;
  final int recurrenceId;
}

class MonthForecast {
  MonthForecast({
    required this.year,
    required this.month,
    required this.expectedIncome,
    required this.spentSoFar,
    required this.projectedExpense,
    required this.projectedBalance,
    required this.byCategory,
    required this.upcoming,
  });

  factory MonthForecast.fromJson(Map<String, dynamic> j) => MonthForecast(
        year: j['year'],
        month: j['month'],
        expectedIncome: toDouble(j['expected_income']),
        spentSoFar: toDouble(j['spent_so_far']),
        projectedExpense: toDouble(j['projected_expense']),
        projectedBalance: toDouble(j['projected_balance']),
        byCategory: (j['by_category'] as List).map((e) => CategoryForecast.fromJson(e)).toList(),
        upcoming: (j['upcoming'] as List).map((e) => ForecastItem.fromJson(e)).toList(),
      );

  final int year;
  final int month;
  final double expectedIncome;
  final double spentSoFar;
  final double projectedExpense;
  final double projectedBalance;
  final List<CategoryForecast> byCategory;
  final List<ForecastItem> upcoming;
}

class Dashboard {
  Dashboard({required this.totalBalance, required this.accounts, required this.month, required this.forecast, required this.recent});

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        totalBalance: toDouble(j['total_balance']),
        accounts: (j['accounts'] as List).map((e) => Account.fromJson(e)).toList(),
        month: MonthSummary.fromJson(j['month']),
        forecast: MonthForecast.fromJson(j['forecast']),
        recent: (j['recent_transactions'] as List).map((e) => Transaction.fromJson(e)).toList(),
      );

  final double totalBalance;
  final List<Account> accounts;
  final MonthSummary month;
  final MonthForecast forecast;
  final List<Transaction> recent;
}

class BankConnection {
  BankConnection({required this.id, required this.institution, required this.status, required this.lastSyncedAt, required this.error});

  factory BankConnection.fromJson(Map<String, dynamic> j) => BankConnection(
        id: j['id'],
        institution: j['institution'],
        status: j['status'],
        lastSyncedAt: _date(j['last_synced_at'])?.toLocal(),
        error: j['error_message'],
      );

  final int id;
  final String? institution;
  final String status;
  final DateTime? lastSyncedAt;
  final String? error;
}

class SyncResult {
  SyncResult({required this.accounts, required this.imported});

  factory SyncResult.fromJson(Map<String, dynamic> j) => SyncResult(accounts: j['accounts'], imported: j['imported']);

  final int accounts;
  final int imported;
}

class Plan {
  Plan({required this.id, required this.name, required this.priceCents, required this.features});

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'],
        name: j['name'],
        priceCents: j['price_cents'],
        features: List<String>.from(j['features']),
      );

  final String id;
  final String name;
  final int priceCents;
  final List<String> features;
}

class SubscriptionInfo {
  SubscriptionInfo({required this.status, required this.isPremium, required this.trialEndsAt, required this.endsAt});

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        status: j['status'],
        isPremium: j['is_premium'],
        trialEndsAt: _date(j['trial_ends_at'])?.toLocal(),
        endsAt: _date(j['subscription_ends_at'])?.toLocal(),
      );

  final String status;
  final bool isPremium;
  final DateTime? trialEndsAt;
  final DateTime? endsAt;
}
