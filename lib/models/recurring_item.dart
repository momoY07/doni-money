import 'dart:convert';
import '../storage.dart';

class RecurringItem {
  final String id;
  final bool isExpense;
  final double amount;
  final String category;
  final String note;
  final String currency;
  final String paymentMethod;
  final String frequency; // 'monthly' | 'weekly'
  final int dayOfMonth;   // 1–28 (monthly)
  final int dayOfWeek;    // 1–7 Mon=1 (weekly)
  final String lastGeneratedKey; // 'yyyy-MM' monthly | 'yyyy-Www' weekly
  final bool isActive;

  const RecurringItem({
    required this.id,
    required this.isExpense,
    required this.amount,
    required this.category,
    required this.note,
    required this.currency,
    required this.paymentMethod,
    required this.frequency,
    required this.dayOfMonth,
    required this.dayOfWeek,
    required this.lastGeneratedKey,
    required this.isActive,
  });

  factory RecurringItem.fromMap(Map<String, dynamic> m) => RecurringItem(
        id: m['id'] as String,
        isExpense: m['isExpense'] as bool,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        note: m['note'] as String? ?? '',
        currency: m['currency'] as String? ?? '',
        paymentMethod: m['paymentMethod'] as String? ?? 'cash',
        frequency: m['frequency'] as String? ?? 'monthly',
        dayOfMonth: (m['dayOfMonth'] as num?)?.toInt() ?? 1,
        dayOfWeek: (m['dayOfWeek'] as num?)?.toInt() ?? 1,
        lastGeneratedKey: m['lastGeneratedKey'] as String? ?? '',
        isActive: m['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'isExpense': isExpense,
        'amount': amount,
        'category': category,
        'note': note,
        'currency': currency,
        'paymentMethod': paymentMethod,
        'frequency': frequency,
        'dayOfMonth': dayOfMonth,
        'dayOfWeek': dayOfWeek,
        'lastGeneratedKey': lastGeneratedKey,
        'isActive': isActive,
      };

  RecurringItem copyWith({
    String? lastGeneratedKey,
    bool? isActive,
  }) =>
      RecurringItem(
        id: id,
        isExpense: isExpense,
        amount: amount,
        category: category,
        note: note,
        currency: currency,
        paymentMethod: paymentMethod,
        frequency: frequency,
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        lastGeneratedKey: lastGeneratedKey ?? this.lastGeneratedKey,
        isActive: isActive ?? this.isActive,
      );

  // ── Storage helpers ──────────────────────────────────────────

  static const _key = 'recurringItems';

  static List<RecurringItem> loadAll() {
    final raw = Storage.txBox.get(_key, defaultValue: '[]') as String;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => RecurringItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveAll(List<RecurringItem> items) async {
    await Storage.txBox.put(
      _key,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
  }

  static Future<void> add(RecurringItem item) async {
    final list = loadAll()..add(item);
    await saveAll(list);
  }

  static Future<void> updateById(String id, RecurringItem updated) async {
    final list = loadAll();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    list[idx] = updated;
    await saveAll(list);
  }

  static Future<void> removeById(String id) async {
    final list = loadAll()..removeWhere((e) => e.id == id);
    await saveAll(list);
  }

  // ── Tx payload ───────────────────────────────────────────────

  Map<String, dynamic> toTxMap(DateTime date) => {
        'id': '${DateTime.now().microsecondsSinceEpoch}',
        'isExpense': isExpense,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'entryCurrency': currency,
        'baseAmount': amount,
        'baseCurrency': currency,
        'exchangeRate': 1.0,
        'currencyMetaVersion': currency.isEmpty ? 0 : 1,
        'paymentMethod': paymentMethod,
      };

  // ── Key helpers ───────────────────────────────────────────────

  static String monthlyKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String weeklyKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final weekNum = ((monday.difference(DateTime(monday.year, 1, 1)).inDays +
                DateTime(monday.year, 1, 1).weekday -
                1) ~/
            7) +
        1;
    return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }
}
