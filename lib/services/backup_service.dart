import 'dart:convert';

import 'package:hive/hive.dart';

import '../storage.dart';

/// Why a backup was rejected. UI maps these to user-facing messages.
enum BackupErrorCode {
  /// Not valid JSON, or the root is not a JSON object.
  malformedJson,

  /// Valid JSON but not a Doni Money backup (missing/foreign `format`).
  wrongFormat,

  /// `schemaVersion` is missing, not an int, or not supported by this build.
  unsupportedSchemaVersion,

  /// A required section or field is absent.
  missingField,

  /// A field is present but has the wrong JSON type.
  invalidType,

  /// A field has the right type but a value this app can't use.
  invalidValue,

  /// Writing the restored data to storage failed (existing data rolled back).
  storageFailure,
}

class BackupException implements Exception {
  final BackupErrorCode code;
  final String message;

  const BackupException(this.code, this.message);

  @override
  String toString() => 'BackupException(${code.name}): $message';
}

/// Where a validated backup came from.
enum BackupSource {
  /// `doni_money_backup` (this engine). Contains every backed-up section.
  current,

  /// Legacy `easy_financial_ledger` export (formatVersion 2) or the older
  /// unmarked shapes the released importers accepted: `[items...]` and
  /// `{"items": [...], "settings": {...}}`. Contains only transactions and,
  /// optionally, language/currency/theme.
  legacy,
}

/// A fully validated backup, ready to be written to storage.
///
/// Values are already in the shape the app reads at runtime, so restoring
/// is only a matter of writing them. A `null` section means "not in this
/// backup": restore leaves the current value alone (legacy files only).
class ValidatedBackup {
  final BackupSource source;
  final int schemaVersion;
  final DateTime? createdAt;
  final String? appVersion;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>>? recurringTransactions;
  final List<String>? customExpenseCategories;
  final List<String>? customIncomeCategories;
  final String? currency;
  final String? language;
  final String? theme;
  final double? monthlyBudget;
  final bool? balanceCarryoverEnabled;

  const ValidatedBackup({
    required this.source,
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.transactions,
    required this.recurringTransactions,
    required this.customExpenseCategories,
    required this.customIncomeCategories,
    required this.currency,
    required this.language,
    required this.theme,
    required this.monthlyBudget,
    required this.balanceCarryoverEnabled,
  });

  bool get isLegacy => source == BackupSource.legacy;
}

/// Local, versioned backup/restore of all persistent user data.
///
/// Pure Dart over a Hive [Box]: no Flutter UI, no platform plugins, so the
/// same engine can feed a file share today and a cloud sync later.
///
/// Backed up (all in [Storage.txBoxName]):
///   items, recurringItems, customExpenseCategories, customIncomeCategories,
///   selectedCurrency, selectedLanguage, selectedTheme, monthlyBudget,
///   balance_carryover_enabled
///
/// Deliberately NOT backed up:
///   lockEnabled / lockPasscode  – device security; a plaintext passcode must
///                                 not travel in a shareable file, and restoring
///                                 it could lock the user out on a new device.
///   SharedPreferences           – is_premium / dev_mode (StoreKit entitlement,
///                                 re-derived from the App Store), onboarding_done,
///                                 review_requested / transaction_count_for_review
///                                 (device/UX state).
///   Alternate app icon          – OS-level device state.
/// Restore never touches any of these.
class BackupService {
  static const String format = 'doni_money_backup';
  static const int currentSchemaVersion = 1;
  static const Set<int> supportedSchemaVersions = {1};

  /// Legacy export marker written by app versions before this engine.
  static const String legacyApp = 'easy_financial_ledger';
  static const Set<int> supportedLegacyFormatVersions = {1, 2};

  // Hive keys (must match the rest of the app).
  static const String kItems = 'items';
  static const String kRecurring = 'recurringItems';
  static const String kCustomExpense = 'customExpenseCategories';
  static const String kCustomIncome = 'customIncomeCategories';
  static const String kCurrency = 'selectedCurrency';
  static const String kLanguage = 'selectedLanguage';
  static const String kTheme = 'selectedTheme';
  static const String kBudget = 'monthlyBudget';
  static const String kCarryover = 'balance_carryover_enabled';

