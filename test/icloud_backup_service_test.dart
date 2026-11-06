import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:simple_ledger/services/backup_service.dart';
import 'package:simple_ledger/services/icloud_backup_service.dart';
import 'package:simple_ledger/services/icloud_backup_storage.dart';
import 'package:simple_ledger/storage.dart';

/// In-memory stand-in for the native container. Mirrors the native
/// contract: a failed write leaves the previous file untouched.
class FakeICloudStorage implements ICloudBackupStorage {
  ICloudAvailability availabilityValue = ICloudAvailability.available;
  String? stored;
  DateTime? modifiedAt;
  bool discoveryTimedOut = false;
  bool notDownloaded = false;
  ICloudStorageException? readError;
  ICloudStorageException? writeError;
  bool isUploaded = true;
  int calls = 0;
  int writes = 0;

  @override
  Future<ICloudAvailability> availability() async {
    calls++;
    return availabilityValue;
  }

  @override
  Future<CloudFileState> inspectLatest() async {
    calls++;
    return CloudFileState(
      exists: stored != null,
      discoveryTimedOut: discoveryTimedOut,
      downloadStatus: notDownloaded ? CloudDownloadStatus.notDownloaded : CloudDownloadStatus.current,
      modifiedAt: modifiedAt,
      isUploaded: isUploaded,
    );
  }

  @override
  Future<CloudReadResult> readLatest({Duration timeout = const Duration(seconds: 30)}) async {
    calls++;
    if (readError != null) throw readError!;
    if (stored == null) {
      throw const ICloudStorageException(ICloudStorageErrorCode.noBackup, 'none');
    }
    if (notDownloaded) {
      throw const ICloudStorageException(ICloudStorageErrorCode.downloadPending, 'downloading');
    }
    return CloudReadResult(
      stored!,
      CloudFileState(exists: true, isUploaded: isUploaded, modifiedAt: modifiedAt),
    );
  }

  @override
  Future<CloudWriteResult> writeLatest(String json) async {
    calls++;
    if (writeError != null) throw writeError!;
    writes++;
    stored = json;
    modifiedAt = DateTime(2026, 11, 4, 13);
    return CloudWriteResult(isUploaded: isUploaded, isUploading: !isUploaded);
  }
}

