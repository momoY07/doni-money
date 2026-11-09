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
import 'package:package_info_plus/package_info_plus.dart';
import '../services/backup_service.dart';
import '../services/backup_file_transfer.dart';
import '../services/icloud_backup_service.dart';
import '../services/icloud_backup_storage.dart';
import '../utils/icloud_backup_text.dart';
import '../companion/companion_card.dart';
import '../companion/companion_character.dart';
import '../companion/companion_data.dart';
import '../companion/money_insight_engine.dart';

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

  /// Companion picked by the user; null = follow the theme's mascot.
  CompanionCharacter? _companionChoice;
  static const _companionLastInsightKey = 'companionLastInsight';

  /// "Saved" snackbar with the app's otter graphic (same in every theme).
  SnackBar _savedSnackBar() {
    final text = t('saved', selectedLanguage);
    return SnackBar(
      content: Row(
        children: [
          Image.asset(
            'assets/images/snackbar_otter.png',
            width: 22,
            height: 22,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(text)),
        ],
      ),
    );
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
    final companion =
        CompanionCharacter.fromId(Storage.txBox.get(CompanionCharacter.storageKey));

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
      _companionChoice = companion;
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
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) => EntrySheet(language: selectedLanguage),
    );

    if (saved != null) {
      await context.read<TxRepo>().add(saved.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _savedSnackBar(),
      );
    }
  }

  Future<void> openAddSheetWithType(bool isExpense) async {
    final saved = await showModalBottomSheet<TxItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) => EntrySheet(
        language: selectedLanguage,
        initialIsExpense: isExpense,
      ),
    );

    if (saved != null) {
      await context.read<TxRepo>().add(saved.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _savedSnackBar(),
      );
    }
  }

  Future<void> openEditSheet(int index, TxItem item) async {
    final edited = await showModalBottomSheet<TxItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (_) => EntrySheet(language: selectedLanguage, initialItem: item),
    );

    if (edited != null) {
      await context.read<TxRepo>().updateById(item.id, edited.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _savedSnackBar(),
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

  // ───────────────────────── Companion (Premium) ─────────────────────────

  Widget _buildCompanion(List<TxItem> tx) {
    final isPremium = context.watch<PurchaseService>().isPremium;
    // Insights are only computed for Premium users; all data stays local.
    final insights = isPremium
        ? const MoneyInsightEngine().generate(buildInsightInput(
            transactions: tx,
            recurring: RecurringItem.loadAll(),
            monthlyBudget: _monthlyBudget,
            selectedCurrency: selectedCurrency,
            now: DateTime.now(),
          ))
        : const <Never>[];
    return CompanionCard(
      language: selectedLanguage,
      selectedTheme: selectedTheme,
      isPremium: isPremium,
      character: _companionChoice ?? CompanionCharacter.defaultForTheme(selectedTheme),
      insights: insights,
      lastShownId: Storage.txBox.get(_companionLastInsightKey) as String?,
      onShown: (id) => Storage.txBox.put(_companionLastInsightKey, id),
      onOpenPaywall: openPaywall,
      onChangeCharacter: (c) {
        setState(() => _companionChoice = c);
        Storage.txBox.put(CompanionCharacter.storageKey, c.id);
      },
    );
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

  // ── Versioned backup (BackupService) ─────────────────────────

  String _backupErrorText(BackupException e) {
    switch (e.code) {
      case BackupErrorCode.wrongFormat:
        return t('backup_err_format', selectedLanguage);
      case BackupErrorCode.unsupportedSchemaVersion:
        return t('backup_err_version', selectedLanguage);
      case BackupErrorCode.storageFailure:
        return t('backup_err_storage', selectedLanguage);
      case BackupErrorCode.malformedJson:
      case BackupErrorCode.missingField:
      case BackupErrorCode.invalidType:
      case BackupErrorCode.invalidValue:
        return t('backup_err_invalid', selectedLanguage);
    }
  }

  Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }

  /// Confirmation text shared by file restore and JSON paste import.
  String _restoreConfirmText(ValidatedBackup b) {
    final buf = StringBuffer(t('backup_restore_confirm_message', selectedLanguage))
      ..write('\n\n')
      ..write(backupSummaryText(b, selectedLanguage));
    if (b.isLegacy) {
      buf
        ..write('\n\n')
        ..write(t('backup_legacy_note', selectedLanguage));
    }
    return buf.toString();
  }

  /// Destructive-restore confirmation shared by file and iCloud restore.
  Future<bool> _confirmRestore(ValidatedBackup b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('backup_restore_confirm_title', selectedLanguage)),
        content: Text(_restoreConfirmText(b)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel', selectedLanguage)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('backup_restore_action', selectedLanguage)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> exportBackupFile() async {
    try {
      final service = BackupService();
      final json = service.createBackupJson(appVersion: await _appVersion());
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await const BackupFileTransfer().share(
        json,
        service.suggestedFileName(),
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> restoreBackupFile() async {
    final String? raw;
    try {
      raw = await const BackupFileTransfer().pick();
    } catch (e) {
      _showSnack(e.toString());
      return;
    }
    if (raw == null || !mounted) return;

    final service = BackupService();
    final ValidatedBackup preview;
    try {
      preview = service.validateBackup(raw);
    } on BackupException catch (e) {
      _showSnack(_backupErrorText(e));
      return;
    }
    if (!mounted) return;
    if (!await _confirmRestore(preview) || !mounted) return;

    try {
      // Validates again internally; nothing is written unless it passes.
      await service.restoreBackup(raw);
    } on BackupException catch (e) {
      _showSnack(_backupErrorText(e));
      return;
    }
    if (!mounted) return;
    _reloadAfterRestore();
    _showSnack(t('backup_restored', selectedLanguage));
  }

  // ── Premium iCloud backup (manual, Phase 1) ──────────────────

  ICloudBackupService get _icloud => ICloudBackupService(
        storage: const MethodChannelICloudBackupStorage(),
        backupService: BackupService(),
        isPremium: () => context.read<PurchaseService>().isPremium,
      );

  Future<ICloudBackupStatus> loadICloudStatus() => _icloud.loadStatus();

  /// Returns true when the Settings status should be reloaded.
  Future<bool> icloudBackupNow() async {
    if (!context.read<PurchaseService>().isPremium) {
      await openPaywall();
      return false;
    }
    try {
      final r = await _icloud.backUpNow(appVersion: await _appVersion());
      _showSnack(t(r.isUploaded ? 'icloud_backup_done' : 'icloud_backup_saved_pending', selectedLanguage));
    } on ICloudBackupException catch (e) {
      _showSnack(icloudIssueText(e.issue, selectedLanguage));
    }
    return true;
  }

  Future<bool> icloudRestore() async {
    if (!context.read<PurchaseService>().isPremium) {
      await openPaywall();
      return false;
    }
    final service = _icloud;
    final PreparedCloudRestore prepared;
    try {
      // Find → download → validate. Nothing is written here.
      prepared = await service.prepareRestore();
    } on ICloudBackupException catch (e) {
      _showSnack(icloudIssueText(e.issue, selectedLanguage));
      return true;
    }
    if (!mounted || !await _confirmRestore(prepared.backup) || !mounted) return false;
    try {
      await service.restore(prepared);
    } on ICloudBackupException catch (e) {
      _showSnack(icloudIssueText(e.issue, selectedLanguage));
      return false;
    }
    if (!mounted) return false;
    _reloadAfterRestore();
    _showSnack(t('backup_restored', selectedLanguage));
    return false;
  }

  /// Re-reads restored values so every tab shows them without a restart.
  void _reloadAfterRestore() {
    context.read<TxRepo>().reloadFromStorage();
    setState(() {
      selectedLanguage =
          Storage.txBox.get('selectedLanguage', defaultValue: 'en') as String;
      selectedCurrency =
          Storage.txBox.get('selectedCurrency', defaultValue: 'USD') as String;
      selectedTheme =
          Storage.txBox.get('selectedTheme', defaultValue: 'cream') as String;
      _monthlyBudget =
          (Storage.txBox.get('monthlyBudget', defaultValue: 0.0) as num)
              .toDouble();
    });
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
    final String prettyJson;
    try {
      prettyJson = BackupService().createBackupJson(
        appVersion: await _appVersion(),
      );
    } catch (e) {
      _showSnack(e.toString());
      return;
    }
    if (!mounted) return;

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
                        final raw = controller.text.trim();
                        final service = BackupService();
                        // Validates (and migrates legacy) without writing.
                        final preview = service.validateBackup(raw);

                        final ok = await showDialog<bool>(
                          context: rootContext,
                          builder: (context) => AlertDialog(
                            title: Text(
                              t('import_confirm_title', selectedLanguage),
                            ),
                            content: Text(_restoreConfirmText(preview)),
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

                        await service.restoreBackup(raw);

                        if (!mounted) return;
                        _reloadAfterRestore();

                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content: Text(t('imported', selectedLanguage)),
                          ),
                        );
                      } on BackupException catch (e) {
                        setModalState(() => errorText = _backupErrorText(e));
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

    final cumulativeBalanceByCurrency = calculateCumulativeBalanceByCurrency(
      tx, selectedMonth, fallbackCurrency: selectedCurrency);
    final hasHistoryMixedCurrencies = cumulativeBalanceByCurrency.length > 1;
    final carryoverByCurrency = carryoverEnabled
        ? calculatePrevMonthBalanceByCurrency(tx, selectedMonth, fallbackCurrency: selectedCurrency)
        : <String, double>{};

    final pages = [
      HomePage(
        income: monthIncome,
        expense: monthExpense,
        onAdd: openAddSheet,
        onAddIncome: () => openAddSheetWithType(false),
        onAddExpense: () => openAddSheetWithType(true),
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
        hasHistoryMixedCurrencies: hasHistoryMixedCurrencies,
        cumulativeBalanceByCurrency: cumulativeBalanceByCurrency,
        carryoverByCurrency: carryoverByCurrency,
        companion: _buildCompanion(tx),
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
        hasHistoryMixedCurrencies: hasHistoryMixedCurrencies,
        cumulativeBalanceByCurrency: cumulativeBalanceByCurrency,
        carryoverByCurrency: carryoverByCurrency,
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
        onGetAllItems: () => context.read<TxRepo>().items,
        onGetSelectedCurrency: () => selectedCurrency,
        onOpenRecurring: openRecurringScreen,
        onOpenCategories: openCategoriesScreen,
        onExportBackup: exportBackupFile,
        onRestoreBackup: restoreBackupFile,
        onLoadICloudStatus: loadICloudStatus,
        onICloudBackupNow: icloudBackupNow,
        onICloudRestore: icloudRestore,
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
