import 'package:flutter_test/flutter_test.dart';
import 'package:simple_ledger/companion/companion_controller.dart';
import 'package:simple_ledger/companion/companion_text.dart';
import 'package:simple_ledger/companion/insight.dart';
import 'package:simple_ledger/companion/money_insight_engine.dart';
import 'package:simple_ledger/utils/i18n.dart';

// "Now" is Wed 2026-11-18 10:00, so this month = November, last = October.
final now = DateTime(2026, 11, 18, 10);
const engine = MoneyInsightEngine();

InsightTransaction spend(DateTime date, double amount,
        {String category = '☕ Coffee', String currency = 'USD'}) =>
    InsightTransaction(
        date: date, isExpense: true, amount: amount, category: category, currency: currency);

InsightTransaction income(DateTime date, double amount, {String currency = 'USD'}) =>
    InsightTransaction(
        date: date, isExpense: false, amount: amount, category: '💰 Salary', currency: currency);

InsightRecurring monthly(int day, {bool active = true}) => InsightRecurring(
    isActive: active,
    isExpense: true,
    amount: 10,
    category: '📱 Phone',
    currency: 'USD',
    frequency: 'monthly',
    dayOfMonth: day,
    dayOfWeek: 1);

InsightRecurring weekly(int weekday) => InsightRecurring(
    isActive: true,
    isExpense: true,
    amount: 5,
    category: '🍔 Food',
    currency: 'USD',
    frequency: 'weekly',
    dayOfMonth: 1,
    dayOfWeek: weekday);

List<Insight> run(List<InsightTransaction> tx,
        {List<InsightRecurring> recurring = const [],
        double budget = 0,
        String currency = 'USD',
        DateTime? at}) =>
    engine.generate(InsightInput(
      now: at ?? now,
      transactions: tx,
      recurring: recurring,
      monthlyBudget: budget,
      budgetCurrency: currency,
    ));

Insight? ofType(List<Insight> list, InsightType type) {
  for (final i in list) {
    if (i.type == type) return i;
  }
  return null;
}