/// Box whose `putAll` always fails, to break a restore mid-write.
class _FailingBox implements Box {
  final Box inner;
  _FailingBox(this.inner);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => inner.get(key, defaultValue: defaultValue);
  @override
  bool containsKey(dynamic key) => inner.containsKey(key);
  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) => throw HiveError('disk full');
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => inner.deleteAll(keys);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tmp;
  late Box box;
  late FakeICloudStorage cloud;
  var premium = true;
  final now = DateTime(2026, 11, 4, 13, 5);

  ICloudBackupService service({Box? onBox}) => ICloudBackupService(
        storage: cloud,
        backupService: BackupService(box: onBox ?? box, now: () => now),
        isPremium: () => premium,
      );

  String row(String id, double amount) => jsonEncode({
        'id': id,
        'isExpense': true,
        'amount': amount,
        'category': '🍔 Food',
        'note': id,
        'date': '2026-11-01T12:00:00.000',
        'entryCurrency': 'KRW',
        'baseAmount': amount,
        'baseCurrency': 'KRW',
        'exchangeRate': 1.0,
        'currencyMetaVersion': 1,
        'paymentMethod': 'card',
      });

  Future<void> seed() async {
    await box.putAll({
      'items': [row('a', 1000), row('b', 2000), row('c', 3000)],
      'selectedCurrency': 'KRW',
      'selectedTheme': 'dog',
      'monthlyBudget': 50000.0,
      'lockEnabled': true,
      'lockPasscode': '2580',
    });
  }

  Map<String, String> snapshot() => {
        for (final k in [...BackupService.managedKeys, 'lockEnabled', 'lockPasscode'])
          k: jsonEncode(box.get(k)),
      };

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('icloud_test');
    Hive.init(tmp.path);
    box = await Hive.openBox(Storage.txBoxName);
    cloud = FakeICloudStorage();
    premium = true;
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  group('Premium gating', () {
    test('non-Premium never touches iCloud and every action is refused', () async {
      premium = false;
      final s = service();
      expect((await s.loadStatus()).issue, ICloudBackupIssue.premiumRequired);
      await expectLater(s.backUpNow(), throwsA(_issue(ICloudBackupIssue.premiumRequired)));
      await expectLater(s.prepareRestore(), throwsA(_issue(ICloudBackupIssue.premiumRequired)));
      await expectLater(
        s.restore(const PreparedCloudRestore('{}', _dummyBackup)),
        throwsA(_issue(ICloudBackupIssue.premiumRequired)),
      );
      expect(cloud.calls, 0);
    });
  });

  group('status', () {
    test('backup metadata is read from the backup itself', () async {
      await seed();
      await service().backUpNow(appVersion: '1.5.0+12');
      final st = await service().loadStatus();
      expect(st.issue, isNull);
      expect(st.backup!.createdAt, now.toUtc());
      expect(st.backup!.appVersion, '1.5.0+12');
      expect(st.backup!.transactions.length, 3);
      expect(st.backup!.schemaVersion, 1);
      expect(st.isUploaded, isTrue);
    });

    test('no backup', () async {
      expect((await service().loadStatus()).issue, ICloudBackupIssue.noBackup);
    });

    test('discovery still gathering is not reported as "no backup"', () async {
      cloud.discoveryTimedOut = true;
      expect((await service().loadStatus()).issue, ICloudBackupIssue.syncInProgress);
    });

    test('exists but not downloaded yet → downloadPending (not "no backup")', () async {
      await seed();
      await service().backUpNow();
      cloud.notDownloaded = true;
      final st = await service().loadStatus();
      expect(st.issue, ICloudBackupIssue.downloadPending);
      expect(st.cloudModifiedAt, isNotNull);
    });

    test('iCloud unavailable states are distinct', () async {
      cloud.availabilityValue = ICloudAvailability.notSignedIn;
      expect((await service().loadStatus()).issue, ICloudBackupIssue.notSignedIn);
      cloud.availabilityValue = ICloudAvailability.containerUnavailable;
      expect((await service().loadStatus()).issue, ICloudBackupIssue.containerUnavailable);
      cloud.availabilityValue = ICloudAvailability.unsupportedPlatform;
      expect((await service().loadStatus()).issue, ICloudBackupIssue.unsupportedPlatform);
      await expectLater(service().backUpNow(), throwsA(_issue(ICloudBackupIssue.unsupportedPlatform)));
    });

    test('malformed cloud backup → corrupted', () async {
      cloud.stored = '{"format": "doni_money_backup", "schemaVer';
      expect((await service().loadStatus()).issue, ICloudBackupIssue.corrupted);
      cloud.stored = jsonEncode({'format': 'someone_else'});
      expect((await service().loadStatus()).issue, ICloudBackupIssue.corrupted);
    });

    test('unsupported schemaVersion → unsupportedVersion', () async {
      await seed();
      await service().backUpNow();
      final doc = jsonDecode(cloud.stored!) as Map<String, dynamic>;
      cloud.stored = jsonEncode({...doc, 'schemaVersion': 2});
      expect((await service().loadStatus()).issue, ICloudBackupIssue.unsupportedVersion);
    });

    test('read/download failure → readFailed', () async {
      cloud.stored = '{}';
      cloud.readError = const ICloudStorageException(ICloudStorageErrorCode.readFailed, 'io');
      expect((await service().loadStatus()).issue, ICloudBackupIssue.readFailed);
    });
  });

  group('Back Up Now', () {
    test('uploads exactly the BackupService JSON, without Premium/passcode', () async {
      await seed();
      final r = await service().backUpNow(appVersion: '1.5.0+12');
      expect(r.isUploaded, isTrue);
      expect(cloud.stored, BackupService(box: box, now: () => now).createBackupJson(appVersion: '1.5.0+12'));
      expect(cloud.stored, isNot(contains('2580')));
      expect(cloud.stored, isNot(contains('lockPasscode')));
      expect(cloud.stored, isNot(contains('is_premium')));
    });

    test('saved but not yet uploaded is reported', () async {
      cloud.isUploaded = false;
      final r = await service().backUpNow();
      expect(r.isUploaded, isFalse);
      expect(r.isUploading, isTrue);
    });

    test('failed upload keeps the previous good backup', () async {
      await seed();
      await service().backUpNow();
      final good = cloud.stored;

      await box.put('items', [row('x', 1)]);
      cloud.writeError = const ICloudStorageException(ICloudStorageErrorCode.verifyFailed, 'mismatch');
      await expectLater(service().backUpNow(), throwsA(_issue(ICloudBackupIssue.writeFailed)));

      expect(cloud.stored, good);
      cloud.writeError = null;
      expect((await service().loadStatus()).backup!.transactions.length, 3);
    });

    test('invalid local data is never uploaded', () async {
      await seed();
      await service().backUpNow();
      final good = cloud.stored;
      await box.put('items', [jsonEncode({'id': 'bad', 'isExpense': true, 'amount': 1, 'category': 'x', 'date': ''})]);
      await expectLater(service().backUpNow(), throwsA(_issue(ICloudBackupIssue.writeFailed)));
      await box.put('items', ['not json']);
      await expectLater(service().backUpNow(), throwsA(_issue(ICloudBackupIssue.writeFailed)));
      expect(cloud.writes, 1);
      expect(cloud.stored, good);
    });
  });

  group('Restore from iCloud', () {
    test('round trip restores data; passcode untouched', () async {
      await seed();
      await service().backUpNow();
      String exported() => BackupService(box: box, now: () => now).createBackupJson();
      final original = exported();

      await box.putAll({'items': [row('z', 9)], 'selectedTheme': 'cream', 'lockPasscode': '1111'});
      final prepared = await service().prepareRestore();
      expect(prepared.backup.transactions.length, 3);
      await service().restore(prepared);

      // What the app reads back is identical to before the change.
      expect(exported(), original);
      expect(box.get('lockPasscode'), '1111');
      expect(box.get('lockEnabled'), true);
    });

    test('download / validation / write failures leave local data unchanged', () async {
      await seed();
      await service().backUpNow();
      await box.put('items', [row('local', 5)]);
      final before = snapshot();

      cloud.notDownloaded = true;
      await expectLater(service().prepareRestore(), throwsA(_issue(ICloudBackupIssue.downloadPending)));
      cloud.notDownloaded = false;

      final good = cloud.stored!;
      cloud.stored = good.substring(0, good.length ~/ 2);
      await expectLater(service().prepareRestore(), throwsA(_issue(ICloudBackupIssue.corrupted)));
      cloud.stored = good;

      cloud.readError = const ICloudStorageException(ICloudStorageErrorCode.readFailed, 'io');
      await expectLater(service().prepareRestore(), throwsA(_issue(ICloudBackupIssue.readFailed)));
      cloud.readError = null;

      final prepared = await service().prepareRestore();
      await expectLater(
        service(onBox: _FailingBox(box)).restore(prepared),
        throwsA(_issue(ICloudBackupIssue.restoreFailed)),
      );

      expect(snapshot(), before);
    });

    test('no backup', () async {
      await expectLater(service().prepareRestore(), throwsA(_issue(ICloudBackupIssue.noBackup)));
    });
  });
}

Matcher _issue(ICloudBackupIssue issue) =>
    isA<ICloudBackupException>().having((e) => e.issue, 'issue', issue);

const _dummyBackup = ValidatedBackup(
  source: BackupSource.current,
  schemaVersion: 1,
  createdAt: null,
  appVersion: null,
  transactions: [],
  recurringTransactions: null,
  customExpenseCategories: null,
  customIncomeCategories: null,
  currency: null,
  language: null,
  theme: null,
  monthlyBudget: null,
  balanceCarryoverEnabled: null,
);
