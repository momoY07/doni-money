import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_ledger/companion/companion_card.dart';
import 'package:simple_ledger/companion/companion_character.dart';
import 'package:simple_ledger/companion/insight.dart';
import 'package:simple_ledger/utils/i18n.dart';

final _now = DateTime(2026, 11, 18);

Insight _ins(String id, String key, [Map<String, Object> args = const {}]) => Insight(
    id: id, type: InsightType.recentActivity, priority: 1, localizationKey: key, args: args,
    generatedAt: _now);

/// One frame to start animations, then let them finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  Future<void> pump(WidgetTester tester,
      {required bool premium,
      VoidCallback? onPaywall,
      List<MoneyQuestion>? asked,
      List<String>? shown,
      bool reduceMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: CompanionCard(
            language: 'en',
            selectedTheme: 'cream',
            isPremium: premium,
            character: CompanionCharacter.otter,
            insights: [
              _ins('streak:3', 'insight_streak', {'days': 3}),
              _ins('activity:5', 'insight_week_activity', {'count': 5}),
            ],
            lastShownId: null,
            onShown: (id) => shown?.add(id),
            onOpenPaywall: onPaywall ?? () {},
            answerFor: premium
                ? (q) {
                    asked?.add(q);
                    return Insight(
                      id: 'notEnough',
                      type: InsightType.notEnoughData,
                      priority: 0,
                      localizationKey: 'answer_top_not_enough',
                      generatedAt: _now,
                    );
                  }
                : null,
          ),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Premium: Ask shows 3 questions; answer shows; tap returns to insights',
      (tester) async {
    final asked = <MoneyQuestion>[];
    final shown = <String>[];
    await pump(tester, premium: true, asked: asked, shown: shown);
    expect(find.textContaining(t('insight_streak', 'en').replaceAll('{days}', '3')),
        findsOneWidget);
    for (final q in MoneyQuestion.values) {
      expect(find.text(t(q.labelKey, 'en')), findsNothing);
    }

    await tester.tap(find.byTooltip('Ask'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (final q in MoneyQuestion.values) {
      expect(find.text(t(q.labelKey, 'en')), findsOneWidget);
    }

    await tester.tap(find.text(t('question_top_category', 'en')));
    await settle(tester);
    expect(asked, [MoneyQuestion.topCategory]);
    expect(find.textContaining(t('answer_top_not_enough', 'en')), findsOneWidget);
    expect(find.text(t('question_compare_last_month', 'en')), findsNothing);
    expect(shown, ['streak:3'], reason: 'answers are not recorded as shown insights');

    // Tap the card: back to the insight rotation (next insight).
    await tester.tap(find.textContaining(t('answer_top_not_enough', 'en')));
    await settle(tester);
    expect(find.textContaining(t('answer_top_not_enough', 'en')), findsNothing);
    expect(shown, ['streak:3', 'activity:5']);
    await finish(tester);
  });

  testWidgets('free user: locked preview, no Ask, tap opens paywall', (tester) async {
    var paywall = 0;
    await pump(tester, premium: false, onPaywall: () => paywall++);
    expect(find.text(t('companion_locked', 'en')), findsOneWidget);
    expect(find.byTooltip('Ask'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    await tester.tap(find.text(t('companion_locked', 'en')));
    expect(paywall, 1);
    await finish(tester);
  });

  /// Whether any transform inside the card currently moves the character.
  bool characterMoved(WidgetTester tester) => tester
      .widgetList<Transform>(
          find.descendant(of: find.byType(CompanionCard), matching: find.byType(Transform)))
      .any((w) => !w.transform.isIdentity());

  testWidgets('character moves briefly when it speaks, then rests', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await pump(tester, premium: true);
    await tester.tap(find.byType(CompanionCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(characterMoved(tester), isTrue);
    await settle(tester);
    expect(characterMoved(tester), isFalse);
    await finish(tester);
  });

  testWidgets('Reduce Motion: no movement, questions still work', (tester) async {
    await pump(tester, premium: true, reduceMotion: true);
    await tester.tap(find.byType(CompanionCard));
    for (var ms = 0; ms < 1200; ms += 100) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(characterMoved(tester), isFalse);
    }
    await tester.tap(find.byTooltip('Ask'));
    await tester.pump();
    expect(find.text(t('question_month_status', 'en')), findsOneWidget);
    await tester.tap(find.text(t('question_month_status', 'en')));
    await tester.pump();
    expect(find.textContaining(t('answer_top_not_enough', 'en')), findsOneWidget);
    expect(characterMoved(tester), isFalse);
    await finish(tester);
  });
}
