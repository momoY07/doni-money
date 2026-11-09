import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:simple_ledger/companion/companion_card.dart';
import 'package:simple_ledger/companion/companion_character.dart';
import 'package:simple_ledger/companion/companion_controller.dart';
import 'package:simple_ledger/companion/companion_prefs.dart';
import 'package:simple_ledger/companion/companion_text.dart';
import 'package:simple_ledger/companion/insight.dart';
import 'package:simple_ledger/companion/money_insight_engine.dart';
import 'package:simple_ledger/utils/currency_utils.dart';
import 'package:simple_ledger/utils/i18n.dart';

// "Now" is Wed 2026-11-18 10:00, so this month = November, last = October.
final now = DateTime(2026, 11, 18, 10);
const engine = MoneyInsightEngine();
const langs = ['en', 'ko', 'es', 'zh', 'ja'];

InsightTransaction spend(DateTime date, double amount,
        {String category = '☕ Coffee', String currency = 'USD'}) =>
    InsightTransaction(
        date: date, isExpense: true, amount: amount, category: category, currency: currency);

InsightTransaction income(DateTime date, double amount, {String currency = 'USD'}) =>
    InsightTransaction(
        date: date, isExpense: false, amount: amount, category: '💰 Salary', currency: currency);

InsightInput input(List<InsightTransaction> tx,
        {double budget = 0, String currency = 'USD', DateTime? at}) =>
    InsightInput(
      now: at ?? now,
      transactions: tx,
      monthlyBudget: budget,
      budgetCurrency: currency,
    );

List<Insight> run(List<InsightTransaction> tx,
        {double budget = 0, String currency = 'USD', DateTime? at}) =>
    engine.generate(input(tx, budget: budget, currency: currency, at: at));

Insight ask(MoneyQuestion q, List<InsightTransaction> tx, {double budget = 0, DateTime? at}) =>
    engine.answer(q, input(tx, budget: budget, at: at));

Insight? ofType(List<Insight> list, InsightType type) {
  for (final i in list) {
    if (i.type == type) return i;
  }
  return null;
}

/// `{name}` placeholders in a template.
Set<String> placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

/// Four previous 7-day periods of 100 each (relative to [now]) plus [recent]
/// in the last 7 days. Periods: p1 = Nov 5–11, p2 = Oct 29–Nov 4,
/// p3 = Oct 22–28, p4 = Oct 15–21.
List<InsightTransaction> weeks({required double recent, String currency = 'USD', int skipWeek = 0}) => [
      if (skipWeek != 1) spend(DateTime(2026, 11, 8), 100, currency: currency),
      if (skipWeek != 2) spend(DateTime(2026, 11, 1), 100, currency: currency),
      if (skipWeek != 3) spend(DateTime(2026, 10, 25), 100, currency: currency),
      if (skipWeek != 4) spend(DateTime(2026, 10, 18), 100, currency: currency),
      if (recent > 0) spend(DateTime(2026, 11, 16), recent, currency: currency),
    ];