  /// Every key restore may write. Nothing outside this set is modified.
  static const List<String> managedKeys = [
    kItems,
    kRecurring,
    kCustomExpense,
    kCustomIncome,
    kCurrency,
    kLanguage,
    kTheme,
    kBudget,
    kCarryover,
  ];

  // Defaults mirror the defaultValue used by the app's readers.
  static const String defaultCurrency = 'USD';
  static const String defaultLanguage = 'en';
  static const String defaultTheme = 'cream';

  static const Set<String> supportedLanguages = {'en', 'ko', 'es', 'zh', 'ja'};
  static const Set<String> supportedCurrencies = {
    'USD', 'KRW', 'EUR', 'JPY', 'GBP', 'CAD', 'AUD',
    'CNY', 'HKD', 'SGD', 'MXN', 'BRL', 'THB', 'VND',
  };
  static const Set<String> supportedThemes = {
    'cream', 'otter_light', 'otter_dark', 'otter_system',
    'dog', 'dog_dark', 'dog_system', 'minimal_black', 'cyber_ai',
  };
  static const Set<String> supportedFrequencies = {'monthly', 'weekly'};

  final Box _box;
  final DateTime Function() _now;

  BackupService({Box? box, DateTime Function()? now})
      : _box = box ?? Storage.txBox,
        _now = now ?? DateTime.now;

  // ───────────────────────────── create ─────────────────────────────

  /// Builds the backup document from current storage.
  ///
  /// The result always passes [validateBackup]; if stored data is too
  /// corrupt to round-trip, this throws instead of producing a bad file.
  Map<String, dynamic> createBackup({String? appVersion}) {
    final doc = <String, dynamic>{
      'format': format,
      'schemaVersion': currentSchemaVersion,
      'createdAt': _now().toUtc().toIso8601String(),
      'appVersion': ?appVersion,
      'data': {
        'transactions': _readTransactions(),
        'recurringTransactions': _readJsonList(kRecurring),
        'categories': {
          'customExpense': _readStringList(kCustomExpense),
          'customIncome': _readStringList(kCustomIncome),
        },
        'settings': {
          'currency': _readString(kCurrency, defaultCurrency),
          'language': _readString(kLanguage, defaultLanguage),
          'theme': _readString(kTheme, defaultTheme),
          'monthlyBudget': _readNum(kBudget, 0.0),
          'balanceCarryoverEnabled': _box.get(kCarryover, defaultValue: true) == true,
        },
      },
    };
    // Self-check: never hand the user a file we would refuse to restore.
    validateBackupMap(doc);
    return doc;
  }

  /// Pretty-printed JSON for [createBackup].
  String createBackupJson({String? appVersion}) =>
      const JsonEncoder.withIndent('  ').convert(createBackup(appVersion: appVersion));

