import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/tx_item.dart';
import '../utils/i18n.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../storage.dart';
import '../tx_repo.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';
import 'calendar_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../services/icon_service.dart';
import 'recurring_screen.dart';
import 'categories_screen.dart';
import '../models/recurring_item.dart';
import '../widgets/entry_sheet.dart';
import '../widgets/tx_detail_sheet.dart';
import '../widgets/passcode_lock_screen.dart';
import '../widgets/passcode_setup_sheet.dart';
import '../widgets/passcode_verify_sheet.dart';
import '../services/purchase_service.dart';
import 'paywall_screen.dart';

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> with WidgetsBindingObserver {
  int index = 0;
  String selectedLanguage = 'en';
  String selectedCurrency = 'USD';
  String selectedListFilter = 'all';
  String selectedListQuery = '';
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String selectedTheme = 'cream';
  double _monthlyBudget = 0;

  String get _savedEmoji {
    if (selectedTheme == 'cyber_ai') return '🤖';
    if (selectedTheme.contains('dog')) return '🐶';
    return '🦦';
  }

  bool _prefsLoaded = false;
  bool lockEnabled = false;
  bool isUnlocked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final enabled =
          Storage.txBox.get('lockEnabled', defaultValue: false) as bool;

      if (enabled && mounted) {
        setState(() {
          lockEnabled = true;
          isUnlocked = false;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    final language =
        Storage.txBox.get('selectedLanguage', defaultValue: 'en') as String;
    final currency =
        Storage.txBox.get('selectedCurrency', defaultValue: 'USD') as String;
    final theme =
        Storage.txBox.get('selectedTheme', defaultValue: 'cream') as String;
    final budget =
        (Storage.txBox.get('monthlyBudget', defaultValue: 0.0) as num)
            .toDouble();

    var enabled = Storage.txBox.get('lockEnabled', defaultValue: false) as bool;
    final savedPasscode =
        Storage.txBox.get('lockPasscode', defaultValue: '') as String;

    if (enabled && savedPasscode.isEmpty) {
      enabled = false;
      await Storage.txBox.put('lockEnabled', false);
    }

    if (!mounted) return;

    setState(() {
      selectedLanguage = language;
      selectedCurrency = currency;
      lockEnabled = enabled;
      isUnlocked = !enabled;
      selectedTheme = theme;
      _monthlyBudget = budget;
      _prefsLoaded = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _processRecurring();
    });
  }

  Future<void> enablePasscodeLock() async {
    final passcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PasscodeSetupSheet(language: selectedLanguage),
    );

    if (passcode == null) return;

    await Storage.txBox.put('lockPasscode', passcode);
    await Storage.txBox.put('lockEnabled', true);

    if (!mounted) return;

    setState(() {
      lockEnabled = true;
      isUnlocked = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('passcode_enabled', selectedLanguage))),
    );
  }

  Future<void> changePasscodeLock() async {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PasscodeVerifySheet(language: selectedLanguage),
    );

    if (verified != true) return;

    final newPasscode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PasscodeSetupSheet(language: selectedLanguage),
    );

    if (newPasscode == null) return;

    await Storage.txBox.put('lockPasscode', newPasscode);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('passcode_changed', selectedLanguage))),
    );
  }

  Future<void> disablePasscodeLock() async {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PasscodeVerifySheet(language: selectedLanguage),
    );

    if (verified != true) return;

    await Storage.txBox.put('lockEnabled', false);
    await Storage.txBox.delete('lockPasscode');

    if (!mounted) return;

    setState(() {
      lockEnabled = false;
      isUnlocked = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('passcode_disabled', selectedLanguage))),
    );
  }

  void goPrevMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    });
  }

  void goNextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
    });
  }

  Future<void> openAddSheet() async {
    final saved = await showModalBottomSheet<TxItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntrySheet(language: selectedLanguage),
    );

    if (saved != null) {
      await context.read<TxRepo>().add(saved.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_savedEmoji ${t('saved', selectedLanguage)}')),
      );
    }
  }

  Future<void> openEditSheet(int index, TxItem item) async {
    final edited = await showModalBottomSheet<TxItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntrySheet(language: selectedLanguage, initialItem: item),
    );

    if (edited != null) {
      await context.read<TxRepo>().updateById(item.id, edited.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_savedEmoji ${t('saved', selectedLanguage)}')),
      );
    }
  }

  Future<void> confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('delete_all_title', selectedLanguage)),
        content: Text(t('delete_all_message', selectedLanguage)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t('delete', selectedLanguage)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t('cancel', selectedLanguage)),
              ),
            ],
          ),
        ],
      ),
    );

    if (ok == true) {
      await context.read<TxRepo>().clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('deleted', selectedLanguage))));
    }
  }

  Map<String, dynamic> _buildBackupPayload() {
    final repo = context.read<TxRepo>();

    return {
      'app': 'easy_financial_ledger',
      'formatVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        'items': repo.items
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        'settings': {
          'selectedLanguage': selectedLanguage,
          'selectedCurrency': selectedCurrency,
          'selectedTheme': selectedTheme,
        },
      },
    };
  }

  List<Map<String, dynamic>> _normalizeImportedItems(dynamic rawItems) {
    if (rawItems is! List) {
      throw const FormatException();
    }

    final normalizedItems = <Map<String, dynamic>>[];

    for (final item in rawItems) {
      if (item is! Map) {
        throw const FormatException();
      }

      final map = Map<String, dynamic>.from(item);

      if (!map.containsKey('isExpense') ||
          !map.containsKey('amount') ||
          !map.containsKey('category') ||
          !map.containsKey('note') ||
          !map.containsKey('date')) {
        throw const FormatException();
      }

      if (map['isExpense'] is! bool) {
        throw const FormatException();
      }

      if (map['amount'] is! num) {
        throw const FormatException();
      }

      final parsedDate = DateTime.tryParse(map['date'].toString());
      if (parsedDate == null) {
        throw const FormatException();
      }

      final amount = (map['amount'] as num).toDouble();
      final rawEntryCurrency = map['entryCurrency']?.toString() ?? '';
      final rawBaseCurrency = map['baseCurrency']?.toString() ?? '';
      final rawVersion = map['currencyMetaVersion'];

      final normalized = <String, dynamic>{
        'isExpense': map['isExpense'] as bool,
        'amount': amount,
        'category': map['category'].toString(),
        'note': map['note']?.toString() ?? '',
        'date': parsedDate.toIso8601String(),
        'entryCurrency': rawEntryCurrency.trim(),
        'baseAmount': map['baseAmount'] is num
            ? (map['baseAmount'] as num).toDouble()
            : amount,
        'baseCurrency': rawBaseCurrency.trim().isEmpty
            ? rawEntryCurrency.trim()
            : rawBaseCurrency.trim(),
        'exchangeRate': map['exchangeRate'] is num
            ? (map['exchangeRate'] as num).toDouble()
            : 1.0,
        'currencyMetaVersion': rawVersion is int
            ? rawVersion
            : (rawVersion is num
                  ? rawVersion.toInt()
                  : (rawEntryCurrency.trim().isEmpty ? 0 : 1)),
      };

      final rawId = map['id']?.toString();
      if (rawId != null && rawId.trim().isNotEmpty) {
        normalized['id'] = rawId;
      }

      normalizedItems.add(normalized);
    }

    return normalizedItems;
  }

  Map<String, dynamic> _parseImportPayload(dynamic decoded) {
    if (decoded is List) {
      return {'items': _normalizeImportedItems(decoded), 'settings': null};
    }

    if (decoded is! Map) {
      throw const FormatException();
    }

    final root = Map<String, dynamic>.from(decoded);

    dynamic rawItems;
    Map<String, dynamic>? rawSettings;

    if (root['data'] is Map) {
      final data = Map<String, dynamic>.from(root['data'] as Map);
      rawItems = data['items'];

      if (data['settings'] is Map) {
        rawSettings = Map<String, dynamic>.from(data['settings'] as Map);
      }
    } else {
      rawItems = root['items'];

      if (root['settings'] is Map) {
        rawSettings = Map<String, dynamic>.from(root['settings'] as Map);
      }
    }

    if (rawItems == null) {
      throw const FormatException();
    }

    return {
      'items': _normalizeImportedItems(rawItems),
      'settings': rawSettings,
    };
  }

  Future<void> _applyImportedSettings(Map<String, dynamic>? settings) async {
    if (settings == null) return;

    const supportedLanguages = {'en', 'ko', 'es', 'zh', 'ja'};
    const supportedCurrencies = {
      'USD', 'KRW', 'EUR', 'JPY', 'GBP',
      'CAD', 'AUD', 'CNY', 'HKD', 'SGD',
      'MXN', 'BRL', 'THB', 'VND',
    };
    const supportedThemes = {'cream', 'otter_light', 'otter_dark', 'dog', 'dog_dark', 'dog_system', 'minimal_black', 'cyber_ai'};

    String nextLanguage = selectedLanguage;
    String nextCurrency = selectedCurrency;
    String nextTheme = selectedTheme;

    final importedLanguage = settings['selectedLanguage']?.toString();
    final importedCurrency = settings['selectedCurrency']?.toString();
    final importedTheme = settings['selectedTheme']?.toString();

    if (importedLanguage != null &&
        supportedLanguages.contains(importedLanguage)) {
      nextLanguage = importedLanguage;
      await Storage.txBox.put('selectedLanguage', importedLanguage);
    }

    if (importedCurrency != null &&
        supportedCurrencies.contains(importedCurrency)) {
      nextCurrency = importedCurrency;
      await Storage.txBox.put('selectedCurrency', importedCurrency);
    }

    if (importedTheme != null && supportedThemes.contains(importedTheme)) {
      nextTheme = importedTheme;
      await Storage.txBox.put('selectedTheme', importedTheme);
    }

    if (!mounted) return;

    setState(() {
      selectedLanguage = nextLanguage;
      selectedCurrency = nextCurrency;
      selectedTheme = nextTheme;
    });
  }

  Future<void> _processRecurring() async {
    final items = RecurringItem.loadAll();
    final now = DateTime.now();
    int generated = 0;

    for (final item in items) {
      if (!item.isActive) continue;

      String currentKey;
      bool shouldGenerate;

      if (item.frequency == 'monthly') {
        currentKey = RecurringItem.monthlyKey(now);
        shouldGenerate =
            item.lastGeneratedKey != currentKey && now.day >= item.dayOfMonth;
      } else {
        currentKey = RecurringItem.weeklyKey(now);
        shouldGenerate =
            item.lastGeneratedKey != currentKey && now.weekday >= item.dayOfWeek;
      }

      if (shouldGenerate) {
        final txDate = item.frequency == 'monthly'
            ? DateTime(now.year, now.month, item.dayOfMonth)
            : now;
        if (!mounted) return;
        await context.read<TxRepo>().add(item.toTxMap(txDate));
        await RecurringItem.updateById(
          item.id,
          item.copyWith(lastGeneratedKey: currentKey),
        );
        generated++;
      }
    }

    if (generated > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 $generated ${t('recurring_generated', selectedLanguage)}'),
        ),
      );
    }
  }

  Future<void> openRecurringScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecurringScreen(
          language: selectedLanguage,
          currency: selectedCurrency,
        ),
      ),
    );
  }

  Future<void> openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
  }

  Future<void> openCategoriesScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CategoriesScreen(
          language: selectedLanguage,
          isPremium: ctx.read<PurchaseService>().isPremium,
        ),
      ),
    );
  }

  Future<void> showExportPreview() async {
    final backupPayload = _buildBackupPayload();
    final prettyJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(backupPayload);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('export_preview', selectedLanguage),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: SelectableText(
                    prettyJson,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: prettyJson));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t('copied_to_clipboard', selectedLanguage),
                        ),
                      ),
                    );
                  },
                  child: Text(t('copy_json', selectedLanguage)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('close', selectedLanguage)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showImportSheet() async {
    final rootContext = context;
    final controller = TextEditingController();
    String? errorText;

    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('import_data', selectedLanguage),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: t('import_hint', selectedLanguage),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        final decoded = jsonDecode(controller.text.trim());
                        final parsedPayload = _parseImportPayload(decoded);

                        final parsedItems = List<Map<String, dynamic>>.from(
                          parsedPayload['items'] as List,
                        );

                        final importedSettings =
                            parsedPayload['settings'] as Map<String, dynamic>?;

                        final ok = await showDialog<bool>(
                          context: rootContext,
                          builder: (context) => AlertDialog(
                            title: Text(
                              t('import_confirm_title', selectedLanguage),
                            ),
                            content: Text(
                              t('import_confirm_message', selectedLanguage),
                            ),
                            actionsPadding: const EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              20,
                            ),
                            actions: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        t('import_data', selectedLanguage),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(t('cancel', selectedLanguage)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );

                        if (ok != true) return;

                        await rootContext.read<TxRepo>().replaceAll(
                          parsedItems,
                        );
                        await _applyImportedSettings(importedSettings);

                        if (!mounted) return;

                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content: Text(t('imported', selectedLanguage)),
                          ),
                        );
                      } catch (_) {
                        setModalState(() {
                          errorText = t(
                            'invalid_import_json',
                            selectedLanguage,
                          );
                        });
                      }
                    },
                    child: Text(t('import_data', selectedLanguage)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(modalContext),
                    child: Text(t('close', selectedLanguage)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openPrivacyPolicyPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivacyPolicyPage(language: selectedLanguage),
      ),
    );
  }

  Future<void> openEditSheetFromHome(TxItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TxDetailSheet(
        item: item,
        language: selectedLanguage,
        currency: selectedCurrency,
        onEdit: () async {
          await openEditSheet(-1, item);
        },
      ),
    );
  }

  Future<void> updateBudget(double value) async {
    await Storage.txBox.put('monthlyBudget', value);
    if (!mounted) return;
    setState(() => _monthlyBudget = value);
  }

  Future<void> deleteRecentItemFromHome(TxItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('delete_entry_title', selectedLanguage)),
        content: Text(t('delete_entry_message', selectedLanguage)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t('delete', selectedLanguage)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t('cancel', selectedLanguage)),
              ),
            ],
          ),
        ],
      ),
    );

    if (ok == true) {
      await context.read<TxRepo>().removeById(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('deleted', selectedLanguage))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (lockEnabled && !isUnlocked) {
      return PasscodeLockScreen(
        language: selectedLanguage,
        onUnlocked: () {
          setState(() {
            isUnlocked = true;
          });
        },
      );
    }

    final repo = context.watch<TxRepo>();
    final tx = repo.items.map((e) => TxItem.fromMap(e)).toList();

    final now = selectedMonth;

    final monthIncome = tx
        .where(
          (x) =>
              !x.isExpense &&
              x.date.year == now.year &&
              x.date.month == now.month,
        )
        .fold(0.0, (sum, x) => sum + x.amount);

    final monthExpense = tx
        .where(
          (x) =>
              x.isExpense &&
              x.date.year == now.year &&
              x.date.month == now.month,
        )
        .fold(0.0, (sum, x) => sum + x.amount);

    final monthItems = tx.where((x) {
      return x.date.year == now.year && x.date.month == now.month;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    final recentPreviewItems = monthItems.take(3).toList();

    final monthCurrencies = collectItemCurrencies(
      monthItems,
      fallbackCurrency: selectedCurrency,
    );

    final monthCurrencySummaries = buildCurrencySummaries(
      monthItems,
      fallbackCurrency: selectedCurrency,
    );

    final cumulativeBalance = calculateCumulativeBalance(tx, selectedMonth);

    // 저번 달 경계 계산 (1월이면 전년 12월로 정확히 넘어감)
    final prevYear = selectedMonth.month == 1 ? selectedMonth.year - 1 : selectedMonth.year;
    final prevMonth = selectedMonth.month == 1 ? 12 : selectedMonth.month - 1;
    final prevMonthIncome = tx
        .where((x) => !x.isExpense && x.date.year == prevYear && x.date.month == prevMonth)
        .fold(0.0, (sum, x) => sum + x.amount);
    final prevMonthExpense = tx
        .where((x) => x.isExpense && x.date.year == prevYear && x.date.month == prevMonth)
        .fold(0.0, (sum, x) => sum + x.amount);
    final carryoverEnabled = Storage.txBox.get('balance_carryover_enabled', defaultValue: true) as bool;
    final carryover = carryoverEnabled ? (prevMonthIncome - prevMonthExpense) : 0.0;

    final pages = [
      HomePage(
        income: monthIncome,
        expense: monthExpense,
        onAdd: openAddSheet,
        selectedMonth: selectedMonth,
        onPrevMonth: goPrevMonth,
        onNextMonth: goNextMonth,
        language: selectedLanguage,
        currency: selectedCurrency,
        monthCurrencies: monthCurrencies,
        currencySummaries: monthCurrencySummaries,
        recentItems: recentPreviewItems,
        onTapRecentItem: (item) async {
          await openEditSheetFromHome(item);
        },
        onLongPressRecentItem: (item) async {
          await deleteRecentItemFromHome(item);
        },
        onOpenList: () {
          setState(() => index = 1);
        },
        monthlyBudget: _monthlyBudget,
        selectedTheme: selectedTheme,
        cumulativeBalance: cumulativeBalance,
        carryover: carryover,
      ),
      TransactionsPage(
        items: tx,
        selectedMonth: selectedMonth,
        onPrevMonth: goPrevMonth,
        onNextMonth: goNextMonth,
        language: selectedLanguage,
        currency: selectedCurrency,
        listFilter: selectedListFilter,
        onListFilterChanged: (value) {
          setState(() => selectedListFilter = value);
        },
        listQuery: selectedListQuery,
        onListQueryChanged: (value) {
          setState(() => selectedListQuery = value);
        },
        onDelete: (i) async {
          await context.read<TxRepo>().removeById(tx[i].id);
        },
        onEdit: (i, item) async {
          await openEditSheet(i, item);
        },
        selectedTheme: selectedTheme,
      ),
      CalendarPage(
        items: tx,
        selectedMonth: selectedMonth,
        onPrevMonth: goPrevMonth,
        onNextMonth: goNextMonth,
        language: selectedLanguage,
        currency: selectedCurrency,
        selectedTheme: selectedTheme,
        onEditItem: (item) async { await openEditSheet(-1, item); },
        onDeleteItem: (item) async { await deleteRecentItemFromHome(item); },
      ),
      StatsPage(
        items: tx,
        selectedMonth: selectedMonth,
        onPrevMonth: goPrevMonth,
        onNextMonth: goNextMonth,
        language: selectedLanguage,
        currency: selectedCurrency,
        selectedTheme: selectedTheme,
        cumulativeBalance: cumulativeBalance,
      ),
      SettingsPage(
        language: selectedLanguage,
        currency: selectedCurrency,
        selectedTheme: selectedTheme,
        lockEnabled: lockEnabled,
        onLanguageChanged: (value) {
          setState(() => selectedLanguage = value);
          Storage.txBox.put('selectedLanguage', value);
        },
        onCurrencyChanged: (value) {
          setState(() => selectedCurrency = value);
          Storage.txBox.put('selectedCurrency', value);
        },
        onThemeChanged: (value) {
          setState(() => selectedTheme = value);
          Storage.txBox.put('selectedTheme', value);
          IconService.setIcon(IconService.iconNameForTheme(value)).catchError((_) {});
        },
        onEnablePasscodeLock: enablePasscodeLock,
        onDisablePasscodeLock: disablePasscodeLock,
        onChangePasscodeLock: changePasscodeLock,
        onOpenPrivacyPolicy: openPrivacyPolicyPage,
        onImport: showImportSheet,
        onExport: showExportPreview,
        onClear: confirmClearAll,
        monthlyBudget: _monthlyBudget,
        onBudgetChanged: updateBudget,
        onGetBackupPayload: () async => _buildBackupPayload(),
        onApplyImport: (items, settings) async {
          await context.read<TxRepo>().replaceAll(items);
          await _applyImportedSettings(settings);
        },
        onGetAllItems: () => context.read<TxRepo>().items,
        onGetSelectedCurrency: () => selectedCurrency,
        onOpenRecurring: openRecurringScreen,
        onOpenCategories: openCategoriesScreen,
        isPremium: context.watch<PurchaseService>().isPremium,
        onOpenPaywall: openPaywall,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t('app_title', selectedLanguage))),
      body: pages[index],
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: index == 4
          ? null
          : FloatingActionButton(
              onPressed: openAddSheet,
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
            border: Border.all(
              color:
                  Theme.of(context).dividerTheme.color ??
                  const Color(0xFFD9E4EE),
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BottomNavigationBar(
              currentIndex: index,
              onTap: (v) => setState(() => index = v),
              selectedFontSize: 13,
              unselectedFontSize: 13,
              iconSize: 32,
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      themeImage(selectedTheme, 'nav_home'),
                      height: 44,
                    ),
                  ),
                  label: t('home', selectedLanguage),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      themeImage(selectedTheme, 'nav_list'),
                      height: 44,
                    ),
                  ),
                  label: t('list', selectedLanguage),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      themeImage(selectedTheme, 'nav_calendar'),
                      height: 44,
                    ),
                  ),
                  label: t('calendar', selectedLanguage),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      themeImage(selectedTheme, 'nav_stats'),
                      height: 44,
                    ),
                  ),
                  label: t('stats', selectedLanguage),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      themeImage(selectedTheme, 'nav_settings'),
                      height: 44,
                    ),
                  ),
                  label: t('settings', selectedLanguage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