void main() {
  // ───────────────────────────── quick questions ─────────────────────────────
  group('quick questions', () {
    test('month status with budget → budget usage', () {
      final a = ask(MoneyQuestion.monthStatus,
          [spend(DateTime(2026, 11, 2), 300), spend(DateTime(2026, 11, 9), 100)],
          budget: 1000);
      expect(a.type, InsightType.budgetUsage);
      expect(a.localizationKey, 'insight_budget_used');
      expect(a.percent, 40);
    });

    test('month status without budget → month-to-date spending', () {
      final a = ask(MoneyQuestion.monthStatus, [
        spend(DateTime(2026, 11, 2), 30.5),
        spend(DateTime(2026, 11, 9), 20),
        spend(DateTime(2026, 10, 9), 999), // last month: not counted
        income(DateTime(2026, 11, 1), 5000), // income: not spending
      ]);
      expect(a.type, InsightType.monthSpending);
      expect(a.localizationKey, 'answer_month_spent');
      expect(a.args['amount'], const InsightAmount(50.5, 'USD'));
    });

    test('month status with no data says so', () {
      final a = ask(MoneyQuestion.monthStatus, const []);
      expect(a.type, InsightType.notEnoughData);
      expect(a.localizationKey, 'answer_month_no_data');
    });

    test('month status with only recent income falls back to recent activity', () {
      final a = ask(MoneyQuestion.monthStatus, [income(DateTime(2026, 11, 17), 100)]);
      expect(a.type, InsightType.recentActivity);
    });

    test('largest category', () {
      final a = ask(MoneyQuestion.topCategory, [
        spend(DateTime(2026, 11, 2), 60, category: '☕ Coffee'),
        spend(DateTime(2026, 11, 3), 20, category: '🍔 Food'),
        spend(DateTime(2026, 11, 4), 20, category: '🍔 Food'),
      ]);
      expect(a.type, InsightType.topCategory);
      expect(a.category, '☕ Coffee');
      expect(a.percent, 60);
    });

    test('insufficient category data says so', () {
      for (final tx in [
        <InsightTransaction>[],
        [spend(DateTime(2026, 11, 2), 60)], // too few entries
        [ // one category only
          spend(DateTime(2026, 11, 2), 1), spend(DateTime(2026, 11, 3), 1), spend(DateTime(2026, 11, 4), 1),
        ],
      ]) {
        final a = ask(MoneyQuestion.topCategory, tx);
        expect(a.type, InsightType.notEnoughData);
        expect(a.localizationKey, 'answer_top_not_enough');
      }
    });

    test('previous-month comparison', () {
      final a = ask(MoneyQuestion.compareLastMonth,
          [spend(DateTime(2026, 10, 5), 100), spend(DateTime(2026, 11, 5), 150)]);
      expect(a.type, InsightType.spendingVsLastMonth);
      expect(a.localizationKey, 'insight_spend_up');
      expect(a.percent, 50);
    });

    test('no previous-month data says so', () {
      final a = ask(MoneyQuestion.compareLastMonth, [spend(DateTime(2026, 11, 5), 150)]);
      expect(a.type, InsightType.notEnoughData);
      expect(a.localizationKey, 'answer_compare_no_previous');
    });

    test('comparison with no spending this month says there is nothing yet', () {
      final a = ask(MoneyQuestion.compareLastMonth, [spend(DateTime(2026, 10, 5), 100)]);
      expect(a.localizationKey, 'answer_month_no_data');
    });

    test('answers use the same numbers as the insights', () {
      final tx = [
        spend(DateTime(2026, 10, 5), 100),
        spend(DateTime(2026, 11, 2), 60, category: '☕ Coffee'),
        spend(DateTime(2026, 11, 3), 20, category: '🍔 Food'),
        spend(DateTime(2026, 11, 4), 30, category: '🍔 Food'),
      ];
      final insights = run(tx);
      expect(ask(MoneyQuestion.topCategory, tx).id,
          ofType(insights, InsightType.topCategory)!.id);
      expect(ask(MoneyQuestion.compareLastMonth, tx).id,
          ofType(insights, InsightType.spendingVsLastMonth)!.id);
    });
  });

  // ─────────────────────────── category comparison ───────────────────────────
  group('category month-over-month', () {
    test('higher → percent', () {
      final i = ofType(run([
        spend(DateTime(2026, 10, 3), 50),
        spend(DateTime(2026, 10, 10), 50),
        spend(DateTime(2026, 10, 5), 100, category: '🍔 Food'),
        spend(DateTime(2026, 11, 2), 70),
        spend(DateTime(2026, 11, 9), 62),
        spend(DateTime(2026, 11, 4), 100, category: '🍔 Food'),
      ]), InsightType.categoryChange)!;
      expect(i.localizationKey, 'insight_category_up');
      expect(i.category, '☕ Coffee');
      expect(i.args['percent'], 32);
      expect(i.mood, InsightMood.neutral);
    });

    test('lower → amount, never a percentage', () {
      final i = ofType(run([
        spend(DateTime(2026, 10, 3), 60, category: '🍽️ Dining'),
        spend(DateTime(2026, 10, 12), 40, category: '🍽️ Dining'),
        spend(DateTime(2026, 11, 6), 52, category: '🍽️ Dining'),
        spend(DateTime(2026, 11, 7), 30),
        spend(DateTime(2026, 10, 7), 30),
      ]), InsightType.categoryChange)!;
      expect(i.localizationKey, 'insight_category_down');
      expect(i.category, '🍽️ Dining');
      expect(i.args['amount'], const InsightAmount(48, 'USD'));
      expect(i.args.containsKey('percent'), isFalse);
    });

    test('roughly the same', () {
      final i = ofType(run([
        spend(DateTime(2026, 10, 3), 50, category: '🚌 Transport'),
        spend(DateTime(2026, 10, 10), 50, category: '🚌 Transport'),
        spend(DateTime(2026, 11, 3), 50, category: '🚌 Transport'),
        spend(DateTime(2026, 11, 10), 52, category: '🚌 Transport'),
        spend(DateTime(2026, 11, 11), 10),
      ]), InsightType.categoryChange)!;
      expect(i.localizationKey, 'insight_category_same');
      expect(i.args.keys, ['category']);
    });

    test('previous value zero: that category is not compared', () {
      final r = run([
        spend(DateTime(2026, 10, 3), 50, category: '🍔 Food'),
        spend(DateTime(2026, 10, 10), 50, category: '🍔 Food'),
        spend(DateTime(2026, 11, 3), 50, category: '🍔 Food'),
        // Coffee is new this month: no "∞%" or any percentage for it.
        spend(DateTime(2026, 11, 4), 30),
        spend(DateTime(2026, 11, 5), 30),
        spend(DateTime(2026, 11, 6), 300),
      ]);
      final i = ofType(r, InsightType.categoryChange)!;
      expect(i.category, '🍔 Food');
      expect(r.where((x) => x.type == InsightType.categoryChange), hasLength(1));
    });

    test('nothing when last month had no comparable spending at all', () {
      final r = run([
        spend(DateTime(2026, 10, 25), 100), // after the 18th
        spend(DateTime(2026, 11, 3), 50),
        spend(DateTime(2026, 11, 4), 50, category: '🍔 Food'),
      ]);
      expect(ofType(r, InsightType.categoryChange), isNull);
    });

    test('tiny categories and too few entries are skipped', () {
      final r = run([
        // Big category, too few entries (2).
        spend(DateTime(2026, 10, 3), 500, category: '🏠 Rent'),
        spend(DateTime(2026, 11, 3), 900, category: '🏠 Rent'),
        // Many entries but < 15% share.
        for (var d = 1; d <= 3; d++) spend(DateTime(2026, 10, d), 5),
        for (var d = 1; d <= 3; d++) spend(DateTime(2026, 11, d), 15),
      ]);
      expect(ofType(r, InsightType.categoryChange), isNull);
    });

    test('multiple currencies are never mixed', () {
      final r = run([
        spend(DateTime(2026, 10, 3), 50),
        spend(DateTime(2026, 10, 10), 50),
        spend(DateTime(2026, 10, 5), 100, category: '🍔 Food'),
        spend(DateTime(2026, 11, 2), 70),
        spend(DateTime(2026, 11, 9), 62),
        spend(DateTime(2026, 11, 4), 100, category: '🍔 Food'),
        // EUR coffee would flip the result if it were added in.
        spend(DateTime(2026, 10, 4), 5000, currency: 'EUR'),
        spend(DateTime(2026, 11, 4), 1, currency: 'EUR'),
      ]);
      final i = ofType(r, InsightType.categoryChange)!;
      expect(i.args['percent'], 32);
      expect(i.currency, 'USD');
      expect(i.currencyScoped, isTrue);
      expect(insightText(i, 'en'), endsWith('(USD)'));
    });

    test('month boundary: January compares with December of the previous year', () {
      final at = DateTime(2027, 1, 20, 9);
      final i = ofType(run([
        spend(DateTime(2026, 12, 3), 50),
        spend(DateTime(2026, 12, 10), 50),
        spend(DateTime(2026, 12, 28), 900), // after the 20th: not comparable
        spend(DateTime(2026, 12, 5), 100, category: '🍔 Food'),
        spend(DateTime(2027, 1, 2), 75),
        spend(DateTime(2027, 1, 9), 75),
        spend(DateTime(2027, 1, 4), 100, category: '🍔 Food'),
      ], at: at), InsightType.categoryChange)!;
      expect(i.args['percent'], 50);
    });

    test('month boundary: end of March compares with all of February', () {
      final at = DateTime(2026, 3, 30, 9);
      final i = ofType(run([
        spend(DateTime(2026, 2, 3), 50),
        spend(DateTime(2026, 2, 28), 50),
        spend(DateTime(2026, 2, 5), 100, category: '🍔 Food'),
        spend(DateTime(2026, 3, 2), 100),
        spend(DateTime(2026, 3, 29), 100),
        spend(DateTime(2026, 3, 4), 100, category: '🍔 Food'),
      ], at: at), InsightType.categoryChange)!;
      expect(i.args['percent'], 100);
    });
  });

  // ───────────────────────────── recent week ─────────────────────────────
  group('recent 7 days vs previous weeks', () {
    test('enough history and clearly higher → reported', () {
      final i = ofType(run(weeks(recent: 180)), InsightType.recentWeekHigher)!;
      expect(i.localizationKey, 'insight_recent_week_higher');
      expect(i.args, {'percent': 80, 'weeks': 4});
      expect(i.mood, InsightMood.attention);
      for (final lang in langs) {
        final text = insightText(i, lang).toLowerCase();
        for (final word in ['unusual', 'abnormal', '이상', 'anormal', 'inusual', '异常', '異常']) {
          expect(text, isNot(contains(word)), reason: '$lang: $text');
        }
      }
    });

    test('normal recent spending → nothing', () {
      expect(ofType(run(weeks(recent: 120)), InsightType.recentWeekHigher), isNull);
      expect(ofType(run(weeks(recent: 90)), InsightType.recentWeekHigher), isNull);
    });

    test('insufficient history → nothing', () {
      // A week without any entries could be missing data, not a quiet week.
      for (var skip = 1; skip <= 4; skip++) {
        expect(ofType(run(weeks(recent: 500, skipWeek: skip)), InsightType.recentWeekHigher), isNull,
            reason: 'missing week $skip');
      }
    });

    test('a quiet week with logged income still counts as history', () {
      final tx = [
        ...weeks(recent: 300, skipWeek: 3),
        income(DateTime(2026, 10, 24), 1000),
      ];
      final i = ofType(run(tx), InsightType.recentWeekHigher)!;
      expect(i.args['percent'], 300); // 300 vs (100+100+0+100)/4 = 75
    });

    test('multiple currencies are never mixed', () {
      final tx = [
        ...weeks(recent: 110), // USD: normal
        spend(DateTime(2026, 11, 17), 50000, currency: 'KRW'),
      ];
      expect(ofType(run(tx), InsightType.recentWeekHigher), isNull);

      final tx2 = [
        ...weeks(recent: 200),
        spend(DateTime(2026, 11, 17), 3, currency: 'KRW'),
      ];
      final i = ofType(run(tx2), InsightType.recentWeekHigher)!;
      expect(i.currency, 'USD');
      expect(i.args['percent'], 100);
      expect(i.currencyScoped, isTrue);
    });

    test('future-dated entries are ignored', () {
      final tx = [...weeks(recent: 100), spend(DateTime(2026, 11, 25), 5000)];
      expect(ofType(run(tx), InsightType.recentWeekHigher), isNull);
    });
  });

  // ──────────────────────────────── tone ────────────────────────────────
  group('personality tone', () {
    List<Insight> samples() => [
          ...run([
            spend(DateTime(2026, 10, 3), 50),
            spend(DateTime(2026, 10, 10), 50),
            spend(DateTime(2026, 10, 5), 100, category: '🍔 Food'),
            spend(DateTime(2026, 11, 2), 70),
            spend(DateTime(2026, 11, 9), 62),
            spend(DateTime(2026, 11, 4), 100, category: '🍔 Food'),
          ], budget: 250),
          ...run(weeks(recent: 180)),
          ...run([spend(DateTime(2026, 10, 2), 200), spend(DateTime(2026, 11, 2), 114)], budget: 100),
          ...run([for (var d = 14; d <= 18; d++) spend(DateTime(2026, 11, d), 1)]),
          ...run([
            spend(DateTime(2026, 10, 3), 60, category: '🍽️ Dining'),
            spend(DateTime(2026, 10, 12), 40, category: '🍽️ Dining'),
            spend(DateTime(2026, 11, 6), 52, category: '🍽️ Dining'),
            spend(DateTime(2026, 11, 7), 30),
            spend(DateTime(2026, 10, 7), 30),
          ]),
          ask(MoneyQuestion.monthStatus, [spend(DateTime(2026, 11, 2), 42)]),
          for (final q in MoneyQuestion.values) ask(q, const []),
          ...run([]),
        ];

    test('facts and numbers are identical for every character', () {
      for (final lang in langs) {
        for (final i in samples()) {
          final facts = <String>[
            for (final v in i.args.values)
              if (v is InsightAmount)
                formatCurrencyValue(v.value, v.currency)
              else if (v is InsightCategory)
                categoryTextNoEmoji(v.raw, lang)
              else
                '$v',
          ];
          for (final c in CompanionCharacter.values) {
            final text = insightText(i, lang, character: c);
            expect(text, isNot(contains('{')), reason: '$lang ${c.id} ${i.localizationKey}: $text');
            for (final f in facts) {
              expect(text, contains(f), reason: '$lang ${c.id} ${i.localizationKey}: $text');
            }
          }
        }
      }
    });

    test('characters sound different', () {
      final i = ofType(run([spend(DateTime(2026, 10, 2), 200), spend(DateTime(2026, 11, 2), 114)]),
          InsightType.spendingVsLastMonth)!;
      final texts = {for (final c in CompanionCharacter.values) insightText(i, 'en', character: c)};
      expect(texts, hasLength(3));
    });

    test('without a character the text is the plain Phase 1 sentence', () {
      final i = ofType(run([spend(DateTime(2026, 10, 2), 100), spend(DateTime(2026, 11, 2), 150)]),
          InsightType.spendingVsLastMonth)!;
      expect(insightText(i, 'en'), "You've spent 50% more than at this point last month.");
    });

    test('no judgmental or advice wording', () {
      const banned = ['should', 'must', 'too much', 'bad', 'warning', 'overspend', 'save more', 'invest'];
      for (final i in samples()) {
        for (final c in CompanionCharacter.values) {
          final text = insightText(i, 'en', character: c).toLowerCase();
          for (final w in banned) {
            expect(text, isNot(contains(w)), reason: '${c.id}: $text');
          }
        }
      }
    });
  });

  // ─────────────────────────── localization ───────────────────────────
  group('localization', () {
    final newKeys = [
      'companion_settings_title', 'companion_settings_desc', 'companion_ask', 'companion_back',
      'question_month_status', 'question_top_category', 'question_compare_last_month',
      'answer_month_spent', 'answer_month_no_data', 'answer_top_not_enough',
      'answer_compare_no_previous', 'insight_category_up', 'insight_category_down',
      'insight_category_same', 'insight_recent_week_higher',
      for (final c in ['otter', 'dog', 'cyber'])
        for (final m in ['neutral', 'positive', 'attention']) 'tone_${c}_$m',
    ];
    const cyberOverridden = [
      'insight_spend_up', 'insight_spend_down', 'insight_spend_same', 'insight_top_category',
      'insight_budget_used', 'insight_budget_over', 'insight_category_up',
      'insight_category_down', 'insight_category_same', 'insight_recent_week_higher',
      'insight_streak', 'answer_month_spent',
    ];

    test('every new key exists in all 5 languages with the same placeholders', () {
      for (final k in [...newKeys, for (final k in cyberOverridden) '${k}_cyber']) {
        final ref = placeholders(t(k, 'en'));
        for (final lang in langs) {
          final v = t(k, lang);
          expect(v, isNot(k), reason: '$lang $k missing');
          expect(placeholders(v), ref, reason: '$lang $k placeholders');
        }
      }
    });

    test('tone wrappers contain {text}; overrides keep the base placeholders', () {
      for (final lang in langs) {
        for (final c in CompanionCharacter.values) {
          for (final m in InsightMood.values) {
            expect(t('tone_${c.id}_${m.name}', lang), contains('{text}'));
          }
        }
        for (final k in cyberOverridden) {
          expect(placeholders(t('${k}_cyber', lang)), placeholders(t(k, lang)), reason: '$lang $k');
        }
      }
    });

    test('quick question labels are localized', () {
      for (final lang in langs) {
        final labels = MoneyQuestion.values.map((q) => t(q.labelKey, lang)).toSet();
        expect(labels, hasLength(3));
        if (lang != 'en') {
          expect(labels.intersection(
              MoneyQuestion.values.map((q) => t(q.labelKey, 'en')).toSet()), isEmpty);
        }
      }
    });
  });

  // ─────────────────────────── controller / UI logic ───────────────────────────
  group('controller with quick questions', () {
    Insight ins(String id) => Insight(
        id: id, type: InsightType.recentActivity, priority: 1, localizationKey: 'k', generatedAt: now);
    final answer = Insight(
        id: 'answer', type: InsightType.monthSpending, priority: 0,
        localizationKey: 'answer_month_spent', generatedAt: now);

    test('a quick question does not corrupt insight cycling', () {
      final shown = <String>[];
      final c = CompanionController(onShown: shown.add)..setInsights([ins('a'), ins('b'), ins('c')]);
      expect(c.current!.id, 'a');

      c.showAnswer(MoneyQuestion.monthStatus, answer);
      expect(c.current!.id, 'answer');
      expect(c.currentInsight!.id, 'a');
      expect(c.showingAnswer, isTrue);
      expect(shown, ['a'], reason: 'answers are not "last shown" insights');

      c.next();
      expect(c.showingAnswer, isFalse);
      expect(c.current!.id, 'b');
      c.next();
      expect(c.current!.id, 'c');
      c.next();
      expect(c.current!.id, 'a');
      expect(shown, ['a', 'b', 'c', 'a']);
    });

    test('dismissing an answer returns to the same insight', () {
      final c = CompanionController()..setInsights([ins('a'), ins('b')]);
      c.next();
      c.showAnswer(MoneyQuestion.topCategory, answer);
      c.dismissAnswer();
      expect(c.current!.id, 'b');
      expect(c.question, isNull);
    });

    test('new data while an answer is open is not recorded as shown', () {
      final shown = <String>[];
      final c = CompanionController(onShown: shown.add)..setInsights([ins('a')]);
      c.showAnswer(MoneyQuestion.monthStatus, answer);
      final spoken = c.speakCount;
      c.setInsights([ins('x'), ins('y')]);
      expect(c.current!.id, 'answer');
      expect(shown, ['a']);
      expect(c.speakCount, spoken);
      c.next();
      expect(shown.last, isNot('answer'));
    });

    test('refreshAnswer replaces the answer only while one is open', () {
      final c = CompanionController()..setInsights([ins('a')]);
      c.refreshAnswer(answer);
      expect(c.current!.id, 'a');
      c.showAnswer(MoneyQuestion.monthStatus, ins('old'));
      final spoken = c.speakCount;
      c.refreshAnswer(answer);
      expect(c.current!.id, 'answer');
      expect(c.speakCount, spoken, reason: 'refresh does not animate');
    });

    test('pose follows the mood', () {
      Insight withMood(InsightMood m) => Insight(
          id: 'm', type: InsightType.recordStreak, priority: 1, localizationKey: 'k',
          generatedAt: now, mood: m);
      expect(poseForInsight(withMood(InsightMood.positive)), CompanionPose.happy);
      expect(poseForInsight(withMood(InsightMood.attention)), CompanionPose.notice);
      expect(poseForInsight(withMood(InsightMood.neutral)), CompanionPose.speaking);
      expect(poseForInsight(null), CompanionPose.speaking);
    });

    test('budget over is never a "happy" line', () {
      final over = ofType(run([spend(DateTime(2026, 11, 2), 300)], budget: 100),
          InsightType.budgetUsage)!;
      expect(over.mood, InsightMood.attention);
      expect(poseForInsight(over), isNot(CompanionPose.happy));
    });
  });

  group('companion preference', () {
    late Directory tmp;
    late Box box;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('companion_prefs');
      Hive.init(tmp.path);
      box = await Hive.openBox('companion_prefs_test');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await tmp.delete(recursive: true);
    });

    test('no choice follows the theme', () {
      final p = CompanionPrefs(box);
      expect(p.explicitChoice, isNull);
      expect(p.effective('cream'), CompanionCharacter.otter);
      expect(p.effective('dog_dark'), CompanionCharacter.dog);
      expect(p.effective('cyber_ai'), CompanionCharacter.cyber);
    });

    test('selection persists', () async {
      await CompanionPrefs(box).setChoice(CompanionCharacter.cyber);
      await box.close();
      box = await Hive.openBox('companion_prefs_test');
      expect(CompanionPrefs(box).explicitChoice, CompanionCharacter.cyber);
    });

    test('theme change does not overwrite an explicit choice', () async {
      final p = CompanionPrefs(box);
      await p.setChoice(CompanionCharacter.dog);
      for (final theme in ['cream', 'otter_dark', 'cyber_ai', 'minimal_black', 'dog']) {
        expect(p.effective(theme), CompanionCharacter.dog, reason: theme);
      }
      expect(box.get(CompanionCharacter.storageKey), 'dog');
    });

    test('an unknown stored value falls back to the theme', () async {
      await box.put(CompanionCharacter.storageKey, 'dragon');
      expect(CompanionPrefs(box).explicitChoice, isNull);
      expect(CompanionPrefs(box).effective('dog'), CompanionCharacter.dog);
      await box.put(CompanionCharacter.storageKey, 7);
      expect(CompanionPrefs(box).effective('cream'), CompanionCharacter.otter);
    });

    test('last shown insight id persists', () async {
      final p = CompanionPrefs(box);
      expect(p.lastShownId, isNull);
      await p.setLastShownId('streak:4');
      expect(CompanionPrefs(box).lastShownId, 'streak:4');
    });
  });
}
