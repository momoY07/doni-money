import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/i18n.dart';
import 'paywall_screen.dart';

class ThemeSelectScreen extends StatefulWidget {
  final String selectedTheme;
  final bool isPremium;
  final Function(String) onThemeChanged;
  final String language;

  const ThemeSelectScreen({
    super.key,
    required this.selectedTheme,
    required this.isPremium,
    required this.onThemeChanged,
    required this.language,
  });

  @override
  State<ThemeSelectScreen> createState() => _ThemeSelectScreenState();
}

class _ThemeSelectScreenState extends State<ThemeSelectScreen> {
  late String _mascot;  // 'otter' | 'dog' | 'minimal_black' | 'cyber_ai'

  static const _line = Color(0xFFD9E4EE);
  static const _softBg = Color(0xFFEAF1F8);
  static const _primaryDark = Color(0xFF5F7FA3);
  static const _textMain = Color(0xFF24364A);
  static const _textSub = Color(0xFF75879A);

  @override
  void initState() {
    super.initState();
    _mascot = mascotFromThemeId(widget.selectedTheme);
  }

  String get _defaultMode =>
      (_mascot == 'minimal_black' || _mascot == 'cyber_ai') ? 'dark' : 'system';

  void _apply() {
    widget.onThemeChanged(themeIdFromComponents(_mascot, _defaultMode));
  }

  void _selectMascot(String mascot, {bool requiresPremium = false}) async {
    if (requiresPremium && !widget.isPremium) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    setState(() => _mascot = mascot);
    _apply();
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 20, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textSub,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _mascotCard({
    required String mascot,
    required String label,
    required String assetPath,
    bool requiresPremium = false,
    bool fill = false,
  }) {
    final isSelected = _mascot == mascot;
    final isLocked = requiresPremium && !widget.isPremium;

    final card = GestureDetector(
        onTap: () => _selectMascot(mascot, requiresPremium: requiresPremium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? _softBg : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? _primaryDark : _line,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      assetPath,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (requiresPremium)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: Color(0xFF7A5500),
                        ),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      bottom: -6,
                      right: -6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: _primaryDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isLocked ? _textSub : _textMain,
                ),
              ),
              if (isLocked)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB0C4CC),
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
    return fill ? card : Expanded(child: card);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(t('theme_select', lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionLabel(t('section_mascot', lang).toUpperCase()),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mascotCard(
                mascot: 'otter',
                label: t('mascot_otter', lang),
                assetPath: 'assets/images/otter_month.png',
              ),
              const SizedBox(width: 14),
              _mascotCard(
                mascot: 'dog',
                label: t('mascot_dog', lang),
                assetPath: 'assets/images/dog_theme/dog_logo.png',
                requiresPremium: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _mascotCard(
            mascot: 'minimal_black',
            label: t('mascot_minimal_black', lang),
            assetPath: 'assets/images/minimal_black/mb_mascot_card.png',
            fill: true,
          ),
          const SizedBox(height: 14),
          _mascotCard(
            mascot: 'cyber_ai',
            label: t('mascot_cyber_ai', lang),
            assetPath: 'assets/images/cyber_ai/cy_mascot_card.png',
            requiresPremium: true,
            fill: true,
          ),
        ],
      ),
    );
  }
}
