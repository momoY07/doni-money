import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/i18n.dart';
import '../theme/app_theme.dart';
import '../services/purchase_service.dart';
import '../services/icon_service.dart';
import 'theme_select_screen.dart';
import 'icon_select_screen.dart';

class SettingsPage extends StatefulWidget {
  final String language;
  final String currency;
  final String selectedTheme;
  final bool lockEnabled;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onThemeChanged;
  final Future<void> Function() onEnablePasscodeLock;
  final Future<void> Function() onDisablePasscodeLock;
  final Future<void> Function() onChangePasscodeLock;
  final Future<void> Function() onOpenPrivacyPolicy;
  final Future<void> Function() onImport;
  final Future<void> Function() onExport;
  final Future<void> Function() onClear;
  final double monthlyBudget;
  final ValueChanged<double> onBudgetChanged;
  final Future<Map<String, dynamic>> Function() onGetBackupPayload;
  final Future<void> Function(List<Map<String, dynamic>> items, Map<String, dynamic>? settings) onApplyImport;
  final List<Map<String, dynamic>> Function() onGetAllItems;
  final String Function() onGetSelectedCurrency;
  final Future<void> Function() onOpenRecurring;
  final Future<void> Function() onOpenCategories;
  final bool isPremium;
  final VoidCallback onOpenPaywall;

