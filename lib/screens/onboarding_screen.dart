import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage.dart';
import '../utils/i18n.dart';
import 'main_tabs.dart';
import 'paywall_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // Initialized from Hive (user's existing prefs), defaults applied on first launch
  String _language = 'en';
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ko'
            ? 'ko'
            : 'en';
    final savedLang =
        Storage.txBox.get('selectedLanguage', defaultValue: deviceLang) as String;
    final savedCur =
        Storage.txBox.get('selectedCurrency', defaultValue: 'USD') as String;
    _language = savedLang;
    _currency = savedCur;
  }

  void _goNext() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    // Save language + currency selected during onboarding
    await Storage.txBox.put('selectedLanguage', _language);
    await Storage.txBox.put('selectedCurrency', _currency);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainTabs()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _WelcomePage(
                language: _language,
                onStart: _goNext,
              ),
              _SetupPage(
                language: _language,
                currency: _currency,
                onLanguageChanged: (v) => setState(() => _language = v),
                onCurrencyChanged: (v) => setState(() => _currency = v),
                onNext: _goNext,
              ),
              _PremiumPage(
                language: _language,
                onFinish: _finishOnboarding,
              ),
            ],
          ),
          // Page indicator dots
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 1: Welcome ────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final String language;
  final VoidCallback onStart;

  const _WelcomePage({required this.language, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Logo
            Image.asset(
              'assets/images/app_icon/app_logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 28),
            // App name
            Text(
              t('onboarding_welcome', language),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            // Tagline
            Text(
              t('onboarding_tagline', language),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(160),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 4),
            // Start button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onStart,
                child: Text(
                  t('onboarding_start', language),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ─── Page 2: Setup ──────────────────────────────────────────────────────────

class _SetupPage extends StatelessWidget {
  final String language;
  final String currency;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onNext;

  const _SetupPage({
    required this.language,
    required this.currency,
    required this.onLanguageChanged,
    required this.onCurrencyChanged,
    required this.onNext,
  });

  static const _currencies = [
    'USD', 'KRW', 'EUR', 'JPY', 'GBP',
    'CAD', 'AUD', 'CNY', 'HKD', 'SGD',
    'MXN', 'BRL', 'THB', 'VND',
  ];

  static const _languages = [
    ('en', 'english',  'English'),
    ('ko', 'korean',   '한국어'),
    ('es', 'spanish',  'Español'),
    ('zh', 'chinese',  '中文'),
    ('ja', 'japanese', '日本語'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            Text(
              t('onboarding_setup_title', language),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('onboarding_setup_desc', language),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(160),
                height: 1.6,
              ),
            ),
            const Spacer(flex: 1),
            // Currency
            _SectionLabel(t('onboarding_select_currency', language)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: currency,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onCurrencyChanged(v);
              },
            ),
            const SizedBox(height: 20),
            // Language
            _SectionLabel(t('onboarding_select_language', language)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: language,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _languages
                  .map(
                    (l) => DropdownMenuItem(
                      value: l.$1,
                      child: Text(l.$3),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onLanguageChanged(v);
              },
            ),
            const Spacer(flex: 3),
            // Next button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onNext,
                child: Text(
                  t('onboarding_next', language),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ─── Page 3: Premium ────────────────────────────────────────────────────────

class _PremiumPage extends StatelessWidget {
  final String language;
  final VoidCallback onFinish;

  const _PremiumPage({required this.language, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              t('onboarding_premium_title', language),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('onboarding_premium_desc', language),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(160),
              ),
            ),
            const SizedBox(height: 24),
            // Comparison table
            _ComparisonTable(language: language),
            const SizedBox(height: 32),
            // Subscribe button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaywallScreen(),
                    ),
                  );
                  // Paywall dismissed — complete onboarding regardless
                  onFinish();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                ),
                child: Text(
                  t('onboarding_subscribe', language),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Later button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onFinish,
                child: Text(
                  t('onboarding_later', language),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final String language;

  const _ComparisonTable({required this.language});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;

    final features = [
      (
        t('onboarding_feature_logging', language),
        _Cell.check,
        _Cell.check,
      ),
      (
        t('onboarding_feature_categories', language),
        _Cell.text(t('onboarding_feature_categories_free', language)),
        _Cell.text(t('onboarding_feature_categories_premium', language)),
      ),
      (
        t('onboarding_feature_budget', language),
        _Cell.check,
        _Cell.check,
      ),
      (
        t('onboarding_feature_backup', language),
        _Cell.cross,
        _Cell.check,
      ),
      (
        t('onboarding_feature_csv', language),
        _Cell.cross,
        _Cell.check,
      ),
      (
        t('onboarding_feature_recurring', language),
        _Cell.cross,
        _Cell.check,
      ),
      (
        t('onboarding_feature_themes', language),
        _Cell.cross,
        _Cell.check,
      ),
      (
        t('onboarding_feature_app_icon', language),
        _Cell.cross,
        _Cell.check,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primary.withAlpha(60)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              color: primary.withAlpha(25),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                const Expanded(flex: 4, child: SizedBox()),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      t('onboarding_free', language),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      t('onboarding_premium', language),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Feature rows
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final isLast = i == features.length - 1;
            return Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(color: primary.withAlpha(30)),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        row.$1,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildCell(row.$2, context, isPremium: false),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildCell(row.$3, context, isPremium: true),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCell(_Cell cell, BuildContext context, {required bool isPremium}) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget content;

    switch (cell.type) {
      case _CellType.check:
        content = Icon(
          Icons.check_circle_rounded,
          color: isPremium ? primary : Colors.green.shade400,
          size: 20,
        );
      case _CellType.cross:
        content = Icon(
          Icons.cancel_rounded,
          color: Colors.grey.shade400,
          size: 20,
        );
      case _CellType.text:
        content = Text(
          cell.label ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPremium
                ? primary
                : Theme.of(context).colorScheme.onSurface.withAlpha(180),
          ),
        );
    }

    return Container(
      color: isPremium ? primary.withAlpha(12) : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: content),
    );
  }
}

enum _CellType { check, cross, text }

class _Cell {
  final _CellType type;
  final String? label;

  const _Cell._(this.type, [this.label]);

  static const check = _Cell._(_CellType.check);
  static const cross = _Cell._(_CellType.cross);
  static _Cell text(String label) => _Cell._(_CellType.text, label);
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF55736C),
      ),
    );
  }
}
