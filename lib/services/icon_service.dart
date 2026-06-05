import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';

class IconService {
  /// iOS CFBundleAlternateIcons keys
  static const String classicAlternateName = 'classic_icon';
  static const String dogAlternateName = 'dog_icon';
  static const String otterAlternateName = 'SD_app_icon';
  static const String dogNewAlternateName = 'dog_app_icon';
  static const String mbAlternateName = 'mb_app_icon';
  static const String cyAlternateName = 'cy_app_icon';

  static Future<void> setIcon(String? iconName) async {
    try {
      if (await FlutterDynamicIcon.supportsAlternateIcons) {
        await FlutterDynamicIcon.setAlternateIconName(iconName);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> getCurrentIcon() async {
    try {
      return await FlutterDynamicIcon.getAlternateIconName();
    } catch (e) {
      return null;
    }
  }

  /// Older builds used `ClassicIcon` / `DogIcon`; re-apply with current plist keys.
  static Future<void> migrateLegacyAlternateIconNames() async {
    try {
      if (!await FlutterDynamicIcon.supportsAlternateIcons) return;
      final name = await FlutterDynamicIcon.getAlternateIconName();
      if (name == 'ClassicIcon') {
        await FlutterDynamicIcon.setAlternateIconName(classicAlternateName);
      } else if (name == 'DogIcon') {
        await FlutterDynamicIcon.setAlternateIconName(dogAlternateName);
      }
    } catch (_) {}
  }

  static String labelKey(String? storedName) {
    switch (storedName) {
      case classicAlternateName:
      case 'ClassicIcon':
        return 'icon_classic';
      case dogAlternateName:
      case 'DogIcon':
        return 'icon_dog';
      case otterAlternateName:
        return 'icon_otter';
      case dogNewAlternateName:
        return 'icon_dog_new';
      case mbAlternateName:
        return 'icon_mb';
      case cyAlternateName:
        return 'icon_cy';
      default:
        return 'icon_default';
    }
  }

  /// Returns the icon name that matches a given themeId, or null for default.
  static String? iconNameForTheme(String themeId) {
    if (themeId == 'otter_light' || themeId == 'otter_dark' ||
        themeId == 'otter_system' || themeId == 'cream') {
      return otterAlternateName;
    }
    if (themeId == 'dog' || themeId == 'dog_dark' || themeId == 'dog_system') {
      return dogNewAlternateName;
    }
    if (themeId == 'minimal_black') return mbAlternateName;
    if (themeId == 'cyber_ai') return cyAlternateName;
    return null;
  }
}
