import 'package:flutter/foundation.dart';

/// Avisa as telas que os dados mudaram (ex.: nova transação) para recarregarem.
class DataVersion extends ChangeNotifier {
  int value = 0;

  void bump() {
    value++;
    notifyListeners();
  }
}
