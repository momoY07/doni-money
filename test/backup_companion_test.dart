import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:simple_ledger/companion/companion_character.dart';
import 'package:simple_ledger/services/backup_service.dart';
import 'package:simple_ledger/services/icloud_backup_service.dart';
import 'package:simple_ledger/storage.dart';

import 'icloud_backup_service_test.dart' show FakeICloudStorage;

void main() {
  late Directory tmp;
  late Box box;
  final fixedNow = DateTime(2026, 11, 18, 9);
  BackupService service() => BackupService(box: box, now: () => fixedNow);
  const key = CompanionCharacter.storageKey;

  Map<String, dynamic> row(String id) => {
        'id': id,
        'isExpense': true,
        'amount': 1200.0,
        'category': '☕ Coffee',
        'note': '',
        'date': '2026-11-02T12:00:00.000',
        'entryCurrency': 'KRW',
        'baseAmount': 1200.0,
        'baseCurrency': 'KRW',
        'exchangeRate': 1.0,
        'currencyMetaVersion': 1,
        'paymentMethod': '',
      };

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_companion');
    Hive.init(tmp.path);
    box = await Hive.openBox(Storage.txBoxName);
    await box.putAll({
      'items': [jsonEncode(row('a'))],
      'selectedCurrency': 'KRW',
      'selectedTheme': 'cream',
      'lockEnabled': true,
      'lockPasscode': '2580',
    });
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  test('companion preference round trip (file backup)', () async {
    await box.put(key, 'cyber');
    final json = service().createBackupJson(appVersion: '1.6.0+13');
    final doc = jsonDecode(json) as Map<String, dynamic>;
    expect(doc['schemaVersion'], 1, reason: 'additive optional field: schema stays v1');
    expect(doc['data']['settings']['companionCharacter'], 'cyber');

    await box.put(key, 'dog');
    final restored = await service().restoreBackup(json);
    expect(restored.companionCharacter, 'cyber');
    expect(box.get(key), 'cyber');
  });

  test('iCloud backup carries the companion through the same engine', () async {
    final cloud = FakeICloudStorage();
    final icloud = ICloudBackupService(
        storage: cloud, backupService: service(), isPremium: () => true);
    await box.put(key, 'dog');
    await icloud.backUpNow(appVersion: '1.6.0+13');
    expect(jsonDecode(cloud.stored!)['data']['settings']['companionCharacter'], 'dog');

    await box.put(key, 'otter');
    final prepared = await icloud.prepareRestore();
    expect(prepared.backup.companionCharacter, 'dog');
    await icloud.restore(prepared);
    expect(box.get(key), 'dog');
  });

  test('no explicit choice → field omitted, theme default stays implicit', () {
    final settings = service().createBackup()['data']['settings'] as Map;
    expect(settings.containsKey('companionCharacter'), isFalse);
  });

  test('old schema-v1 backup without companion still restores and keeps the device choice', () async {
    await box.put(key, 'dog');
    final doc = service().createBackup();
    (doc['data']['settings'] as Map).remove('companionCharacter');
    final b = await service().restoreBackup(jsonEncode(doc));
    expect(b.companionCharacter, isNull);
    expect(box.get(key), 'dog');
  });

  test('a backup restored on a device with no choice leaves it following the theme', () async {
    final doc = service().createBackup();
    await service().restoreBackup(jsonEncode(doc));
    expect(box.containsKey(key), isFalse);
  });

  test('invalid companion values fall back safely instead of failing the restore', () async {
    await box.put(key, 'otter');
    for (final bad in <Object?>['dragon', 42, true, '', null, {'id': 'dog'}]) {
      final doc = service().createBackup();
      final data = Map<String, dynamic>.from(doc['data'] as Map);
      data['settings'] = <String, dynamic>{...data['settings'] as Map, 'companionCharacter': bad};
      doc['data'] = data;
      final b = await service().restoreBackup(jsonEncode(doc));
      expect(b.companionCharacter, isNull, reason: '$bad');
      expect(box.get(key), 'otter', reason: '$bad');
    }
  });

  test('unknown extra settings keys are ignored (how older app versions read new backups)', () {
    final doc = service().createBackup();
    (doc['data']['settings'] as Map)['someFutureSetting'] = 'x';
    expect(() => service().validateBackup(jsonEncode(doc)), returnsNormally);
  });

  test('legacy easy_financial_ledger backups still restore and leave the companion alone', () async {
    await box.put(key, 'cyber');
    final legacy = {
      'app': 'easy_financial_ledger',
      'formatVersion': 2,
      'exportedAt': '2025-06-01T10:20:30.000',
      'data': {
        'items': [row('L1')],
        'settings': {'selectedLanguage': 'ja', 'selectedCurrency': 'JPY', 'selectedTheme': 'dog'},
      },
    };
    final b = await service().restoreBackup(jsonEncode(legacy));
    expect(b.isLegacy, isTrue);
    expect(b.companionCharacter, isNull);
    expect(box.get('selectedTheme'), 'dog');
    expect(box.get(key), 'cyber', reason: 'theme change must not overwrite the explicit companion');

    // Bare legacy list too.
    await service().restoreBackup(jsonEncode([row('L2')]));
    expect(box.get(key), 'cyber');
  });

  test('Premium status and passcode are still never included', () async {
    await box.put(key, 'dog');
    final json = service().createBackupJson();
    for (final s in ['is_premium', 'isPremium', 'premium', 'dev_mode', 'lockPasscode', 'lockEnabled', '2580']) {
      expect(json.contains(s), isFalse, reason: s);
    }
  });

  test('restore never touches passcode settings', () async {
    await box.put(key, 'dog');
    final json = service().createBackupJson();
    await box.putAll({'lockEnabled': false, 'lockPasscode': '9999'});
    await service().restoreBackup(json);
    expect(box.get('lockEnabled'), isFalse);
    expect(box.get('lockPasscode'), '9999');
    expect(BackupService.managedKeys, contains(key));
    expect(BackupService.managedKeys, isNot(contains('lockPasscode')));
  });
}
