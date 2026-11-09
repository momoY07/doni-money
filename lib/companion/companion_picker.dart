import 'package:flutter/material.dart';

import '../utils/i18n.dart';
import 'companion_character.dart';

/// Row of the three companions with a preview of each. Used in Settings.
/// Locked (free) users still see the previews; tapping calls [onSelect] and
/// the caller decides (Settings opens the existing paywall).
class CompanionPicker extends StatelessWidget {
  final String language;
  final CompanionCharacter selected;
  final bool locked;
  final bool dark;
  final Color accent;
  final Color border;
  final Color tileBg;
  final Color textColor;
  final ValueChanged<CompanionCharacter> onSelect;

  const CompanionPicker({
    super.key,
    required this.language,
    required this.selected,
    required this.locked,
    required this.dark,
    required this.accent,
    required this.border,
    required this.tileBg,
    required this.textColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in CompanionCharacter.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _tile(c),
            ),
          ),
      ],
    );
  }

  Widget _tile(CompanionCharacter c) {
    final isSelected = !locked && c == selected;
    final label = t(c.labelKey, language);
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: tileBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isSelected ? accent : border, width: isSelected ? 2 : 1),
        ),
        child: InkWell(
          key: ValueKey('companion_pick_${c.id}'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onTap: () => onSelect(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: locked ? 0.55 : 1,
                      child: Image.asset(
                        c.idleAsset,
                        width: 56,
                        height: 56,
                        cacheWidth: 192,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    if (locked)
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Icon(Icons.lock_rounded,
                            size: 16, color: dark ? Colors.white70 : const Color(0xFF8AA0AE)),
                      )
                    else if (isSelected)
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Icon(Icons.check_circle_rounded, size: 18, color: accent),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