void main() {
  group('spending vs last month (same point in the month)', () {
    test('higher than last month → percent increase', () {
      final r = run([
        spend(DateTime(2026, 10, 5), 100),
        spend(DateTime(2026, 10, 25), 999), // after the 18th: not comparable
        spend(DateTime(2026, 11, 3), 80),
        spend(DateTime(2026, 11, 10), 50),
      ]);
      final i = ofType(r, InsightType.spendingVsLastMonth)!;
      expect(i.localizationKey, 'insight_spend_up');
      expect(i.args['percent'], 30);
      expect(i.currency, 'USD');
    });

    test('lower than last month → amount less, in that currency', () {
      final r = run([
        spend(DateTime(2026, 10, 2), 200),
        spend(DateTime(2026, 11, 2), 114),
      ]);
      final i = ofType(r, InsightType.spendingVsLastMonth)!;
      expect(i.localizationKey, 'insight_spend_down');
      expect(i.args['amount'], const InsightAmount(86, 'USD'));
    });

    test('small difference → "about the same"', () {
      final r = run([spend(DateTime(2026, 10, 2), 100), spend(DateTime(2026, 11, 2), 103)]);
      expect(ofType(r, InsightType.spendingVsLastMonth)!.localizationKey, 'insight_spend_same');
    });

    test('previous month is zero → no comparison at all', () {
      final r = run([
        income(DateTime(2026, 10, 2), 1000),
        spend(DateTime(2026, 11, 2), 50),
      ]);
      expect(ofType(r, InsightType.spendingVsLastMonth), isNull);
    });

    test('no spending yet this month → no comparison', () {
      final r = run([spend(DateTime(2026, 10, 2), 50)]);
      expect(ofType(r, InsightType.spendingVsLastMonth), isNull);
    });

    test('January compares with December of the previous year', () {
      final r = run([
        spend(DateTime(2025, 12, 3), 100),
        spend(DateTime(2026, 1, 3), 150),
      ], at: DateTime(2026, 1, 10));
      expect(ofType(r, InsightType.spendingVsLastMonth)!.args['percent'], 50);
    });

    test('future-dated entries are ignored', () {
      final r = run([
        spend(DateTime(2026, 10, 2), 100),
        spend(DateTime(2026, 11, 2), 100),
        spend(DateTime(2026, 11, 28), 500),
      ]);
      expect(ofType(r, InsightType.spendingVsLastMonth)!.localizationKey, 'insight_spend_same');
    });
  });

  group('largest category', () {
    test('picks the category with the highest total and its share', () {
      final r = run([
        spend(DateTime(2026, 11, 1), 30, category: '☕ Coffee'),
        spend(DateTime(2026, 11, 2), 30, category: '☕ Coffee'),
        spend(DateTime(2026, 11, 3), 40, category: '🍔 Food'),
        income(DateTime(2026, 11, 4), 5000),
      ]);
      final i = ofType(r, InsightType.topCategory)!;
      expect(i.args['category'], const InsightCategory('☕ Coffee'));
      expect(i.args['percent'], 60);
      expect(i.category, '☕ Coffee');
    });

    test('not reported with too few entries, one category, or a tie', () {
      expect(
          ofType(run([spend(DateTime(2026, 11, 1), 10), spend(DateTime(2026, 11, 2), 10, category: '🍔 Food')]),
              InsightType.topCategory),
          isNull);
      expect(
          ofType(
              run([
                spend(DateTime(2026, 11, 1), 10),
                spend(DateTime(2026, 11, 2), 10),
                spend(DateTime(2026, 11, 3), 10),
              ]),
              InsightType.topCategory),
          isNull);
      expect(
          ofType(
              run([
                spend(DateTime(2026, 11, 1), 10),
                spend(DateTime(2026, 11, 2), 10, category: '🍔 Food'),
                spend(DateTime(2026, 11, 3), 5, category: '🍔 Food'),
                spend(DateTime(2026, 11, 4), 5),
              ]),
              InsightType.topCategory),
          isNull);
    });
  });

  group('monthly budget', () {
    test('percentage used', () {
      final r = run([spend(DateTime(2026, 11, 2), 360), spend(DateTime(2026, 10, 2), 900)],
          budget: 500);
      final i = ofType(r, InsightType.budgetUsage)!;
      expect(i.localizationKey, 'insight_budget_used');
      expect(i.args['percent'], 72);
      expect(i.priority, MoneyInsightEngine.pBudgetNormal);
    });

    test('80% or more is high priority; over budget shows the amount over', () {
      final high = ofType(run([spend(DateTime(2026, 11, 2), 450)], budget: 500), InsightType.budgetUsage)!;
      expect(high.priority, MoneyInsightEngine.pBudgetHigh);

      final over = ofType(run([spend(DateTime(2026, 11, 2), 620)], budget: 500), InsightType.budgetUsage)!;
      expect(over.localizationKey, 'insight_budget_over');
      expect(over.args['amount'], const InsightAmount(120, 'USD'));
      expect(over.priority, MoneyInsightEngine.pBudgetOver);
    });

    test('budget not set → nothing', () {
      expect(ofType(run([spend(DateTime(2026, 11, 2), 100)]), InsightType.budgetUsage), isNull);
    });

    test('no spending yet → nothing', () {
      expect(ofType(run([], budget: 500), InsightType.budgetUsage), isNull);
    });
  });

  group('upcoming recurring', () {
    test('counts active entries due after today within 7 days', () {
      final r = run([], recurring: [
        monthly(20), // in 2 days
        monthly(25), // in 7 days
        monthly(26), // in 8 days → no
        monthly(18), // today: already added on launch → next month
        monthly(21, active: false), // paused
        weekly(1), // next Monday (23rd)
      ]);
      final i = ofType(r, InsightType.upcomingRecurring)!;
      expect(i.localizationKey, 'insight_recurring_upcoming');
      expect(i.args['count'], 3);
      expect(i.args['days'], 7);
    });

    test('one entry uses the singular text; wraps into next month', () {
      final r = run([], recurring: [monthly(2)], at: DateTime(2026, 11, 28));
      final i = ofType(r, InsightType.upcomingRecurring)!;
      expect(i.localizationKey, 'insight_recurring_upcoming_one');
    });

    test('no recurring entries → nothing', () {
      expect(ofType(run([]), InsightType.upcomingRecurring), isNull);
      expect(ofType(run([], recurring: [monthly(5)]), InsightType.upcomingRecurring), isNull);
    });

    test('next due date handles short months', () {
      final next = MoneyInsightEngine.nextOccurrenceAfter(monthly(31), DateTime(2026, 2, 10));
      expect(next, DateTime(2026, 2, 28));
    });
  });

  group('activity', () {
    test('streak of consecutive days ending today', () {
      final r = run([
        income(DateTime(2026, 11, 18, 8), 1),
        spend(DateTime(2026, 11, 17), 1),
        spend(DateTime(2026, 11, 16), 1),
        spend(DateTime(2026, 11, 15), 1),
        spend(DateTime(2026, 11, 15, 20), 1),
        spend(DateTime(2026, 11, 13), 1), // gap on the 14th
      ]);
      final i = ofType(r, InsightType.recordStreak)!;
      expect(i.args['days'], 4);
      expect(ofType(r, InsightType.recentActivity), isNull);
    });

    test('streak may end yesterday (today not logged yet)', () {
      final r = run([
        spend(DateTime(2026, 11, 17), 1),
        spend(DateTime(2026, 11, 16), 1),
        spend(DateTime(2026, 11, 15), 1),
      ]);
      expect(ofType(r, InsightType.recordStreak)!.args['days'], 3);
    });

    test('short streak → recent activity count instead', () {
      final r = run([spend(DateTime(2026, 11, 18), 1), spend(DateTime(2026, 11, 12), 1), spend(DateTime(2026, 11, 1), 1)]);
      expect(ofType(r, InsightType.recordStreak), isNull);
      final a = ofType(r, InsightType.recentActivity)!;
      expect(a.args['count'], 2);
      expect(a.localizationKey, 'insight_week_activity');
    });

    test('nothing in the last 7 days → no activity insight', () {
      final r = run([spend(DateTime(2026, 11, 1), 1)]);
      expect(ofType(r, InsightType.recentActivity), isNull);
      expect(ofType(r, InsightType.recordStreak), isNull);
    });
  });

  group('empty and ordering', () {
    test('empty history → only the get-started line', () {
      final r = run([]);
      expect(r, hasLength(1));
      expect(r.single.type, InsightType.getStarted);
    });

    test('get-started is not shown when there is something real', () {
      final r = run([spend(DateTime(2026, 11, 18), 5)]);
      expect(ofType(r, InsightType.getStarted), isNull);
    });

    test('sorted by priority', () {
      final r = run([
        spend(DateTime(2026, 10, 2), 100),
        spend(DateTime(2026, 11, 2), 620, category: '🍔 Food'),
        spend(DateTime(2026, 11, 3), 10),
        spend(DateTime(2026, 11, 4), 10),
      ], budget: 500, recurring: [monthly(20)]);
      final priorities = r.map((i) => i.priority).toList();
      expect(priorities, [...priorities]..sort((a, b) => b.compareTo(a)));
      expect(r.first.localizationKey, 'insight_budget_over');
    });
  });

  group('multiple currencies are never mixed', () {
    test('comparison and top category use only the selected currency', () {
      final r = run([
        spend(DateTime(2026, 10, 2), 100),
        spend(DateTime(2026, 10, 3), 90000, currency: 'KRW'),
        spend(DateTime(2026, 11, 2), 50),
        spend(DateTime(2026, 11, 3), 50, category: '🍔 Food'),
        spend(DateTime(2026, 11, 4), 30, category: '🍔 Food'),
        spend(DateTime(2026, 11, 5), 500000, currency: 'KRW', category: '✈️ Travel'),
      ]);
      final change = ofType(r, InsightType.spendingVsLastMonth)!;
      expect(change.args['percent'], 30); // 130 vs 100 USD
      expect(change.currency, 'USD');
      expect(change.currencyScoped, isTrue);
      final top = ofType(r, InsightType.topCategory)!;
      expect(top.category, '🍔 Food'); // KRW travel ignored
      expect(top.currency, 'USD');
    });

    test('falls back to the most-used currency when the selected one has no spending', () {
      final r = run([
        spend(DateTime(2026, 10, 2), 1000, currency: 'KRW'),
        spend(DateTime(2026, 11, 2), 2000, currency: 'KRW'),
      ]);
      final change = ofType(r, InsightType.spendingVsLastMonth)!;
      expect(change.currency, 'KRW');
      expect(change.currencyScoped, isFalse);
    });

    test('budget is skipped when this month has spending in another currency', () {
      final r = run([
        spend(DateTime(2026, 11, 2), 100),
        spend(DateTime(2026, 11, 3), 5000, currency: 'KRW'),
      ], budget: 500);
      expect(ofType(r, InsightType.budgetUsage), isNull);
    });
  });

  group('text', () {
    test('every insight key exists in all 5 languages and fills its placeholders', () {
      final samples = [
        ...run([
          spend(DateTime(2026, 10, 2), 200),
          spend(DateTime(2026, 11, 2), 300, category: '☕ Coffee'),
          spend(DateTime(2026, 11, 3), 10, category: '🍔 Food'),
          spend(DateTime(2026, 11, 4), 10, category: '🍔 Food'),
        ], budget: 100, recurring: [monthly(20), monthly(21)]),
        ...run([
          spend(DateTime(2026, 10, 2), 200),
          spend(DateTime(2026, 11, 18), 100),
        ], budget: 1000, recurring: [monthly(20)]),
        ...run([spend(DateTime(2026, 11, 18), 1), spend(DateTime(2026, 11, 17), 1), spend(DateTime(2026, 11, 16), 1)]),
        ...run([spend(DateTime(2026, 10, 2), 100), spend(DateTime(2026, 11, 2), 101)]),
        ...run([]),
      ];
      final keys = samples.map((i) => i.localizationKey).toSet();
      expect(keys, containsAll(<String>[
        'insight_spend_up', 'insight_spend_down', 'insight_spend_same', 'insight_top_category',
        'insight_budget_used', 'insight_budget_over', 'insight_recurring_upcoming',
        'insight_recurring_upcoming_one', 'insight_streak', 'insight_week_activity_one',
        'insight_get_started',
      ]));
      for (final lang in ['en', 'ko', 'es', 'zh', 'ja']) {
        for (final i in samples) {
          final text = insightText(i, lang);
          expect(text, isNot(contains('{')), reason: '$lang ${i.localizationKey}: $text');
          expect(text, isNot(startsWith('insight_')), reason: '$lang ${i.localizationKey}');
        }
        for (final k in ['insight_week_activity', 'companion_title', 'companion_locked',
            'companion_choose', 'companion_otter', 'companion_dog', 'companion_cyber']) {
          expect(t(k, lang), isNot(k), reason: '$lang $k');
        }
      }
    });

    test('amounts and categories are localized', () {
      final down = ofType(run([spend(DateTime(2026, 10, 2), 200), spend(DateTime(2026, 11, 2), 114)]),
          InsightType.spendingVsLastMonth)!;
      expect(insightText(down, 'en'), contains(r'$86.00'));
      final top = ofType(
          run([
            spend(DateTime(2026, 11, 1), 50),
            spend(DateTime(2026, 11, 2), 10, category: '🍔 Food'),
            spend(DateTime(2026, 11, 3), 10, category: '🍔 Food'),
          ]),
          InsightType.topCategory)!;
      expect(insightText(top, 'ko'), contains(categoryTextNoEmoji('☕ Coffee', 'ko')));
    });
  });

  group('CompanionController', () {
    Insight ins(String id, int p) => Insight(
        id: id, type: InsightType.recentActivity, priority: p, localizationKey: 'k', generatedAt: now);

    test('starts with the top insight and cycles with next()', () {
      final shown = <String>[];
      final c = CompanionController(onShown: shown.add)..setInsights([ins('a', 3), ins('b', 2), ins('c', 1)]);
      expect(c.current!.id, 'a');
      c.next();
      c.next();
      c.next();
      expect(shown, ['a', 'b', 'c', 'a']);
    });

    test('does not repeat the line shown last time when there is another', () {
      final c = CompanionController(lastShownId: 'a')..setInsights([ins('a', 3), ins('b', 2)]);
      expect(c.current!.id, 'b');
      final only = CompanionController(lastShownId: 'a')..setInsights([ins('a', 3)]);
      expect(only.current!.id, 'a');
    });

    test('keeps the current line when data changes but it is still valid', () {
      final c = CompanionController()..setInsights([ins('a', 3), ins('b', 2)]);
      c.next();
      final before = c.speakCount;
      c.setInsights([ins('x', 9), ins('b', 2)]);
      expect(c.current!.id, 'b');
      expect(c.speakCount, before);
      c.setInsights([ins('x', 9), ins('b', 2)]);
      expect(c.speakCount, before);
    });
  });
}
