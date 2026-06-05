import 'package:flutter/material.dart';

import '../services/icon_service.dart';
import '../utils/i18n.dart';
import 'paywall_screen.dart';

class IconSelectScreen extends StatefulWidget {
  final bool isPremium;
  final String? currentIcon;
  final String language;

  const IconSelectScreen({
    super.key,
    required this.isPremium,
    required this.currentIcon,
    required this.language,
  });

  @override
  State<IconSelectScreen> createState() => _IconSelectScreenState();
}

class _IconSelectScreenState extends State<IconSelectScreen> {
  static const _line = Color(0xFFD9E4EE);
  static const _primaryDark = Color(0xFF5F7FA3);
  static const _textMain = Color(0xFF24364A);
  static const _textSub = Color(0xFF75879A);

  late String? _currentIcon;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentIcon = widget.currentIcon;
  }

  Future<void> _handleSelect(String? iconName, {bool requiresPremium = false}) async {
    if (requiresPremium && !widget.isPremium) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    if (_currentIcon == iconName || _loading) return;

    setState(() => _loading = true);
    try {
      await IconService.setIcon(iconName);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('아이콘 변경 실패: $e')),
        );
      }
      return;
    }
    final updated = await IconService.getCurrentIcon();
    if (mounted) {
      setState(() {
        _currentIcon = updated;
        _loading = false;
      });
    }
  }

  Widget _iconCard({
    required String label,
    required String assetPath,
    required String? iconName,
    bool requiresPremium = false,
  }) {
    final isSelected = _currentIcon == iconName;
    final isLocked = requiresPremium && !widget.isPremium;

    return GestureDetector(
      onTap: () => _handleSelect(iconName, requiresPremium: requiresPremium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF1F8) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _primaryDark : _line,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLocked ? _textSub : _textMain,
              ),
            ),
            if (isLocked)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB0C4CC),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('app_icon', widget.language))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.70,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _iconCard(
                    label: t('icon_otter', widget.language),
                    assetPath: 'assets/images/SD_app_icon.png',
                    iconName: IconService.otterAlternateName,
                  ),
                  _iconCard(
                    label: t('icon_dog_new', widget.language),
                    assetPath: 'assets/images/dog_theme/dog_app_icon.png',
                    iconName: IconService.dogNewAlternateName,
                    requiresPremium: true,
                  ),
                  _iconCard(
                    label: t('icon_mb', widget.language),
                    assetPath: 'assets/images/minimal_black/mb_app_icon.png',
                    iconName: IconService.mbAlternateName,
                  ),
                  _iconCard(
                    label: t('icon_cy', widget.language),
                    assetPath: 'assets/images/cyber_ai/cy_app_icon.png',
                    iconName: IconService.cyAlternateName,
                    requiresPremium: true,
                  ),
                  _iconCard(
                    label: t('icon_classic', widget.language),
                    assetPath: 'assets/images/app_icon/classic_icon.png',
                    iconName: IconService.classicAlternateName,
                  ),
                ],
              ),
            ),
    );
  }
}
