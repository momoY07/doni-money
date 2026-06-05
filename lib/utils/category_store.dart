import 'dart:convert';
import '../storage.dart';

class CategoryStore {
  static const _expenseKey = 'customExpenseCategories';
  static const _incomeKey = 'customIncomeCategories';

  static const defaultExpenseCategories = [
    '🍔 Food', '☕ Coffee', '🛒 Grocery', '🚌 Transport',
    '🛍️ Shopping', '🧾 Bills', '🎬 Entertainment', '💊 Health',
    '🎁 Gift', '✈️ Travel', '🧾 Other',
  ];

  static const defaultIncomeCategories = [
    '💼 Salary', '🎁 Gift', '🧾 Other',
  ];

  static List<String> expenseCategories() =>
      [...defaultExpenseCategories, ...customExpense()];

  static List<String> incomeCategories() =>
      [...defaultIncomeCategories, ...customIncome()];

  static List<String> customExpense() => _getCustom(_expenseKey);
  static List<String> customIncome() => _getCustom(_incomeKey);

  static List<String> _getCustom(String key) {
    final raw = Storage.txBox.get(key, defaultValue: '[]') as String;
    final list = jsonDecode(raw) as List;
    return list.map((e) => e.toString()).toList();
  }

  static Future<void> addExpense(String cat) => _add(_expenseKey, cat);
  static Future<void> addIncome(String cat) => _add(_incomeKey, cat);
  static Future<void> removeExpense(String cat) => _remove(_expenseKey, cat);
  static Future<void> removeIncome(String cat) => _remove(_incomeKey, cat);

  static Future<void> _add(String key, String cat) async {
    final list = _getCustom(key);
    if (!list.contains(cat)) {
      list.add(cat);
      await Storage.txBox.put(key, jsonEncode(list));
    }
  }

  static Future<void> _remove(String key, String cat) async {
    final list = _getCustom(key);
    list.remove(cat);
    await Storage.txBox.put(key, jsonEncode(list));
  }
}