  const SettingsPage({
    super.key,
    required this.language,
    required this.currency,
    required this.selectedTheme,
    required this.lockEnabled,
    required this.onLanguageChanged,
    required this.onCurrencyChanged,
    required this.onThemeChanged,
    required this.onEnablePasscodeLock,
    required this.onDisablePasscodeLock,
    required this.onChangePasscodeLock,
    required this.onOpenPrivacyPolicy,
    required this.onImport,
    required this.onExport,
    required this.onClear,
    this.monthlyBudget = 0,
    required this.onBudgetChanged,
    required this.onGetBackupPayload,
    required this.onApplyImport,
    required this.onGetAllItems,
    required this.onGetSelectedCurrency,
    required this.onOpenRecurring,
    required this.onOpenCategories,
    required this.isPremium,
    required this.onOpenPaywall,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _versionTapCount = 0;
  String? _currentIcon;

  @override
  void initState() {
    super.initState();
    IconService.getCurrentIcon().then((v) {
      if (mounted) setState(() => _currentIcon = v);
    });
  }

  String get language => widget.language;
  String get currency => widget.currency;
  String get selectedTheme => widget.selectedTheme;
  bool get _isMB => selectedTheme == 'minimal_black';
  bool get _isCA => selectedTheme == 'cyber_ai';
  bool get _isDog => selectedTheme.contains('dog');

  String get _settingsSubtitle {
    if (_isCA) return t('settings_sub_ca', language);
    if (_isMB) return t('settings_sub_mb', language);
    if (_isDog) return t('settings_sub_dog', language);
    return t('cute_otter_later', language);
  }
  bool get lockEnabled => widget.lockEnabled;
  bool get isPremium => widget.isPremium;
  double get monthlyBudget => widget.monthlyBudget;
  ValueChanged<String> get onLanguageChanged => widget.onLanguageChanged;
  ValueChanged<String> get onCurrencyChanged => widget.onCurrencyChanged;
  ValueChanged<String> get onThemeChanged => widget.onThemeChanged;
  Future<void> Function() get onEnablePasscodeLock => widget.onEnablePasscodeLock;
  Future<void> Function() get onDisablePasscodeLock => widget.onDisablePasscodeLock;
  Future<void> Function() get onChangePasscodeLock => widget.onChangePasscodeLock;
  Future<void> Function() get onOpenPrivacyPolicy => widget.onOpenPrivacyPolicy;
  Future<void> Function() get onImport => widget.onImport;
  Future<void> Function() get onExport => widget.onExport;
  Future<void> Function() get onClear => widget.onClear;
  ValueChanged<double> get onBudgetChanged => widget.onBudgetChanged;
  Future<Map<String, dynamic>> Function() get onGetBackupPayload => widget.onGetBackupPayload;
  Future<void> Function(List<Map<String, dynamic>>, Map<String, dynamic>?) get onApplyImport => widget.onApplyImport;
  List<Map<String, dynamic>> Function() get onGetAllItems => widget.onGetAllItems;
  String Function() get onGetSelectedCurrency => widget.onGetSelectedCurrency;
  Future<void> Function() get onOpenRecurring => widget.onOpenRecurring;
  Future<void> Function() get onOpenCategories => widget.onOpenCategories;
  VoidCallback get onOpenPaywall => widget.onOpenPaywall;

  Future<void> _handleVersionTap() async {
    _versionTapCount++;
    if (_versionTapCount < 7) return;
    _versionTapCount = 0;

    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (controller.text.trim() != '910727') return;

    final purchaseService = context.read<PurchaseService>();
    final isCurrentlyEnabled = purchaseService.isDevMode;
    if (isCurrentlyEnabled) {
      await purchaseService.disableDevMode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('개발자 모드 비활성화')),
      );
    } else {
      await purchaseService.forceDevMode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔧 개발자 모드 활성화')),
      );
    }
  }

  Future<void> confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('delete_all_title', language)),
        content: Text(t('delete_all_message', language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel', language)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('delete', language)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await onClear();
    }
  }

  Future<void> _exportFile(BuildContext context) async {
    try {
      final payload = await onGetBackupPayload();
      final json = const JsonEncoder.withIndent('  ').convert(payload);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/easy_ledger_backup.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Doni Money Backup',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _importFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      final content = await File(path).readAsString();
      final decoded = jsonDecode(content);

      List<Map<String, dynamic>> parsedItems;
      Map<String, dynamic>? parsedSettings;

      if (decoded is List) {
        parsedItems = List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } else if (decoded is Map) {
        final root = Map<String, dynamic>.from(decoded);
        dynamic rawItems;
        if (root['data'] is Map) {
          final data = Map<String, dynamic>.from(root['data'] as Map);
          rawItems = data['items'];
          if (data['settings'] is Map) {
            parsedSettings = Map<String, dynamic>.from(data['settings'] as Map);
          }
        } else {
          rawItems = root['items'];
          if (root['settings'] is Map) {
            parsedSettings = Map<String, dynamic>.from(root['settings'] as Map);
          }
        }
        if (rawItems == null) throw const FormatException();
        parsedItems = List<Map<String, dynamic>>.from(
          (rawItems as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } else {
        throw const FormatException();
      }

      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('import_confirm_title', language)),
          content: Text(t('import_confirm_message', language)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel', language)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('import_data', language)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await onApplyImport(parsedItems, parsedSettings);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('imported', language))),
      );
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('invalid_import_json', language))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final allItems = onGetAllItems();
      final currency = onGetSelectedCurrency();
      final rows = <String>[
        'Date,Amount,Currency,Type,Category,PaymentMethod,Memo',
      ];
      for (final m in allItems) {
        final date = (m['date'] as String).substring(0, 10);
        final amount = m['amount'].toString();
        final cur = (m['entryCurrency'] as String?)?.trim().isEmpty ?? true
            ? currency
            : m['entryCurrency'];
        final type = (m['isExpense'] as bool) ? 'Expense' : 'Income';
        final cat = (m['category'] as String).replaceAll(',', ';');
        final pm = (m['paymentMethod'] as String?)?.toString() ?? '';
        final note = (m['note'] as String?)
                ?.replaceAll(',', ';')
                .replaceAll('"', "'") ??
            '';
        rows.add('"$date",$amount,$cur,$type,"$cat",$pm,"$note"');
      }
      final csv = rows.join('\n');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/easy_ledger_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Doni Money Export',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  static const Color _line = Color(0xFFD9E4EE);
  static const Color _softBg = Color(0xFFEAF1F8);
  static const Color _primaryDark = Color(0xFF5F7FA3);
  static const Color _textMain = Color(0xFF24364A);
  static const Color _textSub = Color(0xFF75879A);

  String get languageLabel {
    switch (language) {
      case 'ko': return t('korean', language);
      case 'es': return t('spanish', language);
      case 'zh': return t('chinese', language);
      case 'ja': return t('japanese', language);
      default:   return t('english', language);
    }
  }

  String get themeLabel => t(themeLabelKey(selectedTheme), language);

  static const _otterImgs = <String, String>{
    'language':       'assets/images/language.jpeg',
    'currency':       'assets/images/currency.jpeg',
    'monthly_budget': 'assets/images/monthly_budget.jpeg',
    'theme':          'assets/images/theme.jpeg',
    'set_passcode':   'assets/images/set_passcode.jpeg',
    'disable_passcode':'assets/images/disable_passcode.jpeg',
    'copy_json':      'assets/images/copy_json.png',
    'paste_json':     'assets/images/paste_json.png',
    'backup':         'assets/images/backuptofile.jpeg',
    'export_csv':     'assets/images/export_csv.jpeg',
    'recurring':      'assets/images/recurring_transactions.jpeg',
    'categories':     'assets/images/manage_categories.jpeg',
    'app_icon':       'assets/images/SD_app_icon.png',
    'privacy':        'assets/images/privacy_policy.jpeg',
    'clear':          'assets/images/clear_all_entries.jpeg',
  };

  static const _dogImgs = <String, String>{
    'language':       'assets/images/dog_theme/dog_language.jpeg',
    'currency':       'assets/images/dog_theme/dog_currency.jpeg',
    'monthly_budget': 'assets/images/dog_theme/dog_monthly_budget.jpeg',
    'theme':          'assets/images/dog_theme/dog_theme.jpeg',
    'set_passcode':   'assets/images/dog_theme/dog_set_passcode.jpeg',
    'disable_passcode':'assets/images/dog_theme/dog_disable_passcode.jpeg',
    'copy_json':      'assets/images/dog_theme/dog_copy_json.png',
    'paste_json':     'assets/images/dog_theme/dog_paste_json.png',
    'backup':         'assets/images/dog_theme/dog_backuptofile.jpeg',
    'export_csv':     'assets/images/dog_theme/dog_export_csv.jpeg',
    'recurring':      'assets/images/dog_theme/dog_recurring transactions.jpeg',
    'categories':     'assets/images/dog_theme/dog_manage_categories.jpeg',
    'app_icon':       'assets/images/dog_theme/dog_app_icon.png',
    'privacy':        'assets/images/dog_theme/dog_privacy_policy.jpeg',
    'clear':          'assets/images/dog_theme/dog_clear_all_entries.jpeg',
  };

  static const _cyImgs = <String, String>{
    'language':        'assets/images/cyber_ai/cy_language.png',
    'currency':        'assets/images/cyber_ai/cy_currency.png',
    'monthly_budget':  'assets/images/cyber_ai/cy_monthly_budget.png',
    'theme':           'assets/images/cyber_ai/cy_theme.png',
    'set_passcode':    'assets/images/cyber_ai/cy_set_passcode.png',
    'disable_passcode':'assets/images/cyber_ai/cy_disable_passcode.png',
    'copy_json':       'assets/images/cyber_ai/cy_copy_json.png',
    'paste_json':      'assets/images/cyber_ai/cy_paste_json.png',
    'backup':          'assets/images/cyber_ai/cy_backup.png',
    'export_csv':      'assets/images/cyber_ai/cy_export_csv.png',
    'recurring':       'assets/images/cyber_ai/cy_recurring.png',
    'categories':      'assets/images/cyber_ai/cy_categories.png',
    'app_icon':        'assets/images/cyber_ai/cy_app_icon.png',
    'privacy':         'assets/images/cyber_ai/cy_privacy.png',
    'clear':           'assets/images/cyber_ai/cy_clear_all.png',
  };

  static const _mbImgs = <String, String>{
    'language':        'assets/images/minimal_black/mb_language.png',
    'currency':        'assets/images/minimal_black/mb_currency.png',
    'monthly_budget':  'assets/images/minimal_black/mb_monthly_budget.png',
    'theme':           'assets/images/minimal_black/mb_theme.png',
    'set_passcode':    'assets/images/minimal_black/mb_set_passcode.png',
    'disable_passcode':'assets/images/minimal_black/mb_disable_passcode.png',
    'copy_json':       'assets/images/minimal_black/mb_copy_json.png',
    'paste_json':      'assets/images/minimal_black/mb_paste_json.png',
    'backup':          'assets/images/minimal_black/mb_backup.png',
    'export_csv':      'assets/images/minimal_black/mb_export_csv.png',
    'recurring':       'assets/images/minimal_black/mb_recurring.png',
    'categories':      'assets/images/minimal_black/mb_categories.png',
    'app_icon':        'assets/images/minimal_black/mb_app_icon.png',
    'privacy':         'assets/images/minimal_black/mb_privacy.png',
    'clear':           'assets/images/minimal_black/mb_clear_all.png',
  };

  Widget _img(String key) {
    final isMB = selectedTheme == 'minimal_black';
    final isCA = selectedTheme == 'cyber_ai';
    final isDog = selectedTheme == 'dog' ||
        selectedTheme == 'dog_dark' ||
        selectedTheme == 'dog_system';
    if (isCA) {
      final path = _cyImgs[key] ?? _otterImgs[key]!;
      return Image.asset(path, width: 30, height: 30, fit: BoxFit.contain);
    }
    if (isMB) {
      final path = _mbImgs[key] ?? _otterImgs[key]!;
      return Image.asset(path, width: 30, height: 30, fit: BoxFit.contain);
    }
    final path = (isDog ? _dogImgs[key] : _otterImgs[key]) ?? _otterImgs[key]!;
    return Image.asset(path, width: 30, height: 30, fit: BoxFit.contain);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF666666) : _textSub),
        ),
      ),
    );
  }

  Widget _settingTile({
    required Widget leading,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : _line)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : _softBg),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: leading),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isLocked
                          ? ((_isCA || _isMB) ? Colors.white.withAlpha(80) : _textMain.withAlpha(140))
                          : ((_isCA || _isMB) ? Colors.white : _textMain),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : _textSub),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isLocked)
              Icon(Icons.lock_rounded, size: 18, color: (_isCA || _isMB) ? const Color(0xFF555555) : const Color(0xFFB0C4CC))
            else
              Icon(Icons.chevron_right_rounded, color: (_isCA || _isMB) ? const Color(0xFF555555) : _textSub),
          ],
        ),
      ),
    );
  }

  Widget _premiumBanner(BuildContext context) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4E8F7D), Color(0xFF2E6B5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('settings_premium_active', language),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('settings_premium_active_subtitle', language),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onOpenPaywall,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B6FCE), Color(0xFF5A4AB0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x308B6FCE),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('settings_upgrade', language),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('settings_upgrade_subtitle', language),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? bgColor,
    Color? borderColor,
    Color? titleColor,
    Color? subtitleColor,
  }) {
    final defaultBg = _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white);
    final defaultBorder = _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : _line);
    final defaultTitle = (_isCA || _isMB) ? Colors.white : _textMain;
    final defaultSub = _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : _textSub);
    final iconBg = _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : Colors.white.withValues(alpha: 0.7));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor ?? defaultBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor ?? defaultBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: leading),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor ?? defaultTitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor ?? defaultSub,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subtitleColor ?? defaultSub),
          ],
        ),
      ),
    );
  }

  Future<void> showLanguageSheet(BuildContext context) async {
    const langs = [
      ('en', 'english',  'English'),
      ('ko', 'korean',   '한국어'),
      ('es', 'spanish',  'Español'),
      ('zh', 'chinese',  '中文'),
      ('ja', 'japanese', '日本語'),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: _isCA ? const Color(0xFF0A0A1A) : (_isMB ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFD)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < langs.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _settingTile(
                  leading: Icon(Icons.translate_rounded, color: _primaryDark),
                  title: langs[i].$3,
                  onTap: () {
                    Navigator.pop(context);
                    onLanguageChanged(langs[i].$1);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showCurrencySheet(BuildContext context) async {
    const currencies = [
      ('USD', 'US Dollar'),
      ('KRW', 'Korean Won'),
      ('EUR', 'Euro'),
      ('JPY', 'Japanese Yen'),
      ('GBP', 'British Pound'),
      ('CAD', 'Canadian Dollar'),
      ('AUD', 'Australian Dollar'),
      ('CNY', 'Chinese Yuan'),
      ('HKD', 'Hong Kong Dollar'),
      ('SGD', 'Singapore Dollar'),
      ('MXN', 'Mexican Peso'),
      ('BRL', 'Brazilian Real'),
      ('THB', 'Thai Baht'),
      ('VND', 'Vietnamese Dong'),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: _isCA ? const Color(0xFF0A0A1A) : (_isMB ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFD)),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ListView.separated(
              controller: scrollCtrl,
              itemCount: currencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _settingTile(
                leading: Icon(
                  Icons.attach_money_rounded,
                  color: _primaryDark,
                ),
                title: currencies[i].$1,
                subtitle: currencies[i].$2,
                onTap: () {
                  Navigator.pop(context);
                  onCurrencyChanged(currencies[i].$1);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showBudgetDialog(BuildContext context) async {
    final ctrl = TextEditingController(
      text: monthlyBudget > 0 ? monthlyBudget.toStringAsFixed(2) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('set_budget', language)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: t('budget_hint', language),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel', language)),
          ),
          if (monthlyBudget > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0.0),
              child: Text(
                t('delete', language),
                style: const TextStyle(color: Color(0xFFB4544A)),
              ),
            ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                ctrl.text.trim().replaceAll(',', ''),
              );
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: Text(t('save', language)),
          ),
        ],
      ),
    );

    if (result != null) {
      onBudgetChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _premiumBanner(context),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            gradient: (_isCA || _isMB) ? null : const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : null),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : _line)),
            boxShadow: (_isCA || _isMB) ? null : const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : _softBg),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      themeImage(selectedTheme, 'setting_card'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: (_isCA || _isMB) ? Colors.white : _textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _settingsSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : _textSub),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('language', language)),
        _settingTile(
          leading: _img('language'),
          title: t('language', language),
          subtitle: languageLabel,
          onTap: () => showLanguageSheet(context),
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('currency', language)),
        _settingTile(
          leading: _img('currency'),
          title: t('currency', language),
          subtitle: currency,
          onTap: () => showCurrencySheet(context),
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('monthly_budget', language)),
        _settingTile(
          leading: _img('monthly_budget'),
          title: t('monthly_budget', language),
          subtitle: monthlyBudget > 0
              ? monthlyBudget.toStringAsFixed(2)
              : t('no_budget_set', language),
          onTap: () => showBudgetDialog(context),
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('theme', language)),
        _settingTile(
          leading: _img('theme'),
          title: t('theme', language),
          subtitle: themeLabel,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ThemeSelectScreen(
                selectedTheme: selectedTheme,
                isPremium: isPremium,
                onThemeChanged: onThemeChanged,
                language: language,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('security', language)),
        if (!lockEnabled)
          _settingTile(
            leading: _img('set_passcode'),
            title: t('passcode_set', language),
            subtitle: t('lock_disabled', language),
            onTap: () async {
              await onEnablePasscodeLock();
            },
          )
        else ...[
          _settingTile(
            leading: _img('set_passcode'),
            title: t('passcode_lock', language),
            subtitle: t('lock_enabled', language),
            onTap: () async {
              await onChangePasscodeLock();
            },
          ),
          const SizedBox(height: 10),
          _actionTile(
            leading: _img('set_passcode'),
            title: t('change_passcode', language),
            subtitle: t('current_passcode', language),
            onTap: () async {
              await onChangePasscodeLock();
            },
          ),
          const SizedBox(height: 10),
          _actionTile(
            leading: _img('disable_passcode'),
            title: t('passcode_disable', language),
            subtitle: t('passcode_lock', language),
            onTap: () async {
              await onDisablePasscodeLock();
            },
            bgColor: _isCA ? const Color(0xFF1A0A1A) : (_isMB ? const Color(0xFF2A1515) : const Color(0xFFFFF6F4)),
            borderColor: _isCA ? const Color(0xFF2D0D0D) : (_isMB ? const Color(0xFF3D1818) : const Color(0xFFF1D5D0)),
            titleColor: const Color(0xFF8A3F39),
            subtitleColor: const Color(0xFFB4544A),
          ),
        ],
        const SizedBox(height: 18),

        _sectionTitle(t('data', language)),
        _actionTile(
          leading: _img('copy_json'),
          title: t('json_copy', language),
          subtitle: 'JSON',
          onTap: () async {
            await onExport();
          },
        ),
        const SizedBox(height: 10),
        _actionTile(
          leading: _img('paste_json'),
          title: t('json_paste', language),
          subtitle: 'JSON',
          onTap: () async {
            await onImport();
          },
        ),
        const SizedBox(height: 10),
        _settingTile(
          leading: _img('backup'),
          title: t('backup_to_file', language),
          subtitle: isPremium
              ? t('file_backup_subtitle', language)
              : t('premium_locked_hint', language),
          isLocked: !isPremium,
          onTap: isPremium ? () => _exportFile(context) : onOpenPaywall,
        ),
        const SizedBox(height: 10),
        _settingTile(
          leading: _img('backup'),
          title: t('restore_from_file', language),
          subtitle: isPremium
              ? t('file_backup_subtitle', language)
              : t('premium_locked_hint', language),
          isLocked: !isPremium,
          onTap: isPremium ? () => _importFile(context) : onOpenPaywall,
        ),
        const SizedBox(height: 10),
        _settingTile(
          leading: _img('export_csv'),
          title: t('export_csv', language),
          subtitle: isPremium
              ? t('csv_subtitle', language)
              : t('premium_locked_hint', language),
          isLocked: !isPremium,
          onTap: isPremium ? () => _exportCsv(context) : onOpenPaywall,
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('recurring_management', language)),
        _settingTile(
          leading: _img('recurring'),
          title: t('recurring_management', language),
          subtitle: isPremium
              ? t('recurring_subtitle', language)
              : t('premium_locked_hint', language),
          isLocked: !isPremium,
          onTap: isPremium
              ? () async { await onOpenRecurring(); }
              : onOpenPaywall,
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('custom_categories', language)),
        _settingTile(
          leading: _img('categories'),
          title: t('custom_categories', language),
          subtitle: t('category_subtitle', language),
          onTap: () async { await onOpenCategories(); },
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('app_icon', language)),
        _settingTile(
          leading: _img('app_icon'),
          title: t('app_icon', language),
          subtitle: t(IconService.labelKey(_currentIcon), language),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IconSelectScreen(
                  isPremium: isPremium,
                  currentIcon: _currentIcon,
                  language: language,
                ),
              ),
            );
            final updated = await IconService.getCurrentIcon();
            if (mounted) setState(() => _currentIcon = updated);
          },
        ),
        const SizedBox(height: 18),

        _sectionTitle('Subscription'),
        _actionTile(
          leading: Icon(Icons.card_membership_rounded, color: _primaryDark),
          title: 'Manage Subscription',
          subtitle: 'Apple Subscriptions',
          onTap: () async {
            final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
        ),
        const SizedBox(height: 10),
        _actionTile(
          leading: Icon(Icons.restore_rounded, color: _primaryDark),
          title: t('paywall_restore', language),
          subtitle: t('paywall_restore', language),
          onTap: () async {
            final svc = context.read<PurchaseService>();
            await svc.restorePurchases();

            // StoreKit 응답 기다리기 (최대 5초)
            for (var i = 0; i < 10; i++) {
              await Future.delayed(const Duration(milliseconds: 500));
              if (!context.mounted) return;
              if (svc.isPremium) break;
            }

            if (!context.mounted) return;
            final err = svc.errorMessage;
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err)),
              );
            } else if (svc.isPremium) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('paywall_purchase_success', language))),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('paywall_nothing_to_restore', language))),
              );
            }
          },
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('legal', language)),
        _actionTile(
          leading: _img('privacy'),
          title: t('privacy_policy', language),
          subtitle: t('privacy_policy_subtitle', language),
          onTap: () async {
            await onOpenPrivacyPolicy();
          },
        ),
        const SizedBox(height: 18),

        _sectionTitle(t('clear_all_entries', language)),
        _actionTile(
          leading: _img('clear'),
          title: t('clear_all_entries', language),
          subtitle: t('delete_all_message', language),
          onTap: () async {
            await onClear();
          },
          bgColor: _isCA ? const Color(0xFF1A0A1A) : (_isMB ? const Color(0xFF2A1515) : const Color(0xFFFFF6F4)),
          borderColor: _isCA ? const Color(0xFF2D0D0D) : (_isMB ? const Color(0xFF3D1818) : const Color(0xFFF1D5D0)),
          titleColor: const Color(0xFF8A3F39),
          subtitleColor: const Color(0xFFB4544A),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _handleVersionTap,
          child: Center(
            child: Text(
              'v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: _textSub.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  final String language;

  const PrivacyPolicyPage({super.key, required this.language});

  Widget _section({
    required String title,
    required String body,
    String? body2,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF24364A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D7186),
            ),
          ),
          if (body2 != null) ...[
            const SizedBox(height: 8),
            Text(
              body2,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D7186),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('privacy_policy_title', language))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE6D8AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_rounded,
                        color: Color(0xFF9C7A22),
                        size: 28,
                      ),
                      SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('privacy_policy_title', language),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF24364A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('privacy_intro', language),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6A5A2C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              title: t('privacy_collect_title', language),
              body: t('privacy_collect_body', language),
              body2: t('privacy_collect_body_2', language),
            ),
            _section(
              title: t('privacy_storage_title', language),
              body: t('privacy_storage_body', language),
            ),
            _section(
              title: t('privacy_backup_title', language),
              body: t('privacy_backup_body', language),
            ),
            _section(
              title: t('privacy_passcode_title', language),
              body: t('privacy_passcode_body', language),
            ),
            _section(
              title: t('privacy_third_party_title', language),
              body: t('privacy_third_party_body', language),
            ),
            _section(
              title: t('privacy_future_title', language),
              body: t('privacy_future_body', language),
            ),
            _section(
              title: t('privacy_contact_title', language),
              body: t('privacy_contact_body', language),
            ),
          ],
        ),
      ),
    );
  }
}
