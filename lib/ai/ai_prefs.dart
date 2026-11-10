import 'dart:math';

import 'package:hive/hive.dart';

/// Local AI Conversation settings in the app's Hive box.
///
/// None of these keys are in BackupService.managedKeys: consent is asked
/// again on a new device, and the install id is never transferred.
class AiPrefs {
  AiPrefs(this._box);

  final Box _box;

  static const consentKey = 'aiConversationEnabled';
  static const installIdKey = 'aiInstallId';

  /// True only after the user tapped "Enable AI Conversation".
  bool get enabled => _box.get(consentKey) == true;

  Future<void> setEnabled(bool value) => _box.put(consentKey, value);

  /// Random id for server-side rate limiting only. Not derived from the
  /// device, Apple account or purchases; created on first AI use.
  String installId() {
    final existing = _box.get(installIdKey);
    if (existing is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(existing)) return existing;
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _box.put(installIdKey, id);
    return id;
  }
}
