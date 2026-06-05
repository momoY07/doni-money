import 'package:flutter/material.dart';

class AppThemePreset {
  final String id;
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color scaffoldBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color divider;
  final Color inputFill;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color snackBarBackground;
  final Color fabBackground;
  final Color fabForeground;
  final Color bottomBarBackground;
  final Color bottomSelected;
  final Color bottomUnselected;
  final Color segmentedSelectedBackground;
  final Color segmentedSelectedForeground;
  final Color segmentedForeground;
  final Color labelColor;
  final Color hintColor;

  const AppThemePreset({
    required this.id,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.scaffoldBackground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.divider,
    required this.inputFill,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.snackBarBackground,
    required this.fabBackground,
    required this.fabForeground,
    required this.bottomBarBackground,
    required this.bottomSelected,
    required this.bottomUnselected,
    required this.segmentedSelectedBackground,
    required this.segmentedSelectedForeground,
    required this.segmentedForeground,
    required this.labelColor,
    required this.hintColor,
  });
}

String themeLabelKey(String themeId) {
  switch (themeId) {
    case 'otter_light':    return 'theme_otter_light';
    case 'otter_dark':     return 'theme_otter_dark';
    case 'otter_system':   return 'theme_cream_otter';
    case 'dog':            return 'theme_dog';
    case 'dog_dark':       return 'theme_dog_dark';
    case 'dog_system':     return 'theme_dog_system';
    case 'minimal_black':  return 'theme_minimal_black';
    case 'cyber_ai':       return 'theme_cyber_ai';
    case 'cream':
    default:               return 'theme_cream_otter';
  }
}

/// 'otter' | 'dog' | 'minimal_black'
String mascotFromThemeId(String themeId) {
  if (themeId == 'dog' || themeId == 'dog_dark' || themeId == 'dog_system') {
    return 'dog';
  }
  if (themeId == 'minimal_black') return 'minimal_black';
  if (themeId == 'cyber_ai') return 'cyber_ai';
  return 'otter';
}

/// 'light' | 'dark' | 'system'
String brightnessKeyFromThemeId(String themeId) {
  if (themeId == 'otter_dark' || themeId == 'dog_dark' || themeId == 'minimal_black' || themeId == 'cyber_ai') return 'dark';
  if (themeId == 'cream' || themeId == 'dog_system' || themeId == 'otter_system') return 'system';
  return 'light';
}

String themeIdFromComponents(String mascot, String brightnessKey) {
  if (mascot == 'minimal_black') return 'minimal_black';
  if (mascot == 'cyber_ai') return 'cyber_ai';
  if (mascot == 'dog') {
    if (brightnessKey == 'dark') return 'dog_dark';
    if (brightnessKey == 'system') return 'dog_system';
    return 'dog';
  }
  if (brightnessKey == 'dark') return 'otter_dark';
  if (brightnessKey == 'system') return 'cream';
  return 'otter_light';
}

String lightThemeIdForMascot(String mascot) {
  if (mascot == 'minimal_black') return 'minimal_black';
  if (mascot == 'cyber_ai') return 'cyber_ai';
  return mascot == 'dog' ? 'dog' : 'otter_light';
}

String darkThemeIdForMascot(String mascot) {
  if (mascot == 'minimal_black') return 'minimal_black';
  if (mascot == 'cyber_ai') return 'cyber_ai';
  return mascot == 'dog' ? 'dog_dark' : 'otter_dark';
}

ThemeMode themeModeFromThemeId(String themeId) {
  if (themeId == 'otter_dark' || themeId == 'dog_dark' || themeId == 'minimal_black' || themeId == 'cyber_ai') {
    return ThemeMode.dark;
  }
  return ThemeMode.light;
}

