import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage.dart';

class TxRepo extends ChangeNotifier {
  TxRepo() {
    normalizeItems();
  }

  List<Map<String, dynamic>> get items {
    final raw = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  String _toTrimmedString(dynamic value) {
    final text = value?.toString() ?? '';
    return text.trim();
  }

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> item) {
    final map = Map<String, dynamic>.from(item);

    final rawId = _toTrimmedString(map['id']);
    final amount = _toDouble(map['amount']);
    final entryCurrency = _toTrimmedString(map['entryCurrency']);
    final rawBaseCurrency = _toTrimmedString(map['baseCurrency']);
    final rawVersion = map['currencyMetaVersion'];

    map['id'] = rawId.isEmpty ? _generateId() : rawId;
    map['isExpense'] = map['isExpense'] == true;
    map['amount'] = amount;
    map['category'] = _toTrimmedString(map['category']);
    map['note'] = map['note']?.toString() ?? '';
    map['date'] = _toTrimmedString(map['date']);

    map['entryCurrency'] = entryCurrency;
    map['baseAmount'] = _toDouble(map['baseAmount'], fallback: amount);
    map['baseCurrency'] = rawBaseCurrency.isEmpty
        ? entryCurrency
        : rawBaseCurrency;
    map['exchangeRate'] = _toDouble(map['exchangeRate'], fallback: 1.0);
    map['currencyMetaVersion'] = rawVersion is int
        ? rawVersion
        : (rawVersion is num
              ? rawVersion.toInt()
              : (entryCurrency.isEmpty ? 0 : 1));

    return map;
  }

  Future<void> normalizeItems() async {
    final list = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    bool changed = false;
    final normalized = <String>[];

    for (final raw in list) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final fixed = _normalizeItem(map);

      if (jsonEncode(map) != jsonEncode(fixed)) {
        changed = true;
      }

      normalized.add(jsonEncode(fixed));
    }

    if (changed) {
      await Storage.txBox.put('items', normalized);
      notifyListeners();
    }
  }

  Future<void> add(Map<String, dynamic> item) async {
    final list = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    final normalizedItem = _normalizeItem(item);

    list.insert(0, jsonEncode(normalizedItem));
    await Storage.txBox.put('items', list);
    notifyListeners();
  }

  Future<void> clear() async {
    await Storage.txBox.put('items', <String>[]);
    notifyListeners();
  }

  Future<void> replaceAll(List<Map<String, dynamic>> newItems) async {
    final normalized = newItems
        .map((item) => jsonEncode(_normalizeItem(item)))
        .toList();

    await Storage.txBox.put('items', normalized);
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    final list = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    await Storage.txBox.put('items', list);
    notifyListeners();
  }

  Future<void> updateAt(int index, Map<String, dynamic> item) async {
    final list = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    if (index < 0 || index >= list.length) return;

    final normalizedItem = _normalizeItem(item);
    list[index] = jsonEncode(normalizedItem);
    await Storage.txBox.put('items', list);
    notifyListeners();
  }

  Future<void> removeById(String id) async {
    final list = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    final index = list.indexWhere((raw) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id'] == id;
    });

    if (index == -1) return;

    list.removeAt(index);
    await Storage.txBox.put('items', list);
    notifyListeners();
  }

  Future<void> updateById(String id, Map<String, dynamic> item) async {
    final list = (Storage.txBox.get('items', defaultValue: <String>[]) as List)
        .cast<String>();

    final index = list.indexWhere((raw) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map['id'] == id;
    });

    if (index == -1) return;

    final normalizedItem = _normalizeItem(item);
    normalizedItem['id'] = id;

    list[index] = jsonEncode(normalizedItem);
    await Storage.txBox.put('items', list);
    notifyListeners();
  }
}
