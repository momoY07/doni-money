/// The Premium companion's look. Independent of the visual theme.
///
/// Pure Dart (no Flutter imports) so the backup engine can validate ids.
enum CompanionCharacter {
  otter(
    'otter',
    'companion_otter',
    idleAsset: 'assets/images/otter_month.png',
    speakingAsset: 'assets/images/log_today.png',
    happyAsset: 'assets/images/log_today.png',
  ),
  dog(
    'dog',
    'companion_dog',
    idleAsset: 'assets/images/dog_theme/dog_logo.png',
    speakingAsset: 'assets/images/dog_theme/dog_logo.png',
    happyAsset: 'assets/images/dog_theme/dog_logo.png',
  ),
  cyber(
    'cyber',
    'companion_cyber',
    idleAsset: 'assets/images/cyber_ai/cy_empty.png',
    speakingAsset: 'assets/images/cyber_ai/cy_empty.png',
    happyAsset: 'assets/images/cyber_ai/cy_empty.png',
  );

  const CompanionCharacter(
    this.id,
    this.labelKey, {
    required this.idleAsset,
    required this.speakingAsset,
    required this.happyAsset,
  });

  /// Stored value (Hive and backups).
  final String id;
  final String labelKey;
  final String idleAsset;
  final String speakingAsset;
  final String happyAsset;

  /// Hive key in the app box. Not part of Premium state. Included in
  /// backups (optional field) only when the user picked one explicitly.
  static const storageKey = 'companionCharacter';

  static CompanionCharacter? fromId(Object? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Default before the user picks one: match the current theme's mascot.
  static CompanionCharacter defaultForTheme(String themeId) {
    if (themeId == 'cyber_ai') return cyber;
    if (themeId.contains('dog')) return dog;
    return otter;
  }

  /// The character to show: an explicit (valid) choice always wins over the
  /// theme; otherwise follow the theme. Unknown stored values are ignored.
  static CompanionCharacter resolve(Object? storedId, String themeId) =>
      fromId(storedId) ?? defaultForTheme(themeId);
}