AppThemePreset appThemePresetFromId(String themeId) {
  switch (themeId) {
    case 'otter_light':
      return const AppThemePreset(
        id: 'otter_light', brightness: Brightness.light,
        primary: Color(0xFF7EC8B8), secondary: Color(0xFFDDF6F0),
        surface: Colors.white, scaffoldBackground: Color(0xFFFFFFFF),
        appBarBackground: Colors.white, appBarForeground: Color(0xFF24364A),
        divider: Color(0xFFE0E0E0), inputFill: Colors.white,
        buttonBackground: Color(0xFF7EC8B8), buttonForeground: Colors.white,
        snackBarBackground: Color(0xFF24364A), fabBackground: Color(0xFFDDF6F0),
        fabForeground: Color(0xFF2E8F7D), bottomBarBackground: Colors.white,
        bottomSelected: Color(0xFF2E8F7D), bottomUnselected: Color(0xFFB0B0B0),
        segmentedSelectedBackground: Color(0xFFDDF6F0),
        segmentedSelectedForeground: Color(0xFF2E8F7D),
        segmentedForeground: Color(0xFF888888),
        labelColor: Color(0xFF4C6F68), hintColor: Color(0xFF9E9E9E),
      );
    case 'otter_dark':
      return const AppThemePreset(
        id: 'otter_dark', brightness: Brightness.dark,
        primary: Color(0xFF7EC8B8), secondary: Color(0xFF1A1A1A),
        surface: Color(0xFF111111), scaffoldBackground: Color(0xFF000000),
        appBarBackground: Color(0xFF000000), appBarForeground: Colors.white,
        divider: Color(0xFF2A2A2A), inputFill: Color(0xFF111111),
        buttonBackground: Color(0xFF7EC8B8), buttonForeground: Colors.black,
        snackBarBackground: Colors.white, fabBackground: Color(0xFF1A1A1A),
        fabForeground: Color(0xFF7EC8B8), bottomBarBackground: Color(0xFF111111),
        bottomSelected: Color(0xFF7EC8B8), bottomUnselected: Color(0xFF555555),
        segmentedSelectedBackground: Color(0xFF1A1A1A),
        segmentedSelectedForeground: Color(0xFF7EC8B8),
        segmentedForeground: Color(0xFF888888),
        labelColor: Color(0xFFAAAAAA), hintColor: Color(0xFF666666),
      );
    case 'dog_dark':
      return const AppThemePreset(
        id: 'dog_dark', brightness: Brightness.dark,
        primary: Color(0xFFE8A93B), secondary: Color(0xFF1A1A1A),
        surface: Color(0xFF111111), scaffoldBackground: Color(0xFF000000),
        appBarBackground: Color(0xFF000000), appBarForeground: Colors.white,
        divider: Color(0xFF2A2A2A), inputFill: Color(0xFF111111),
        buttonBackground: Color(0xFFE8A93B), buttonForeground: Colors.black,
        snackBarBackground: Colors.white, fabBackground: Color(0xFF1A1A1A),
        fabForeground: Color(0xFFE8A93B), bottomBarBackground: Color(0xFF111111),
        bottomSelected: Color(0xFFE8A93B), bottomUnselected: Color(0xFF555555),
        segmentedSelectedBackground: Color(0xFF1A1A1A),
        segmentedSelectedForeground: Color(0xFFE8A93B),
        segmentedForeground: Color(0xFF888888),
        labelColor: Color(0xFFAAAAAA), hintColor: Color(0xFF666666),
      );
    case 'dog':
      return const AppThemePreset(
        id: 'dog', brightness: Brightness.light,
        primary: Color(0xFFE8A93B), secondary: Color(0xFFFFF3D0),
        surface: Colors.white, scaffoldBackground: Colors.white,
        appBarBackground: Colors.white, appBarForeground: Color(0xFF24364A),
        divider: Color(0xFFE0E0E0), inputFill: Colors.white,
        buttonBackground: Color(0xFFE8A93B), buttonForeground: Colors.white,
        snackBarBackground: Color(0xFF24364A), fabBackground: Color(0xFFFFF3D0),
        fabForeground: Color(0xFFB07A12), bottomBarBackground: Colors.white,
        bottomSelected: Color(0xFFB07A12), bottomUnselected: Color(0xFFB0B0B0),
        segmentedSelectedBackground: Color(0xFFFFF3D0),
        segmentedSelectedForeground: Color(0xFFB07A12),
        segmentedForeground: Color(0xFF888888),
        labelColor: Color(0xFF8A7040), hintColor: Color(0xFF9E9E9E),
      );
    case 'minimal_black':
      return const AppThemePreset(
        id: 'minimal_black', brightness: Brightness.dark,
        primary: Color(0xFFC9A043), secondary: Color(0xFF1A1A1A),
        surface: Color(0xFF111111), scaffoldBackground: Color(0xFF1A1A1A),
        appBarBackground: Color(0xFF111111), appBarForeground: Colors.white,
        divider: Color(0xFF2A2A2A), inputFill: Color(0xFF111111),
        buttonBackground: Color(0xFFC9A043), buttonForeground: Colors.black,
        snackBarBackground: Colors.white, fabBackground: Color(0xFF1A1A1A),
        fabForeground: Color(0xFFC9A043), bottomBarBackground: Color(0xFF111111),
        bottomSelected: Color(0xFFC9A043), bottomUnselected: Color(0xFF555555),
        segmentedSelectedBackground: Color(0xFF2A2A2A),
        segmentedSelectedForeground: Color(0xFFC9A043),
        segmentedForeground: Color(0xFF666666),
        labelColor: Color(0xFFAAAAAA), hintColor: Color(0xFF555555),
      );
    case 'cyber_ai':
      return const AppThemePreset(
        id: 'cyber_ai', brightness: Brightness.dark,
        primary: Color(0xFF00D4FF), secondary: Color(0xFF7B2FFF),
        surface: Color(0xFF0F0F2A), scaffoldBackground: Color(0xFF0A0A1A),
        appBarBackground: Color(0xFF0A0A1A), appBarForeground: Colors.white,
        divider: Color(0xFF1A1A3A), inputFill: Color(0xFF0F0F2A),
        buttonBackground: Color(0xFF00D4FF), buttonForeground: Colors.black,
        snackBarBackground: Colors.white, fabBackground: Color(0xFF00D4FF),
        fabForeground: Colors.black, bottomBarBackground: Color(0xFF0A0A1A),
        bottomSelected: Color(0xFF00D4FF), bottomUnselected: Color(0xFF3A3A5A),
        segmentedSelectedBackground: Color(0xFF1A1A4A),
        segmentedSelectedForeground: Color(0xFF00D4FF),
        segmentedForeground: Color(0xFF3A3A5A),
        labelColor: Color(0xFF8080AA), hintColor: Color(0xFF3A3A5A),
      );
    case 'otter_system':
      return appThemePresetFromId('cream');
    case 'dog_system':
      return const AppThemePreset(
        id: 'dog_system', brightness: Brightness.light,
        primary: Color(0xFFA9BFF1), secondary: Color(0xFFE8EFFE),
        surface: Colors.white, scaffoldBackground: Color(0xFFF5F7FF),
        appBarBackground: Color(0xFFF5F7FF), appBarForeground: Color(0xFF2A3560),
        divider: Color(0xFFD4DCFA), inputFill: Colors.white,
        buttonBackground: Color(0xFFA9BFF1), buttonForeground: Color(0xFF1A2550),
        snackBarBackground: Color(0xFF2A3560), fabBackground: Color(0xFFE8EFFE),
        fabForeground: Color(0xFF4A6BC8), bottomBarBackground: Colors.white,
        bottomSelected: Color(0xFF4A6BC8), bottomUnselected: Color(0xFF8A9CC8),
        segmentedSelectedBackground: Color(0xFFE8EFFE),
        segmentedSelectedForeground: Color(0xFF4A6BC8),
        segmentedForeground: Color(0xFF6A7AA8),
        labelColor: Color(0xFF6A7AA8), hintColor: Color(0xFF9AAAD8),
      );
    case 'cream':
    default:
      return const AppThemePreset(
        id: 'cream',
        brightness: Brightness.light,
        primary: Color(0xFFEDD174),
        secondary: Color(0xFFF8EDC3),
        surface: Colors.white,
        scaffoldBackground: Color(0xFFFFFBF1),
        appBarBackground: Color(0xFFFFFBF1),
        appBarForeground: Color(0xFF5C4A1C),
        divider: Color(0xFFE8DDB7),
        inputFill: Colors.white,
        buttonBackground: Color(0xFFEDD174),
        buttonForeground: Color(0xFF5C4A1C),
        snackBarBackground: Color(0xFF5C4A1C),
        fabBackground: Color(0xFFF8EDC3),
        fabForeground: Color(0xFF9C7A22),
        bottomBarBackground: Colors.white,
        bottomSelected: Color(0xFF9C7A22),
        bottomUnselected: Color(0xFFB29A63),
        segmentedSelectedBackground: Color(0xFFF8EDC3),
        segmentedSelectedForeground: Color(0xFF9C7A22),
        segmentedForeground: Color(0xFF8A7440),
        labelColor: Color(0xFF8A7440),
        hintColor: Color(0xFFB29A63),
      );
  }
}

