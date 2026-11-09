import 'package:flutter/material.dart';

/// Ícones disponíveis para categorias (o nome é salvo na API).
const Map<String, IconData> categoryIcons = {
  'restaurant': Icons.restaurant,
  'shopping_cart': Icons.shopping_cart,
  'directions_car': Icons.directions_car,
  'home': Icons.home,
  'favorite': Icons.favorite,
  'school': Icons.school,
  'celebration': Icons.celebration,
  'subscriptions': Icons.subscriptions,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'account_balance': Icons.account_balance,
  'category': Icons.category,
  'payments': Icons.payments,
  'savings': Icons.savings,
  'pets': Icons.pets,
  'fitness_center': Icons.fitness_center,
  'flight': Icons.flight,
  'child_care': Icons.child_care,
  'phone_iphone': Icons.phone_iphone,
  'local_gas_station': Icons.local_gas_station,
  'work': Icons.work,
  'card_giftcard': Icons.card_giftcard,
  'help_outline': Icons.help_outline,
};

IconData iconFor(String name) => categoryIcons[name] ?? Icons.category;

const categoryColors = [
  '#FF7043', '#8D6E63', '#42A5F5', '#7E57C2', '#EF5350', '#26A69A', '#FFCA28',
  '#AB47BC', '#EC407A', '#78909C', '#5D4037', '#43A047', '#66BB6A', '#29B6F6',
];
