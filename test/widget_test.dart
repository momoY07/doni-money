// App boot smoke test: the real widget tree (providers + MainTabs) starts on
// existing storage and shows stored data. Replaces the unused `flutter create`
// counter template that never matched this app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_ledger/main.dart';
import 'package:simple_ledger/services/purchase_service.dart';
import 'package:simple_ledger/storage.dart';
import 'package:simple_ledger/tx_repo.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('app_smoke');
    Hive.init(tmp.path);
    await Hive.openBox(Storage.txBoxName);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  testWidgets('app boots to main tabs and reads existing records', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.runAsync(() async {
      await Storage.txBox.putAll({
        'selectedLanguage': 'en',
        'selectedCurrency': 'USD',
        'items': [
          jsonEncode({
            'id': 'smoke1',
            'isExpense': true,
            'amount': 12.5,
            'category': '☕ Coffee',
            'note': 'smoke-test-latte',
            'date': DateTime.now().toIso8601String(),
            // Already normalized, so TxRepo has nothing to rewrite on boot.
            'entryCurrency': '',
            'baseAmount': 12.5,
            'baseCurrency': '',
            'exchangeRate': 1.0,
            'currencyMetaVersion': 0,
          }),
        ],
      });
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TxRepo()),
          ChangeNotifierProvider(create: (_) => PurchaseService()),
        ],
        child: const SimpleLedgerApp(showOnboarding: false),
      ),
    );
    await tester.pump();

    expect(find.text('Doni Money'), findsWidgets);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Open the List tab: the stored row is rendered.
    await tester.tap(find.text('List'));
    await tester.pump();
    expect(find.textContaining('smoke-test-latte'), findsWidgets);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