ThemeData buildLedgerTheme(String themeId) {
  final preset = appThemePresetFromId(themeId);

  return ThemeData(
    useMaterial3: true,
    brightness: preset.brightness,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: preset.primary,
          brightness: preset.brightness,
        ).copyWith(
          primary: preset.primary,
          secondary: preset.secondary,
          surface: preset.surface,
          onSurface: preset.appBarForeground,
          onPrimary: preset.buttonForeground,
        ),
    scaffoldBackgroundColor: preset.scaffoldBackground,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: preset.appBarBackground,
      foregroundColor: preset.appBarForeground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: preset.appBarForeground,
      ),
    ),
    cardTheme: CardThemeData(
      color: preset.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: preset.divider),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: preset.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: preset.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: preset.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: preset.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: preset.primary, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: preset.labelColor,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: preset.hintColor),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: preset.buttonBackground,
        foregroundColor: preset.buttonForeground,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: preset.snackBarBackground,
      contentTextStyle: TextStyle(
        color: preset.brightness == Brightness.dark
            ? const Color(0xFF102132)
            : Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: preset.bottomBarBackground,
      elevation: 0,
      selectedItemColor: preset.bottomSelected,
      unselectedItemColor: preset.bottomUnselected,
      selectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: preset.divider)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return preset.segmentedSelectedBackground;
          }
          return preset.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return preset.segmentedSelectedForeground;
          }
          return preset.segmentedForeground;
        }),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: preset.fabBackground,
      foregroundColor: preset.fabForeground,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
  );
}

