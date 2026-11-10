import 'package:hive/hive.dart';

import 'companion_character.dart';

/// Local companion preferences in the app's Hive box. Nothing here is
/// Premium state; entitlement stays in PurchaseService.
class CompanionPrefs {
  CompanionPrefs(this._box);

  final Box _box;

  static const lastInsightKey = 'companionLastInsight';

  /// The user's explicit choice, or null when they never picked one (or the
  /// stored value is unknown), meaning "follow the theme".
  CompanionCharacter? get explicitChoice =>
      CompanionCharacter.fromId(_box.get(CompanionCharacter.storageKey));

  Future<void> setChoice(CompanionCharacter c) =>
      _box.put(CompanionCharacter.storageKey, c.id);

  CompanionCharacter effective(String themeId) =>
      CompanionCharacter.resolve(_box.get(CompanionCharacter.storageKey), themeId);

  String? get lastShownId {
    final v = _box.get(lastInsightKey);
    return v is String ? v : null;
  }

  Future<void> setLastShownId(String id) => _box.put(lastInsightKey, id);
}