  /// e.g. `doni-money-backup-2026-11-04.json` (local date).
  String suggestedFileName() {
    final d = _now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'doni-money-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }

  // ──────────────────────────── validate ────────────────────────────

  /// Parses and fully validates a backup JSON string. Never touches storage.
  /// Accepts current and legacy files; legacy data is validated and migrated
  /// into a [ValidatedBackup] here, before anything could be written.
  /// Throws [BackupException] on any problem.
  ValidatedBackup validateBackup(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (e) {
      throw BackupException(BackupErrorCode.malformedJson, 'Invalid JSON: ${e.message}');
    }
    if (decoded is List) return _validateLegacy(items: decoded, settings: null, root: null);
    if (decoded is! Map) {
      throw const BackupException(
          BackupErrorCode.malformedJson, 'Root must be a JSON object');
    }
    return validateBackupMap(Map<String, dynamic>.from(decoded));
  }

  /// Same as [validateBackup] for an already-decoded JSON object.
  ValidatedBackup validateBackupMap(Map<String, dynamic> root) {
    if (root.containsKey('format')) {
      if (root['format'] != format) {
        throw const BackupException(
            BackupErrorCode.wrongFormat, 'Not a Doni Money backup file');
      }
      return _validateCurrent(root);
    }
    if (root.containsKey('app')) {
      if (root['app'] != legacyApp) {
        throw const BackupException(
            BackupErrorCode.wrongFormat, 'Not a Doni Money backup file');
      }
      return _validateLegacyRoot(root);
    }
    // Unmarked legacy shape: only accepted if it actually carries items.
    final data = root['data'];
    if (root.containsKey('items') || (data is Map && data.containsKey('items'))) {
      return _validateLegacyRoot(root);
    }
    throw const BackupException(
        BackupErrorCode.wrongFormat, 'Not a Doni Money backup file');
  }

  ValidatedBackup _validateCurrent(Map<String, dynamic> root) {
    final version = root['schemaVersion'];
    if (version is! int || !supportedSchemaVersions.contains(version)) {
      throw BackupException(BackupErrorCode.unsupportedSchemaVersion,
          'Unsupported schemaVersion: $version');
    }

    final createdAtRaw = _req<String>(root, 'createdAt', 'createdAt');
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const BackupException(BackupErrorCode.invalidValue, 'createdAt is not a valid date');
    }
    final appVersion = _opt<String>(root, 'appVersion', 'appVersion');

    final data = _reqMap(root, 'data', 'data');

    final txRaw = _req<List>(data, 'transactions', 'data.transactions');
    final transactions = <Map<String, dynamic>>[];
    for (var i = 0; i < txRaw.length; i++) {
      transactions.add(_validateTransaction(txRaw[i], 'data.transactions[$i]'));
    }

    final recRaw = _req<List>(data, 'recurringTransactions', 'data.recurringTransactions');
    final recurring = <Map<String, dynamic>>[];
    for (var i = 0; i < recRaw.length; i++) {
      recurring.add(_validateRecurring(recRaw[i], 'data.recurringTransactions[$i]'));
    }

    final cats = _reqMap(data, 'categories', 'data.categories');
    final customExpense = _stringList(cats, 'customExpense', 'data.categories.customExpense');
    final customIncome = _stringList(cats, 'customIncome', 'data.categories.customIncome');

    final settings = _reqMap(data, 'settings', 'data.settings');
    final currency = _req<String>(settings, 'currency', 'data.settings.currency');
    final language = _req<String>(settings, 'language', 'data.settings.language');
    final theme = _req<String>(settings, 'theme', 'data.settings.theme');
    final budget = _req<num>(settings, 'monthlyBudget', 'data.settings.monthlyBudget');
    final carryover = _req<bool>(
        settings, 'balanceCarryoverEnabled', 'data.settings.balanceCarryoverEnabled');

    _oneOf(currency, supportedCurrencies, 'data.settings.currency');
    _oneOf(language, supportedLanguages, 'data.settings.language');
    _oneOf(theme, supportedThemes, 'data.settings.theme');
    if (!budget.isFinite || budget < 0) {
      throw const BackupException(
          BackupErrorCode.invalidValue, 'data.settings.monthlyBudget must be a finite number ≥ 0');
    }

    return ValidatedBackup(
      source: BackupSource.current,
      schemaVersion: version,
      createdAt: createdAt,
      appVersion: appVersion,
      transactions: transactions,
      recurringTransactions: recurring,
      customExpenseCategories: customExpense,
      customIncomeCategories: customIncome,
      currency: currency,
      language: language,
      theme: theme,
      monthlyBudget: budget.toDouble(),
      balanceCarryoverEnabled: carryover,
    );
  }

  // ─────────────────────────── legacy import ─────────────────────────

  ValidatedBackup _validateLegacyRoot(Map<String, dynamic> root) {
    final fv = root['formatVersion'];
    if (fv != null && (fv is! int || !supportedLegacyFormatVersions.contains(fv))) {
      throw BackupException(BackupErrorCode.unsupportedSchemaVersion,
          'Unsupported legacy formatVersion: $fv');
    }
    // Released exporter nests under `data`; older importers also read root.
    final Map<String, dynamic> container;
    if (root.containsKey('data')) {
      container = _reqMap(root, 'data', 'data');
    } else {
      container = root;
    }
    final items = _req<List>(container, 'items', root.containsKey('data') ? 'data.items' : 'items');
    final settingsRaw = container['settings'];
    if (settingsRaw != null && settingsRaw is! Map) {
      throw const BackupException(BackupErrorCode.invalidType, 'settings must be an object');
    }
    return _validateLegacy(
      items: items,
      settings: settingsRaw == null ? null : Map<String, dynamic>.from(settingsRaw as Map),
      root: root,
    );
  }