bool isMbTheme(String themeId) => themeId == 'minimal_black';

// Returns [dark] for minimal_black, [light] for all other themes.
Color mbC(String themeId, Color light, Color dark) =>
    themeId == 'minimal_black' ? dark : light;

String themeImage(String themeId, String key) {
  if (themeId == 'dog' || themeId == 'dog_dark' || themeId == 'dog_system') {
    switch (key) {
      case 'bg_home': return 'assets/images/dog_theme/bg_home_dog.png';
      case 'mascot': return 'assets/images/dog_theme/dog_logo.png';
      case 'nav_home': return 'assets/images/dog_theme/dog_home.png';
      case 'nav_list': return 'assets/images/dog_theme/dog_list.png';
      case 'header_list': return 'assets/images/dog_theme/dog_list.png';
      case 'nav_calendar': return 'assets/images/dog_theme/dog_calendar.png';
      case 'nav_stats': return 'assets/images/dog_theme/dog_Stats.png';
      case 'nav_settings': return 'assets/images/dog_theme/dog_Settings.png';
      case 'no_data': return 'assets/images/dog_theme/dog_no.png';
      case 'setting_card': return 'assets/images/dog_theme/dog_setting_card.png';
    }
  }
  if (themeId == 'minimal_black') {
    switch (key) {
      case 'mascot': return 'assets/images/minimal_black/mb_mascot_card.png';
      case 'setting_card': return 'assets/images/minimal_black/mb_mascot_card.png';
      case 'nav_home': return 'assets/images/minimal_black/mb_nav_home.png';
      case 'nav_list': return 'assets/images/minimal_black/mb_nav_list.png';
      case 'nav_calendar': return 'assets/images/minimal_black/mb_nav_calendar.png';
      case 'nav_stats': return 'assets/images/minimal_black/mb_nav_stats.png';
      case 'nav_settings': return 'assets/images/minimal_black/mb_nav_settings.png';
      case 'no_data': return 'assets/images/minimal_black/mb_empty.png';
      case 'header_list': return 'assets/images/minimal_black/mb_month_header.png';
    }
  }
  if (themeId == 'cyber_ai') {
    switch (key) {
      case 'mascot': return 'assets/images/cyber_ai/cy_mascot_card.png';
      case 'setting_card': return 'assets/images/cyber_ai/cy_settings_header.png';
      case 'nav_home': return 'assets/images/cyber_ai/cy_nav_home.png';
      case 'nav_list': return 'assets/images/cyber_ai/cy_nav_list.png';
      case 'nav_calendar': return 'assets/images/cyber_ai/cy_nav_calendar.png';
      case 'nav_stats': return 'assets/images/cyber_ai/cy_nav_stats.png';
      case 'nav_settings': return 'assets/images/cyber_ai/cy_nav_settings.png';
      case 'no_data': return 'assets/images/cyber_ai/cy_empty.png';
      case 'header_list': return 'assets/images/cyber_ai/cy_month_header.png';
    }
  }
  switch (key) {
    case 'bg_home': return 'assets/images/bg_home_otter.png';
    case 'mascot': return 'assets/images/otter_month.png';
    case 'nav_home': return 'assets/images/nav_home.png';
    case 'nav_list': return 'assets/images/nav_list.png';
    case 'header_list': return 'assets/images/nav_list.png';
    case 'nav_calendar': return 'assets/images/nav_calendar.png';
    case 'nav_stats': return 'assets/images/nav_stats.png';
    case 'nav_settings': return 'assets/images/nav_settings.png';
    case 'no_data': return 'assets/images/no.png';
    case 'setting_card': return 'assets/images/simple_setting.png';
    default: return '';
  }
}
