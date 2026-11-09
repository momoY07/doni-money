import 'dart:math' as math;

import 'insight.dart';

/// A transaction as the engine sees it: the currency is already resolved
/// (legacy rows without a currency use the app's selected currency).
class InsightTransaction {
  final DateTime date;
  final bool isExpense;
  final double amount;
  final String category;
  final String currency;

  const InsightTransaction({
    required this.date,
    required this.isExpense,
    required this.amount,
    required this.category,
    required this.currency,
  });
}

class InsightRecurring {
  final bool isActive;
  final bool isExpense;
  final double amount;
  final String category;
  final String currency;

  /// 'monthly' or 'weekly'.
  final String frequency;
  final int dayOfMonth;

  /// 1 = Monday … 7 = Sunday.
  final int dayOfWeek;

  const InsightRecurring({
    required this.isActive,
    required this.isExpense,
    required this.amount,
    required this.category,
    required this.currency,
    required this.frequency,
    required this.dayOfMonth,
    required this.dayOfWeek,
  });
}

/// Everything the engine needs, already normalized. No storage, no UI.
class InsightInput {
  final DateTime now;
  final List<InsightTransaction> transactions;
  final List<InsightRecurring> recurring;

  /// 0 = no budget. The budget is in [budgetCurrency].
  final double monthlyBudget;

  /// The app's selected currency: the budget's currency and the preferred
  /// currency for comparisons.
  final String budgetCurrency;

  const InsightInput({
    required this.now,
    required this.transactions,
    this.recurring = const [],
    this.monthlyBudget = 0,
    required this.budgetCurrency,
  });
}

/// Turns local Doni Money data into short factual observations.
///
/// Rules:
/// * Amounts in different currencies are never added together. Money
///   insights use one currency: the selected currency if this month has
///   spending in it, otherwise the currency with the most spending entries.
/// * Nothing is reported when the data can't support it (e.g. no
///   month-over-month change when last month had no comparable spending).
/// * Entries dated after [InsightInput.now] are ignored.
class MoneyInsightEngine {
  const MoneyInsightEngine();

  // Priorities (higher shows first).
  static const int pBudgetOver = 90;
  static const int pBudgetHigh = 80;
  static const int pUpcomingRecurring = 70;
  static const int pRecentWeekHigher = 65;
  static const int pSpendingChange = 60;
  static const int pCategoryChange = 55;
  static const int pTopCategory = 50;
  static const int pBudgetNormal = 40;
  static const int pStreak = 30;
  static const int pActivity = 20;
  static const int pGetStarted = 10;

  /// Budget usage at or above this percent is shown with high priority.
  static const int budgetHighPercent = 80;

  /// Month-over-month changes smaller than this are reported as "about the
  /// same".
  static const int sameSpendingPercent = 5;

  /// Top category needs at least this many spending entries this month.
  static const int topCategoryMinEntries = 3;

  /// A streak is reported from this many consecutive days.
  static const int minStreakDays = 3;

  static const int upcomingWindowDays = 7;

  /// Category changes smaller than this are "about the same" (categories
  /// vary more than totals, so the band is wider).
  static const int sameCategoryPercent = 10;

  /// A category must hold at least this share of the month's spending (this
  /// month or the same days of last month) to be compared.
  static const int categoryMinSharePercent = 15;

  /// Entries in that category across both periods.
  static const int categoryMinEntries = 3;

  /// Completed 7-day periods required before the recent week is compared.
  static const int recentWeekHistoryWeeks = 4;

  /// The last 7 days must be at least this much above the previous weeks'
  /// average to be mentioned. Smaller differences are normal variation.
  static const int recentWeekMinIncreasePercent = 30;

  List<Insight> generate(InsightInput input) {
    final c = _Ctx(input);
    final now = c.now;

    final out = <Insight>[
      ?_spendingChange(c),
      ?_categoryChange(c),
      ?_topCategory(c),
      ?_budget(c),
      ?_upcomingRecurring(input.recurring, c.today, now),
      ?_recentWeekHigher(c),
      ..._activity(c.past, c.today, now),
    ];

    if (out.isEmpty) {
      out.add(Insight(
        id: 'getStarted',
        type: InsightType.getStarted,
        priority: pGetStarted,
        localizationKey: 'insight_get_started',
        generatedAt: now,
      ));
    }

    out.sort((a, b) => b.priority.compareTo(a.priority));
    return out;
  }

