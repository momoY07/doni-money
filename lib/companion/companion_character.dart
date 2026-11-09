/// The Premium companion's look. Independent of the visual theme.
enum CompanionCharacter {
  otter('otter', 'companion_otter', 'assets/images/otter_month.png',
      'assets/images/log_today.png'),
  dog('dog', 'companion_dog', 'assets/images/dog_theme/dog_logo.png',
      'assets/images/dog_theme/dog_logo.png'),
  cyber('cyber', 'companion_cyber', 'assets/images/cyber_ai/cy_empty.png',
      'assets/images/cyber_ai/cy_empty.png');

  const CompanionCharacter(this.id, this.labelKey, this.idleAsset, this.speakingAsset);

  /// Stored value.
  final String id;
  final String labelKey;
  final String idleAsset;
  final String speakingAsset;

  /// Hive key in the app box. Not part of Premium state and not in backups.
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
}