  /// Validates legacy items/settings and migrates them to the current model:
  /// every row gets the full current field set (missing ids are generated),
  /// and settings the legacy app would have ignored are skipped.
  ValidatedBackup _validateLegacy({
    required List items,
    required Map<String, dynamic>? settings,
    required Map<String, dynamic>? root,
  }) {
    DateTime? createdAt;
    final exportedAt = root?['exportedAt'];
    if (exportedAt is String) createdAt = DateTime.tryParse(exportedAt);

    final idBase = _now().microsecondsSinceEpoch;
    final transactions = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final path = 'items[$i]';
      final raw = items[i];
      if (raw is! Map) {
        throw BackupException(BackupErrorCode.invalidType, '$path must be an object');
      }
      final m = Map<String, dynamic>.from(raw);
      final rawId = m['id'];
      if (rawId != null && rawId is! String && rawId is! num) {
        throw BackupException(BackupErrorCode.invalidType, '$path.id must be a string');
      }
      final id = rawId?.toString().trim() ?? '';
      m['id'] = id.isEmpty ? '${idBase + i}' : id;

      final entryCurrency = (_opt<String>(m, 'entryCurrency', '$path.entryCurrency') ?? '').trim();
      final baseCurrency = (_opt<String>(m, 'baseCurrency', '$path.baseCurrency') ?? '').trim();
      final amount = _req<num>(m, 'amount', '$path.amount');
      m['note'] = _opt<String>(m, 'note', '$path.note') ?? '';
      m['entryCurrency'] = entryCurrency;
      m['baseCurrency'] = baseCurrency.isEmpty ? entryCurrency : baseCurrency;
      m['baseAmount'] = _opt<num>(m, 'baseAmount', '$path.baseAmount') ?? amount;
      m['exchangeRate'] = _opt<num>(m, 'exchangeRate', '$path.exchangeRate') ?? 1.0;
      m['currencyMetaVersion'] = _opt<int>(m, 'currencyMetaVersion', '$path.currencyMetaVersion') ??
          (entryCurrency.isEmpty ? 0 : 1);
      m['paymentMethod'] = _opt<String>(m, 'paymentMethod', '$path.paymentMethod') ?? '';
      m['category'] = (_req<String>(m, 'category', '$path.category')).trim();
      final date = DateTime.tryParse(_req<String>(m, 'date', '$path.date'));
      if (date == null) {
        throw BackupException(BackupErrorCode.invalidValue, '$path.date is not a valid date');
      }
      m['date'] = date.toIso8601String();
      // Same checks every current-format row gets.
      transactions.add(_validateTransaction(m, path));
    }

    String? pick(String key, Set<String> allowed) {
      if (settings == null) return null;
      final v = _opt<String>(settings, key, 'settings.$key');
      return v != null && allowed.contains(v) ? v : null;
    }