  // ─────────────────────────── insights ───────────────────────────

  /// This month so far vs the same days of last month, in one currency.
  Insight? _spendingChange(_Ctx c) {
    final focus = c.focus;
    if (focus == null) return null;
    final now = c.now;
    final scoped = c.scoped;

    double current = 0, previous = 0;
    for (final t in c.past) {
      if (!t.isExpense || t.currency != focus) continue;
      if (c.inThisMonth(t)) {
        current += t.amount;
      } else if (c.inComparablePrevious(t)) {
        previous += t.amount;
      }
    }
    // No comparable spending last month (or none yet this month): say nothing.
    if (previous <= 0 || current <= 0) return null;

    final change = ((current - previous) / previous * 100).round();
    if (change.abs() < sameSpendingPercent) {
      return Insight(
        id: 'spendingChange:same:$focus',
        type: InsightType.spendingVsLastMonth,
        priority: pSpendingChange,
        localizationKey: 'insight_spend_same',
        currency: focus,
        currencyScoped: scoped,
        percent: change,
        generatedAt: now,
      );
    }
    if (change > 0) {
      return Insight(
        id: 'spendingChange:up:$change:$focus',
        type: InsightType.spendingVsLastMonth,
        priority: pSpendingChange,
        localizationKey: 'insight_spend_up',
        args: {'percent': change},
        percent: change,
        currency: focus,
        currencyScoped: scoped,
        generatedAt: now,
      );
    }
    final less = _round2(previous - current);
    return Insight(
      id: 'spendingChange:down:$less:$focus',
      type: InsightType.spendingVsLastMonth,
      priority: pSpendingChange,
      localizationKey: 'insight_spend_down',
      mood: InsightMood.positive,
      args: {'amount': InsightAmount(less, focus)},
      amount: less,
      percent: change,
      currency: focus,
      currencyScoped: scoped,
      generatedAt: now,
    );
  }

