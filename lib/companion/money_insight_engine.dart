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
  static const int pSpendingChange = 60;
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

  List<Insight> generate(InsightInput input) {
    final now = input.now;
    final today = _day(now);
    final past = input.transactions.where((t) => !t.date.isAfter(now)).toList();

    final monthExpenses = past
        .where((t) => t.isExpense && t.date.year == now.year && t.date.month == now.month)
        .toList();
    final monthCurrencies = monthExpenses.map((t) => t.currency).toSet();
    final focus = _focusCurrency(monthExpenses, input.budgetCurrency);
    final scoped = monthCurrencies.length > 1;

    final out = <Insight>[
      ...[_spendingChange(past, now, focus, scoped)].whereType<Insight>(),
      ...[_topCategory(monthExpenses, now, focus, scoped)].whereType<Insight>(),
      ...[_budget(input, monthExpenses, monthCurrencies, now)].whereType<Insight>(),
      ...[_upcomingRecurring(input.recurring, today, now)].whereType<Insight>(),
      ..._activity(past, today, now),
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
  Insight? _spendingChange(
      List<InsightTransaction> past, DateTime now, String? focus, bool scoped) {
    if (focus == null) return null;
    final prev = DateTime(now.year, now.month - 1, 1);
    final prevDays = DateTime(prev.year, prev.month + 1, 0).day;
    final cutoffDay = math.min(now.day, prevDays);

    double current = 0, previous = 0;
    for (final t in past) {
      if (!t.isExpense || t.currency != focus) continue;
      if (t.date.year == now.year && t.date.month == now.month) {
        current += t.amount;
      } else if (t.date.year == prev.year &&
          t.date.month == prev.month &&
          t.date.day <= cutoffDay) {
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
      args: {'amount': InsightAmount(less, focus)},
      amount: less,
      percent: change,
      currency: focus,
      currencyScoped: scoped,
      generatedAt: now,
    );
  }

  Insight? _topCategory(
      List<InsightTransaction> monthExpenses, DateTime now, String? focus, bool scoped) {
    if (focus == null) return null;
    final inFocus = monthExpenses.where((t) => t.currency == focus).toList();
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
  Insight? _budget(InsightInput input, List<InsightTransaction> monthExpenses,
      Set<String> monthCurrencies, DateTime now) {
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

  // ─────────────────────────── helpers ───────────────────────────

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