    return ValidatedBackup(
      source: BackupSource.legacy,
      schemaVersion: (root?['formatVersion'] as int?) ?? 0,
      createdAt: createdAt,
      appVersion: null,
      transactions: transactions,
      recurringTransactions: null,
      customExpenseCategories: null,
      customIncomeCategories: null,
      language: pick('selectedLanguage', supportedLanguages),
      currency: pick('selectedCurrency', supportedCurrencies),
      theme: pick('selectedTheme', supportedThemes),
      monthlyBudget: null,
      balanceCarryoverEnabled: null,
    );
  }

  // ───────────────────────────── restore ────────────────────────────

  /// Validates [rawJson] and, only if it is fully valid, replaces all backed-up
  /// data with it. On any failure existing data is left as it was.
  ///
  /// Order: validate → encode every value into its storage form → one
  /// `putAll` (Hive writes all frames in a single batch and only updates its
  /// in-memory index after the write succeeds). If the write still throws,
  /// the previous values are written back.
  Future<ValidatedBackup> restoreBackup(String rawJson) async {
    final backup = validateBackup(rawJson);
    await _apply(backup);
    return backup;
  }

  Future<void> _apply(ValidatedBackup b) async {
    // Prepare: build every storage value before writing anything.
    // Sections absent from the backup (null, legacy only) are not written.
    final next = <String, dynamic>{
      kItems: b.transactions.map(jsonEncode).toList(),
      if (b.recurringTransactions != null) kRecurring: jsonEncode(b.recurringTransactions),
      if (b.customExpenseCategories != null) kCustomExpense: jsonEncode(b.customExpenseCategories),
      if (b.customIncomeCategories != null) kCustomIncome: jsonEncode(b.customIncomeCategories),
      kCurrency: ?b.currency,
      kLanguage: ?b.language,
      kTheme: ?b.theme,
      kBudget: ?b.monthlyBudget,
      kCarryover: ?b.balanceCarryoverEnabled,
    };

    final previous = <String, dynamic>{
      for (final k in next.keys)
        if (_box.containsKey(k)) k: _box.get(k),
    };
    final previouslyAbsent = next.keys.where((k) => !_box.containsKey(k)).toList();

    try {
      await _box.putAll(next);
    } catch (e) {
      try {
        await _box.putAll(previous);
        await _box.deleteAll(previouslyAbsent);
      } catch (_) {
        // Best effort; original error is what matters to the caller.
      }
      throw BackupException(BackupErrorCode.storageFailure, 'Could not write backup: $e');
    }
  }

  // ───────────────────────── storage readers ────────────────────────

  List<Map<String, dynamic>> _readTransactions() {
    final raw = _box.get(kItems, defaultValue: const <String>[]) as List;
    return raw.map((e) {
      final m = Map<String, dynamic>.from(jsonDecode(e as String) as Map);
      // Fill fields older rows may lack so every exported row is complete.
      // Unknown extra keys are kept as-is.
      final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
      final entryCurrency = (m['entryCurrency'] ?? '').toString();
      return <String, dynamic>{
        ...m,
        'id': (m['id'] ?? '').toString(),
        'isExpense': m['isExpense'] == true,
        'amount': amount,
        'category': (m['category'] ?? '').toString(),
        'note': (m['note'] ?? '').toString(),
        'date': (m['date'] ?? '').toString(),
        'entryCurrency': entryCurrency,
        'baseAmount': (m['baseAmount'] as num?)?.toDouble() ?? amount,
        'baseCurrency': (m['baseCurrency'] ?? entryCurrency).toString(),
        'exchangeRate': (m['exchangeRate'] as num?)?.toDouble() ?? 1.0,
        'currencyMetaVersion': (m['currencyMetaVersion'] as num?)?.toInt() ??
            (entryCurrency.trim().isEmpty ? 0 : 1),
        'paymentMethod': (m['paymentMethod'] ?? '').toString(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _readJsonList(String key) {
    final raw = _box.get(key, defaultValue: '[]') as String;
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<String> _readStringList(String key) {
    final raw = _box.get(key, defaultValue: '[]') as String;
    return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
  }

  String _readString(String key, String fallback) {
    final v = _box.get(key);
    return v is String ? v : fallback;
  }

  double _readNum(String key, double fallback) {
    final v = _box.get(key);
    return v is num ? v.toDouble() : fallback;
  }

  // ─────────────────────────── validators ───────────────────────────

  Map<String, dynamic> _validateTransaction(Object? raw, String path) {
    if (raw is! Map) {
      throw BackupException(BackupErrorCode.invalidType, '$path must be an object');
    }
    final m = Map<String, dynamic>.from(raw);
    final id = _req<String>(m, 'id', '$path.id');
    if (id.trim().isEmpty) {
      throw BackupException(BackupErrorCode.invalidValue, '$path.id must not be empty');
    }
    _req<bool>(m, 'isExpense', '$path.isExpense');
    final amount = _req<num>(m, 'amount', '$path.amount');
    if (!amount.isFinite) {
      throw BackupException(BackupErrorCode.invalidValue, '$path.amount must be finite');
    }
    _req<String>(m, 'category', '$path.category');
    final date = _req<String>(m, 'date', '$path.date');
    if (DateTime.tryParse(date) == null) {
      throw BackupException(BackupErrorCode.invalidValue, '$path.date is not a valid date');
    }
    _opt<String>(m, 'note', '$path.note');
    _opt<String>(m, 'entryCurrency', '$path.entryCurrency');
    _opt<num>(m, 'baseAmount', '$path.baseAmount');
    _opt<String>(m, 'baseCurrency', '$path.baseCurrency');
    _opt<num>(m, 'exchangeRate', '$path.exchangeRate');
    _opt<int>(m, 'currencyMetaVersion', '$path.currencyMetaVersion');
    _opt<String>(m, 'paymentMethod', '$path.paymentMethod');
    // Doubles in storage, same as TxRepo writes them.
    m['amount'] = amount.toDouble();
    if (m['baseAmount'] is num) m['baseAmount'] = (m['baseAmount'] as num).toDouble();
    if (m['exchangeRate'] is num) m['exchangeRate'] = (m['exchangeRate'] as num).toDouble();
    m['note'] ??= '';
    return m;
  }

  Map<String, dynamic> _validateRecurring(Object? raw, String path) {
    if (raw is! Map) {
      throw BackupException(BackupErrorCode.invalidType, '$path must be an object');
    }
    final m = Map<String, dynamic>.from(raw);
    _req<String>(m, 'id', '$path.id');
    _req<bool>(m, 'isExpense', '$path.isExpense');
    final amount = _req<num>(m, 'amount', '$path.amount');
    if (!amount.isFinite) {
      throw BackupException(BackupErrorCode.invalidValue, '$path.amount must be finite');
    }
    _req<String>(m, 'category', '$path.category');
    _opt<String>(m, 'note', '$path.note');
    _opt<String>(m, 'currency', '$path.currency');
    _opt<String>(m, 'paymentMethod', '$path.paymentMethod');
    final freq = _opt<String>(m, 'frequency', '$path.frequency');
    if (freq != null) _oneOf(freq, supportedFrequencies, '$path.frequency');
    _opt<int>(m, 'dayOfMonth', '$path.dayOfMonth');
    _opt<int>(m, 'dayOfWeek', '$path.dayOfWeek');
    _opt<String>(m, 'lastGeneratedKey', '$path.lastGeneratedKey');
    _opt<bool>(m, 'isActive', '$path.isActive');
    m['amount'] = amount.toDouble();
    return m;
  }

  List<String> _stringList(Map<String, dynamic> m, String key, String path) {
    final list = _req<List>(m, key, path);
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! String) {
        throw BackupException(BackupErrorCode.invalidType, '$path[$i] must be a string');
      }
    }
    return list.cast<String>().toList();
  }

  Map<String, dynamic> _reqMap(Map<String, dynamic> m, String key, String path) =>
      Map<String, dynamic>.from(_req<Map>(m, key, path));

  T _req<T>(Map<String, dynamic> m, String key, String path) {
    if (!m.containsKey(key) || m[key] == null) {
      throw BackupException(BackupErrorCode.missingField, 'Missing required field: $path');
    }
    final v = m[key];
    if (v is! T) {
      throw BackupException(BackupErrorCode.invalidType,
          '$path must be ${_typeName<T>()}, got ${v.runtimeType}');
    }
    return v;
  }

  T? _opt<T>(Map<String, dynamic> m, String key, String path) {
    final v = m[key];
    if (v == null) return null;
    if (v is! T) {
      throw BackupException(BackupErrorCode.invalidType,
          '$path must be ${_typeName<T>()}, got ${v.runtimeType}');
    }
    return v;
  }

  void _oneOf(String value, Set<String> allowed, String path) {
    if (!allowed.contains(value)) {
      throw BackupException(BackupErrorCode.invalidValue, '$path has unsupported value "$value"');
    }
  }

  static String _typeName<T>() {
    if (T == String) return 'a string';
    if (T == bool) return 'a boolean';
    if (T == int) return 'an integer';
    if (T == num) return 'a number';
    if (T == List) return 'an array';
    if (T == Map) return 'an object';
    return '$T';
  }
}