  Insight? _topCategory(_Ctx c) {
    final focus = c.focus;
    if (focus == null) return null;
    final now = c.now;
    final scoped = c.scoped;
    final inFocus = c.monthExpenses.where((t) => t.currency == focus).toList();
    if (inFocus.length < topCategoryMinEntries) return null;

    final totals = <String, double>{};
    for (final t in inFocus) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    // A single category isn't a "biggest" category.
    if (totals.length < 2) return null;
    final total = totals.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return null;

    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
      });
    final top = sorted.first;
    // A tie for first place has no single biggest category.
    if (sorted[1].value == top.value) return null;

    final share = (top.value / total * 100).round();
    return Insight(
      id: 'topCategory:${top.key}:$share:$focus',
      type: InsightType.topCategory,
      priority: pTopCategory,
      localizationKey: 'insight_top_category',
      args: {'category': InsightCategory(top.key), 'percent': share},
      category: top.key,
      amount: _round2(top.value),
      percent: share,
      currency: focus,
      currencyScoped: scoped,
      generatedAt: now,
    );
  }

  /// The budget is in the selected currency. Like the Home budget bar, it is
  /// only evaluated when this month's spending is all in that currency.
  Insight? _budget(_Ctx c) {
    final input = c.input;
    final now = c.now;
    final monthExpenses = c.monthExpenses;
    final monthCurrencies = c.monthCurrencies;
    final budget = input.monthlyBudget;
    if (budget <= 0) return null;
    final currency = input.budgetCurrency;
    if (monthCurrencies.any((c) => c != currency)) return null;

    final spent = monthExpenses.fold(0.0, (s, t) => s + t.amount);
    if (spent > budget) {
      final over = _round2(spent - budget);
      return Insight(
        id: 'budget:over:$over:$currency',
        type: InsightType.budgetUsage,
        priority: pBudgetOver,
        localizationKey: 'insight_budget_over',
        mood: InsightMood.attention,
        args: {'amount': InsightAmount(over, currency)},
        amount: over,
        percent: (spent / budget * 100).round(),
        currency: currency,
        generatedAt: now,
      );
    }
    if (spent <= 0) return null;
    final percent = (spent / budget * 100).round();
    return Insight(
      id: 'budget:used:$percent:$currency',
      type: InsightType.budgetUsage,
      priority: percent >= budgetHighPercent ? pBudgetHigh : pBudgetNormal,
      localizationKey: 'insight_budget_used',
      mood: percent >= budgetHighPercent ? InsightMood.attention : InsightMood.neutral,
      args: {'percent': percent},
      percent: percent,
      amount: _round2(spent),
      currency: currency,
      generatedAt: now,
    );
  }

  /// Recurring entries are added when the app opens on/after their day, so
  /// "upcoming" means due after today and within [upcomingWindowDays].
  Insight? _upcomingRecurring(
      List<InsightRecurring> recurring, DateTime today, DateTime now) {
    final last = today.add(const Duration(days: upcomingWindowDays));
    var count = 0;
    for (final r in recurring) {
      if (!r.isActive) continue;
      final next = nextOccurrenceAfter(r, today);
      if (next != null && !next.isAfter(last)) count++;
    }
    if (count == 0) return null;
    return Insight(
      id: 'recurring:$count',
      type: InsightType.upcomingRecurring,
      priority: pUpcomingRecurring,
      localizationKey:
          count == 1 ? 'insight_recurring_upcoming_one' : 'insight_recurring_upcoming',
      mood: InsightMood.attention,
      args: {'count': count, 'days': upcomingWindowDays},
      generatedAt: now,
    );
  }

  /// Logging streak (any entry counts), or recent activity when there is no
  /// streak. Never both.
  List<Insight> _activity(List<InsightTransaction> past, DateTime today, DateTime now) {
    if (past.isEmpty) return const [];
    final days = past.map((t) => _day(t.date)).toSet();

    // A streak may end today or yesterday (today isn't over yet).
    var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = _day(cursor.subtract(const Duration(days: 1)));
    }
    if (streak >= minStreakDays) {
      return [
        Insight(
          id: 'streak:$streak',
          type: InsightType.recordStreak,
          priority: pStreak,
          localizationKey: 'insight_streak',
          mood: InsightMood.positive,
          args: {'days': streak},
          generatedAt: now,
        ),
      ];
    }

    final weekStart = today.subtract(const Duration(days: 6));
    final count = past.where((t) => !_day(t.date).isBefore(weekStart)).length;
    if (count == 0) return const [];
    return [
      Insight(
        id: 'activity:$count',
        type: InsightType.recentActivity,
        priority: pActivity,
        localizationKey: count == 1 ? 'insight_week_activity_one' : 'insight_week_activity',
        args: {'count': count},
        generatedAt: now,
      ),
    ];
  }


  /// One category, this month so far vs the same days of last month, in the
  /// focus currency. Only categories with meaningful spending in both
  /// periods are compared, and only the clearest change is reported.
  Insight? _categoryChange(_Ctx c) {
    final focus = c.focus;
    if (focus == null) return null;

    final cur = <String, double>{}, prev = <String, double>{};
    final entries = <String, int>{};
    double curTotal = 0, prevTotal = 0;
    for (final t in c.past) {
      if (!t.isExpense || t.currency != focus) continue;
      if (c.inThisMonth(t)) {
        cur[t.category] = (cur[t.category] ?? 0) + t.amount;
        curTotal += t.amount;
      } else if (c.inComparablePrevious(t)) {
        prev[t.category] = (prev[t.category] ?? 0) + t.amount;
        prevTotal += t.amount;
      } else {
        continue;
      }
      entries[t.category] = (entries[t.category] ?? 0) + 1;
    }
    // With a single category this would just repeat the total comparison.
    if (cur.length < 2 || curTotal <= 0 || prevTotal <= 0) return null;

    String? best;
    double bestDelta = 0;
    for (final cat in cur.keys) {
      final now = cur[cat]!, before = prev[cat] ?? 0;
      // No percentage against zero, and nothing to compare without both.
      if (before <= 0 || now <= 0) continue;
      if ((entries[cat] ?? 0) < categoryMinEntries) continue;
      final share = math.max(now / curTotal, before / prevTotal) * 100;
      if (share < categoryMinSharePercent) continue;
      final delta = ((now - before) / before).abs();
      if (best == null ||
          delta > bestDelta ||
          (delta == bestDelta && cat.compareTo(best) < 0)) {
        best = cat;
        bestDelta = delta;
      }
    }
    if (best == null) return null;

    final now = cur[best]!, before = prev[best]!;
    final change = ((now - before) / before * 100).round();
    final category = InsightCategory(best);
    Insight make(String key, String tag, Map<String, Object> args, InsightMood mood,
            {double? amount}) =>
        Insight(
          id: 'categoryChange:$tag:$best:$focus',
          type: InsightType.categoryChange,
          priority: pCategoryChange,
          localizationKey: key,
          args: {'category': category, ...args},
          category: best,
          amount: amount,
          percent: change,
          currency: focus,
          currencyScoped: c.scoped,
          mood: mood,
          generatedAt: c.now,
        );

    if (change.abs() < sameCategoryPercent) {
      return make('insight_category_same', 'same', const {}, InsightMood.neutral);
    }
    if (change > 0) {
      return make('insight_category_up', 'up:$change', {'percent': change}, InsightMood.neutral);
    }
    final less = _round2(before - now);
    return make('insight_category_down', 'down:$less',
        {'amount': InsightAmount(less, focus)}, InsightMood.positive,
        amount: less);
  }

  /// The last 7 days vs the previous [recentWeekHistoryWeeks] 7-day periods.
  /// Only reported when every one of those periods has logged entries (so a
  /// quiet week is real data, not a gap) and the increase is clear.
  Insight? _recentWeekHigher(_Ctx c) {
    final today = c.today;
    DateTime dayOffset(int n) => DateTime(today.year, today.month, today.day - n);
    final windowStart = dayOffset(7 * (recentWeekHistoryWeeks + 1) - 1);

    final window = c.past.where((t) => !_day(t.date).isBefore(windowStart)).toList();
    final windowExpenses = window.where((t) => t.isExpense).toList();
    final focus = _focusCurrency(windowExpenses, c.input.budgetCurrency);
    if (focus == null) return null;
    final scoped = windowExpenses.any((t) => t.currency != focus);

    /// Period 0 = last 7 days (today included); 1… = earlier 7-day periods.
    int period(InsightTransaction t) => _daysBetween(_day(t.date), today) ~/ 7;

    final sums = List<double>.filled(recentWeekHistoryWeeks + 1, 0);
    final logged = List<bool>.filled(recentWeekHistoryWeeks + 1, false);
    for (final t in window) {
      final p = period(t);
      if (p < 0 || p > recentWeekHistoryWeeks) continue;
      logged[p] = true;
      if (t.isExpense && t.currency == focus) sums[p] += t.amount;
    }
    for (var p = 1; p <= recentWeekHistoryWeeks; p++) {
      if (!logged[p]) return null;
    }
    final average =
        sums.sublist(1).fold(0.0, (a, b) => a + b) / recentWeekHistoryWeeks;
    final recent = sums[0];
    if (average <= 0 || recent <= 0) return null;
    final increase = ((recent - average) / average * 100).round();
    if (increase < recentWeekMinIncreasePercent) return null;

    return Insight(
      id: 'recentWeekHigher:$increase:$focus',
      type: InsightType.recentWeekHigher,
      priority: pRecentWeekHigher,
      localizationKey: 'insight_recent_week_higher',
      args: {'percent': increase, 'weeks': recentWeekHistoryWeeks},
      percent: increase,
      amount: _round2(recent),
      currency: focus,
      currencyScoped: scoped,
      mood: InsightMood.attention,
      generatedAt: c.now,
    );
  }

  // ─────────────────────────── quick questions ───────────────────────────

  /// Answer to one of the fixed quick questions, from the same calculations
  /// as [generate]. Always returns something: when the data can't answer,
  /// the result says so (type [InsightType.notEnoughData]).
  Insight answer(MoneyQuestion question, InsightInput input) {
    final c = _Ctx(input);
    final Insight? found;
    switch (question) {
      case MoneyQuestion.monthStatus:
        found = _budget(c) ?? _monthSpending(c) ?? _activity(c.past, c.today, c.now).firstOrNull;
        if (found == null) return _notEnough(c, 'answer_month_no_data');
      case MoneyQuestion.topCategory:
        found = _topCategory(c);
        if (found == null) return _notEnough(c, 'answer_top_not_enough');
      case MoneyQuestion.compareLastMonth:
        found = _spendingChange(c);
        if (found == null) {
          return _notEnough(
              c, c.focus == null ? 'answer_month_no_data' : 'answer_compare_no_previous');
        }
    }
    return found;
  }

  /// Month-to-date spending in the focus currency.
  Insight? _monthSpending(_Ctx c) {
    final focus = c.focus;
    if (focus == null) return null;
    final total = _round2(c.monthExpenses
        .where((t) => t.currency == focus)
        .fold(0.0, (s, t) => s + t.amount));
    if (total <= 0) return null;
    return Insight(
      id: 'monthSpending:$total:$focus',
      type: InsightType.monthSpending,
      priority: 0,
      localizationKey: 'answer_month_spent',
      args: {'amount': InsightAmount(total, focus)},
      amount: total,
      currency: focus,
      currencyScoped: c.scoped,
      generatedAt: c.now,
    );
  }

  Insight _notEnough(_Ctx c, String key) => Insight(
        id: 'notEnough:$key',
        type: InsightType.notEnoughData,
        priority: 0,
        localizationKey: key,
        generatedAt: c.now,
      );

  // ─────────────────────────── helpers ───────────────────────────

  /// Whole calendar days from [a] to [b] (both local midnights); DST-safe.
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// Next due date strictly after [today], or null if it can't be computed.
  static DateTime? nextOccurrenceAfter(InsightRecurring r, DateTime today) {
    if (r.frequency == 'weekly') {
      if (r.dayOfWeek < 1 || r.dayOfWeek > 7) return null;
      var delta = (r.dayOfWeek - today.weekday) % 7;
      if (delta == 0) delta = 7;
      return today.add(Duration(days: delta));
    }
    if (r.dayOfMonth < 1 || r.dayOfMonth > 31) return null;
    DateTime candidate(int year, int month) {
      final lastDay = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, math.min(r.dayOfMonth, lastDay));
    }

    final thisMonth = candidate(today.year, today.month);
    if (thisMonth.isAfter(today)) return thisMonth;
    return candidate(today.year, today.month + 1);
  }

  static String? _focusCurrency(List<InsightTransaction> monthExpenses, String preferred) {
    if (monthExpenses.isEmpty) return null;
    if (monthExpenses.any((t) => t.currency == preferred)) return preferred;
    final counts = <String, int>{};
    for (final t in monthExpenses) {
      counts[t.currency] = (counts[t.currency] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return sorted.first.key;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}

/// Values every insight shares, computed once per call.
class _Ctx {
  _Ctx(this.input)
      : now = input.now,
        today = MoneyInsightEngine._day(input.now) {
    past = input.transactions.where((t) => !t.date.isAfter(now)).toList();
    monthExpenses = past.where((t) => t.isExpense && inThisMonth(t)).toList();
    monthCurrencies = monthExpenses.map((t) => t.currency).toSet();
    focus = MoneyInsightEngine._focusCurrency(monthExpenses, input.budgetCurrency);
    final prev = DateTime(now.year, now.month - 1, 1);
    _prevYear = prev.year;
    _prevMonth = prev.month;
    _cutoffDay = math.min(now.day, DateTime(prev.year, prev.month + 1, 0).day);
  }

  final InsightInput input;
  final DateTime now;
  final DateTime today;
  late final List<InsightTransaction> past;
  late final List<InsightTransaction> monthExpenses;
  late final Set<String> monthCurrencies;

  /// Currency money insights use this month (null = no spending yet).
  late final String? focus;
  late final int _prevYear, _prevMonth, _cutoffDay;

  /// True when this month mixes currencies.
  bool get scoped => monthCurrencies.length > 1;

  bool inThisMonth(InsightTransaction t) =>
      t.date.year == now.year && t.date.month == now.month;

  /// Last month, up to the same day of the month (clamped to its length).
  bool inComparablePrevious(InsightTransaction t) =>
      t.date.year == _prevYear && t.date.month == _prevMonth && t.date.day <= _cutoffDay;
}
