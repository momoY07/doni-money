import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:simple_ledger/models/recurring_item.dart';
import 'package:simple_ledger/models/tx_item.dart';
import 'package:simple_ledger/services/backup_service.dart';
import 'package:simple_ledger/storage.dart';
import 'package:simple_ledger/tx_repo.dart';
import 'package:simple_ledger/utils/category_store.dart';

/// Box that fails the first `putAll`, to simulate a storage error mid-restore.
class _FailingBox implements Box {
  final Box inner;
  bool _failed = false;
  _FailingBox(this.inner);

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      inner.get(key, defaultValue: defaultValue);
  @override
  bool containsKey(dynamic key) => inner.containsKey(key);
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) {
    if (!_failed) {
      _failed = true;
      throw HiveError('simulated disk failure');
    }
    return inner.putAll(entries);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => inner.deleteAll(keys);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tmp;
  late Box box;
  final fixedNow = DateTime(2026, 11, 4, 9, 30);
  BackupService service() => BackupService(box: box, now: () => fixedNow);

  Map<String, dynamic> tx(String id, double amount, {bool expense = true}) => {
        'id': id,
        'isExpense': expense,
        'amount': amount,
        'category': '🍔 Food',
        'note': 'note $id',
        'date': '2026-11-0${id.length}T12:00:00.000',
        'entryCurrency': 'KRW',
        'baseAmount': amount,
        'baseCurrency': 'KRW',
        'exchangeRate': 1.0,
        'currencyMetaVersion': 1,
        'paymentMethod': 'card',
      };

  Future<void> seed() async {
    await box.put('items', [jsonEncode(tx('a', 12000)), jsonEncode(tx('bb', 3500.5, expense: false))]);
    await RecurringItem.saveAll([
      const RecurringItem(
        id: 'r1', isExpense: true, amount: 9900, category: '📶 Internet',
        note: 'ISP', currency: 'KRW', paymentMethod: 'bank', frequency: 'monthly',
        dayOfMonth: 15, dayOfWeek: 1, lastGeneratedKey: '2026-10', isActive: true,
      ),
    ]);
    await CategoryStore.addExpense('🐶 Pet');
    await CategoryStore.addIncome('🪙 Side job');
    await box.putAll({
      'selectedCurrency': 'KRW',
      'selectedLanguage': 'ko',
      'selectedTheme': 'dog_dark',
      'monthlyBudget': 500000.0,
      'balance_carryover_enabled': false,
      'lockEnabled': true,
      'lockPasscode': '1234',
    });
  }

  /// Snapshot of every managed key + lock keys, for "unchanged" checks.
  Map<String, dynamic> snapshot() => {
        for (final k in [...BackupService.managedKeys, 'lockEnabled', 'lockPasscode'])
          k: jsonEncode(box.get(k)),
      };

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_test');
    Hive.init(tmp.path);
    box = await Hive.openBox(Storage.txBoxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  group('createBackup', () {
    test('includes all user data with versioned envelope', () async {
      await seed();
      final doc = service().createBackup(appVersion: '1.5.0+12');

      expect(doc['format'], 'doni_money_backup');
      expect(doc['schemaVersion'], 1);
      expect(doc['appVersion'], '1.5.0+12');
      expect(DateTime.parse(doc['createdAt'] as String), fixedNow.toUtc());

      final data = doc['data'] as Map<String, dynamic>;
      expect((data['transactions'] as List).length, 2);
      expect((data['transactions'] as List).first['id'], 'a');
      expect((data['recurringTransactions'] as List).single['id'], 'r1');
      expect(data['categories'], {
        'customExpense': ['🐶 Pet'],
        'customIncome': ['🪙 Side job'],
      });
      expect(data['settings'], {
        'currency': 'KRW',
        'language': 'ko',
        'theme': 'dog_dark',
        'monthlyBudget': 500000.0,
        'balanceCarryoverEnabled': false,
      });
    });

    test('excludes passcode / lock state', () async {
      await seed();
      final json = service().createBackupJson();
      expect(json.contains('lockPasscode'), isFalse);
      expect(json.contains('1234'), isFalse);
      expect(json.contains('lockEnabled'), isFalse);
    });

    test('empty storage produces a valid backup with app defaults', () {
      final s = service();
      final doc = s.createBackup();
      final data = doc['data'] as Map<String, dynamic>;
      expect(data['transactions'], isEmpty);
      expect(data['recurringTransactions'], isEmpty);
      expect(data['categories'], {'customExpense': [], 'customIncome': []});
      expect(data['settings'], {
        'currency': 'USD',
        'language': 'en',
        'theme': 'cream',
        'monthlyBudget': 0.0,
        'balanceCarryoverEnabled': true,
      });
      expect(() => s.validateBackup(jsonEncode(doc)), returnsNormally);
    });

    test('legacy rows missing newer fields are exported complete', () async {
      await box.put('items', [
        jsonEncode({
          'isExpense': true, 'amount': 5, 'category': '☕ Coffee',
          'note': '', 'date': '2024-01-02T00:00:00.000', 'id': 'old1',
        }),
      ]);
      final row = (service().createBackup()['data']['transactions'] as List).single
          as Map<String, dynamic>;
      expect(row['paymentMethod'], '');
      expect(row['baseAmount'], 5.0);
      expect(row['currencyMetaVersion'], 0);
      expect(TxItem.fromMap(row).id, 'old1');
    });

    test('file name is readable and dated', () {
      expect(service().suggestedFileName(), 'doni-money-backup-2026-11-04.json');
    });
  });

  group('validateBackup rejects', () {
    late Map<String, dynamic> good;
    setUp(() async {
      await seed();
      good = service().createBackup();
    });

    BackupErrorCode codeOf(String raw) {
      try {
        service().validateBackup(raw);
      } on BackupException catch (e) {
        return e.code;
      }
      fail('expected BackupException');
    }

    Map<String, dynamic> mutate(void Function(Map<String, dynamic> d) f) {
      final copy = jsonDecode(jsonEncode(good)) as Map<String, dynamic>;
      f(copy);
      return copy;
    }

    test('malformed JSON', () {
      expect(codeOf('{"format": "doni_money_backup", '), BackupErrorCode.malformedJson);
      expect(codeOf('not json'), BackupErrorCode.malformedJson);
      expect(codeOf('"just a string"'), BackupErrorCode.malformedJson);
      expect(codeOf('42'), BackupErrorCode.malformedJson);
    });

    test('wrong format / other app', () {
      expect(codeOf(jsonEncode(mutate((d) => d['format'] = 'other_app_backup'))),
          BackupErrorCode.wrongFormat);
      expect(codeOf(jsonEncode(mutate((d) => d.remove('format')))), BackupErrorCode.wrongFormat);
      expect(codeOf(jsonEncode({'app': 'some_other_app', 'data': {'items': []}})),
          BackupErrorCode.wrongFormat);
      expect(codeOf('{}'), BackupErrorCode.wrongFormat);
      expect(codeOf(jsonEncode({'entries': [], 'version': 1})), BackupErrorCode.wrongFormat);
    });

    test('unsupported schemaVersion', () {
      for (final v in [2, 0, '1', null, 1.5]) {
        expect(codeOf(jsonEncode(mutate((d) => d['schemaVersion'] = v))),
            BackupErrorCode.unsupportedSchemaVersion, reason: 'schemaVersion=$v');
      }
    });

    test('missing required data', () {
      expect(codeOf(jsonEncode(mutate((d) => d.remove('data')))), BackupErrorCode.missingField);
      expect(codeOf(jsonEncode(mutate((d) => (d['data'] as Map).remove('transactions')))),
          BackupErrorCode.missingField);
      expect(codeOf(jsonEncode(mutate((d) => (d['data']['settings'] as Map).remove('currency')))),
          BackupErrorCode.missingField);
      expect(codeOf(jsonEncode(mutate((d) => (d['data']['transactions'][0] as Map).remove('amount')))),
          BackupErrorCode.missingField);
    });

    test('field with wrong type', () {
      expect(codeOf(jsonEncode(mutate((d) => d['data']['transactions'][0]['amount'] = '12000'))),
          BackupErrorCode.invalidType);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['transactions'][0]['isExpense'] = 'yes'))),
          BackupErrorCode.invalidType);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['transactions'] = {'a': 1}))),
          BackupErrorCode.invalidType);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['settings']['monthlyBudget'] = '5'))),
          BackupErrorCode.invalidType);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['categories']['customExpense'] = [1]))),
          BackupErrorCode.invalidType);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['recurringTransactions'][0]['dayOfMonth'] = 'x'))),
          BackupErrorCode.invalidType);
    });

    test('unusable values', () {
      expect(codeOf(jsonEncode(mutate((d) => d['data']['transactions'][0]['date'] = 'yesterday'))),
          BackupErrorCode.invalidValue);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['settings']['theme'] = 'neon'))),
          BackupErrorCode.invalidValue);
      expect(codeOf(jsonEncode(mutate((d) => d['data']['settings']['currency'] = 'XYZ'))),
          BackupErrorCode.invalidValue);
    });
  });

  group('restoreBackup', () {
    test('restores everything and app readers see it', () async {
      await seed();
      final json = service().createBackupJson();

      // Wipe to a fresh-install state, keeping a different passcode.
      await box.clear();
      await box.putAll({'lockEnabled': true, 'lockPasscode': '9999'});

      final restored = await service().restoreBackup(json);
      expect(restored.transactions.length, 2);

      final repo = TxRepo();
      expect(repo.items.map((e) => e['id']), ['a', 'bb']);
      expect(repo.items.map(TxItem.fromMap).first.amount, 12000);
      expect(RecurringItem.loadAll().single.dayOfMonth, 15);
      expect(CategoryStore.customExpense(), ['🐶 Pet']);
      expect(CategoryStore.expenseCategories().last, '🐶 Pet');
      expect(CategoryStore.customIncome(), ['🪙 Side job']);
      expect(box.get('selectedCurrency'), 'KRW');
      expect(box.get('selectedLanguage'), 'ko');
      expect(box.get('selectedTheme'), 'dog_dark');
      expect(box.get('monthlyBudget'), 500000.0);
      expect(box.get('balance_carryover_enabled'), false);
      // Device security state is never touched.
      expect(box.get('lockPasscode'), '9999');
      expect(box.get('lockEnabled'), true);
    });

    test('empty backup clears data to empty', () async {
      final emptyJson = service().createBackupJson();
      await seed();
      await service().restoreBackup(emptyJson);
      expect(TxRepo().items, isEmpty);
      expect(RecurringItem.loadAll(), isEmpty);
      expect(CategoryStore.customExpense(), isEmpty);
      expect(box.get('selectedCurrency'), 'USD');
      expect(box.get('lockPasscode'), '1234');
    });

    test('invalid input never changes existing data', () async {
      await seed();
      final before = snapshot();
      final good = service().createBackup();

      final bad = <String>[
        '{oops',
        jsonEncode({...good, 'format': 'something_else'}),
        jsonEncode({...good, 'schemaVersion': 99}),
        jsonEncode({...good, 'data': {...good['data'] as Map, 'settings': null}}),
        // One bad row deep inside an otherwise valid backup.
        jsonEncode({
          ...good,
          'data': {
            ...good['data'] as Map,
            'transactions': [
              (good['data']['transactions'] as List).first,
              {...(good['data']['transactions'] as List).last as Map, 'amount': 'lots'},
            ],
          },
        }),
      ];
      for (final raw in bad) {
        await expectLater(service().restoreBackup(raw), throwsA(isA<BackupException>()));
        expect(snapshot(), before, reason: raw);
      }
    });

    test('storage failure during write rolls back and keeps data', () async {
      await seed();
      final otherJson = BackupService(box: box, now: () => fixedNow).createBackupJson();
      // Change data so the backup differs from current state.
      await box.put('items', [jsonEncode(tx('zzz', 1))]);
      await box.put('selectedTheme', 'cyber_ai');
      final before = snapshot();

      final failing = BackupService(box: _FailingBox(box), now: () => fixedNow);
      await expectLater(
        failing.restoreBackup(otherJson),
        throwsA(isA<BackupException>()
            .having((e) => e.code, 'code', BackupErrorCode.storageFailure)),
      );
      expect(snapshot(), before);
    });

    test('round trip: backup → change data → restore → original back', () async {
      await seed();
      final original = snapshot();
      final json = service().createBackupJson();

      final repo = TxRepo();
      await repo.removeById('a');
      await repo.updateById('bb', {...tx('bb', 1), 'note': 'edited'});
      await RecurringItem.removeById('r1');
      await CategoryStore.removeExpense('🐶 Pet');
      await CategoryStore.addExpense('🎮 Games');
      await box.putAll({'selectedCurrency': 'USD', 'selectedTheme': 'cream', 'monthlyBudget': 1.0});
      expect(snapshot(), isNot(original));

      var notified = 0;
      repo.addListener(() => notified++);
      await service().restoreBackup(json);
      repo.reloadFromStorage();

      expect(notified, 1);
      expect(snapshot(), original);
      expect(repo.items.map((e) => e['note']), ['note a', 'note bb']);
      // And the restored file re-exports identically (stable schema).
      expect(service().createBackupJson(), json);
    });
  });

  group('legacy easy_financial_ledger import', () {
    // Exactly what the released `_buildBackupPayload()` wrote (file backup
    // and JSON copy share it): rows are TxRepo's stored maps.
    Map<String, dynamic> legacyFile({List<Map<String, dynamic>>? items, Map<String, dynamic>? settings}) => {
          'app': 'easy_financial_ledger',
          'formatVersion': 2,
          'exportedAt': '2025-06-01T10:20:30.000',
          'data': {
            'items': items ?? [tx('L1', 4500), tx('L22', 100000, expense: false)],
            'settings': settings ??
                {'selectedLanguage': 'ja', 'selectedCurrency': 'JPY', 'selectedTheme': 'minimal_black'},
          },
        };

    test('validates and migrates into the current model', () {
      final b = service().validateBackup(jsonEncode(legacyFile()));
      expect(b.isLegacy, isTrue);
      expect(b.schemaVersion, 2);
      expect(b.createdAt, DateTime.parse('2025-06-01T10:20:30.000'));
      expect(b.transactions.map((e) => e['id']), ['L1', 'L22']);
      expect(b.transactions.first['paymentMethod'], 'card');
      expect([b.language, b.currency, b.theme], ['ja', 'JPY', 'minimal_black']);
      // Legacy never carried these: restore must leave them alone.
      expect(b.recurringTransactions, isNull);
      expect(b.customExpenseCategories, isNull);
      expect(b.monthlyBudget, isNull);
      expect(b.balanceCarryoverEnabled, isNull);
    });

    test('restore replaces transactions + settings, keeps everything else', () async {
      await seed();
      await service().restoreBackup(jsonEncode(legacyFile()));

      final items = TxRepo().items.map(TxItem.fromMap).toList();
      expect(items.map((e) => e.id), ['L1', 'L22']);
      expect(items.last.isExpense, isFalse);
      expect(items.first.paymentMethod, 'card');
      expect(box.get('selectedLanguage'), 'ja');
      expect(box.get('selectedCurrency'), 'JPY');
      expect(box.get('selectedTheme'), 'minimal_black');
      // Untouched: not part of legacy backups.
      expect(RecurringItem.loadAll().single.id, 'r1');
      expect(CategoryStore.customExpense(), ['🐶 Pet']);
      expect(box.get('monthlyBudget'), 500000.0);
      expect(box.get('balance_carryover_enabled'), false);
      expect(box.get('lockPasscode'), '1234');
      expect(box.get('lockEnabled'), true);
    });

    test('older unmarked shapes the released importers accepted', () async {
      final bare = [
        {'isExpense': true, 'amount': 7, 'category': '☕ Coffee', 'note': 'x', 'date': '2023-03-04'},
      ];
      final b1 = service().validateBackup(jsonEncode(bare));
      expect(b1.isLegacy, isTrue);
      expect(b1.transactions.single['id'], isNotEmpty); // generated
      expect(b1.transactions.single['date'], '2023-03-04T00:00:00.000');
      expect(b1.transactions.single['amount'], 7.0);
      expect(b1.language, isNull);

      final rootItems = {'items': bare, 'settings': {'selectedLanguage': 'es'}};
      final b2 = service().validateBackup(jsonEncode(rootItems));
      expect(b2.transactions.length, 1);
      expect(b2.language, 'es');

      await service().restoreBackup(jsonEncode(bare));
      expect(TxItem.fromMap(TxRepo().items.single).category, '☕ Coffee');
    });

    test('settings the old app would ignore are skipped, not written', () async {
      await seed();
      await service().restoreBackup(jsonEncode(legacyFile(
        settings: {'selectedLanguage': 'fr', 'selectedCurrency': 'XYZ', 'selectedTheme': 'neon'},
      )));
      expect(box.get('selectedLanguage'), 'ko');
      expect(box.get('selectedCurrency'), 'KRW');
      expect(box.get('selectedTheme'), 'dog_dark');
    });

    test('after legacy restore, export is the current format', () async {
      await service().restoreBackup(jsonEncode(legacyFile()));
      final doc = service().createBackup();
      expect(doc['format'], 'doni_money_backup');
      expect(service().validateBackup(jsonEncode(doc)).isLegacy, isFalse);
    });

    test('invalid legacy files never change existing data', () async {
      await seed();
      final before = snapshot();
      Map<String, dynamic> row(Map<String, dynamic> patch) => {...tx('L1', 1), ...patch};
      final bad = <(String, BackupErrorCode)>[
        (jsonEncode({...legacyFile(), 'formatVersion': 3}), BackupErrorCode.unsupportedSchemaVersion),
        (jsonEncode({'app': 'easy_financial_ledger', 'formatVersion': 2, 'data': {}}), BackupErrorCode.missingField),
        (jsonEncode(legacyFile(items: [row({'amount': '4500'})])), BackupErrorCode.invalidType),
        (jsonEncode(legacyFile(items: [row({'isExpense': 'true'})])), BackupErrorCode.invalidType),
        (jsonEncode(legacyFile(items: [row({'date': 'not a date'})])), BackupErrorCode.invalidValue),
        (jsonEncode(legacyFile(items: [tx('ok', 1), {...tx('L2', 1)}..remove('date')])), BackupErrorCode.missingField),
        (jsonEncode(legacyFile(items: [row({})], settings: null)..['data']['settings'] = 'ko'), BackupErrorCode.invalidType),
        (jsonEncode([1, 2]), BackupErrorCode.invalidType),
      ];
      for (final (raw, code) in bad) {
        await expectLater(
          service().restoreBackup(raw),
          throwsA(isA<BackupException>().having((e) => e.code, 'code', code)),
          reason: raw,
        );
        expect(snapshot(), before, reason: raw);
      }
    });
  });
}
