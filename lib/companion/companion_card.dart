import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/i18n.dart';
import 'companion_character.dart';
import 'companion_controller.dart';
import 'companion_text.dart';
import 'insight.dart';

/// Compact Home card: the companion character and one short speech bubble.
///
/// The character only moves for a moment when it says something new, then
/// rests (no looping animation, to keep battery use low). Tapping shows the
/// next insight. Free users see a locked preview that opens the paywall.
class CompanionCard extends StatefulWidget {
  final String language;
  final String selectedTheme;
  final bool isPremium;
  final CompanionCharacter character;
  final List<Insight> insights;
  final String? lastShownId;
  final ValueChanged<String> onShown;
  final VoidCallback onOpenPaywall;
  final ValueChanged<CompanionCharacter> onChangeCharacter;

  const CompanionCard({
    super.key,
    required this.language,
    required this.selectedTheme,
    required this.isPremium,
    required this.character,
    required this.insights,
    required this.lastShownId,
    required this.onShown,
    required this.onOpenPaywall,
    required this.onChangeCharacter,
  });

  @override
  State<CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<CompanionCard> with SingleTickerProviderStateMixin {
  late final CompanionController _controller;
  late final AnimationController _motion;
  int _seenSpeak = 0;

  bool get _isCA => widget.selectedTheme == 'cyber_ai';
  bool get _isMB => widget.selectedTheme == 'minimal_black';
  bool get _dark => _isCA || _isMB;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _controller = CompanionController(lastShownId: widget.lastShownId, onShown: widget.onShown);
    if (widget.isPremium) _controller.setInsights(widget.insights);
    _controller.addListener(_onControllerChanged);
    _seenSpeak = _controller.speakCount;
    if (widget.isPremium && _controller.current != null) _motion.forward();
  }

  @override
  void didUpdateWidget(covariant CompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremium) _controller.setInsights(widget.insights);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.speakCount != _seenSpeak) {
      _seenSpeak = _controller.speakCount;
      _motion.forward(from: 0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _motion.dispose();
    super.dispose();
  }

  Future<void> _chooseCharacter() async {
    final picked = await showModalBottomSheet<CompanionCharacter>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('companion_choose', widget.language),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final c in CompanionCharacter.values)
                    Expanded(
                      child: _CharacterOption(
                        character: c,
                        label: t(c.labelKey, widget.language),
                        selected: c == widget.character,
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != widget.character) {
      widget.onChangeCharacter(picked);
      _motion.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = widget.isPremium;
    final insight = premium ? _controller.current : null;
    final message = premium
        ? (insight == null ? '' : insightText(insight, widget.language))
        : t('companion_locked', widget.language);

    final cardBg = _isCA
        ? const Color(0xFF0F0F2A)
        : (_isMB ? const Color(0xFF1E1E1E) : Colors.white);
    final border = _isCA
        ? const Color(0xFF2A2A5A)
        : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE));
    final bubbleBg = _isCA
        ? const Color(0xFF1A1A3A)
        : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF3F8FC));
    final textColor = _dark ? Colors.white : const Color(0xFF24364A);
    final subColor = _isCA
        ? const Color(0xFF6B6B9A)
        : (_isMB ? const Color(0xFF888888) : const Color(0xFF627487));

    return Semantics(
      button: true,
      label: '${t('companion_title', widget.language)}. $message',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: premium ? _controller.next : widget.onOpenPaywall,
          child: Ink(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildCharacter(premium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, ?current],
                        ),
                        child: Text(
                          message,
                          key: ValueKey(message),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (premium)
                    IconButton(
                      tooltip: t('companion_choose', widget.language),
                      visualDensity: VisualDensity.compact,
                      onPressed: _chooseCharacter,
                      icon: Icon(Icons.swap_horiz_rounded, size: 20, color: subColor),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.lock_rounded, size: 18, color: subColor),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacter(bool premium) {
    const size = 56.0;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final speaking = premium && _motion.isAnimating;
        // Three soft hops while speaking, then still.
        final hop = speaking ? (math.sin(_motion.value * 3 * math.pi)).abs() * 6 : 0.0;
        final image = Image.asset(
          speaking ? widget.character.speakingAsset : widget.character.idleAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: 192,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        );
        return Transform.translate(
          offset: Offset(0, -hop),
          child: SizedBox(
            width: size,
            height: size,
            child: premium ? image : Opacity(opacity: 0.55, child: image),
          ),
        );
      },
    );
  }
}

class _CharacterOption extends StatelessWidget {
  final CompanionCharacter character;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterOption({
    required this.character,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Image.asset(character.idleAsset, width: 64, height: 64, cacheWidth: 192),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
