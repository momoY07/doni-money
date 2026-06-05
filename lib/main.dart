import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main_tabs.dart';
import 'screens/onboarding_screen.dart';
import 'services/icon_service.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';
import 'storage.dart';
import 'tx_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await initializeDateFormatting('en_US', null);
  await Storage.init();
  await IconService.migrateLegacyAlternateIconNames();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  final purchaseService = PurchaseService();
  // Initialize async; UI renders immediately with cached isPremium from prefs
  purchaseService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TxRepo()),
        ChangeNotifierProvider.value(value: purchaseService),
      ],
      child: SimpleLedgerApp(showOnboarding: !onboardingDone),
    ),
  );
}

class SimpleLedgerApp extends StatelessWidget {
  final bool showOnboarding;

  const SimpleLedgerApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: Storage.txBox.listenable(keys: ['selectedTheme']),
      builder: (context, box, _) {
        final selectedTheme =
            box.get('selectedTheme', defaultValue: 'cream') as String;
        final mascot = mascotFromThemeId(selectedTheme);
        final isDark = themeModeFromThemeId(selectedTheme) == ThemeMode.dark;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Doni Money',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: isDark
              ? buildLedgerTheme(lightThemeIdForMascot(mascot))
              : buildLedgerTheme(selectedTheme),
          darkTheme: isDark
              ? buildLedgerTheme(selectedTheme)
              : buildLedgerTheme(darkThemeIdForMascot(mascot)),
          home: showOnboarding ? const OnboardingScreen() : const MainTabs(),
        );
      },
    );
  }
}
