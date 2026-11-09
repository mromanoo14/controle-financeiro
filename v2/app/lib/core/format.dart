import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
final _shortDate = DateFormat('dd MMM', 'pt_BR');
final _month = DateFormat('MMMM yyyy', 'pt_BR');
final _monthShort = DateFormat('MMM', 'pt_BR');

String money(num value) => _currency.format(value);
String formatDate(DateTime d) => _date.format(d);
String shortDate(DateTime d) => _shortDate.format(d);
String monthName(int year, int month) {
  final s = _month.format(DateTime(year, month));
  return s[0].toUpperCase() + s.substring(1);
}

String monthShort(int year, int month) => _monthShort.format(DateTime(year, month)).replaceAll('.', '');

/// Data no formato da API (yyyy-MM-dd).
String apiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Converte o texto digitado ("1.234,56" ou "1234.56") em número.
double? parseMoney(String text) {
  var t = text.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Valor no formato da API ("1234.56").
String apiMoney(double v) => v.toStringAsFixed(2);

double toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));

Color hexColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

String colorHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
