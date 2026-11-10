import 'dart:convert';
import 'dart:math' as math;

import '../companion/insight.dart';
import '../companion/money_insight_engine.dart';
import '../utils/i18n.dart';

/// Which part of the user's data a question is about. Decides which context
/// sections are built, so each request carries only what it needs.
enum AiTopic { overview, budget, categories, comparison, week, recurring }

/// Context section names. They are also the values the backend may echo in
/// `usedContext`, and the server accepts exactly these keys.
abstract final class AiContextSection {
  static const month = 'month';
  static const previousMonth = 'previousMonth';
  static const budget = 'budget';
  static const categories = 'categories';
  static const recentWeek = 'recentWeek';
  static const recurring = 'recurring';
  static const otherCurrencies = 'otherCurrencies';
  static const insights = 'insights';

  static const all = {
    month, previousMonth, budget, categories, recentWeek, recurring, otherCurrencies, insights,
  };
}

/// The sanitized, aggregated summary sent with one AI question.
///
/// Built only by [AiFinancialContextBuilder]. Contains no transaction ids,
/// notes, exact timestamps, payment methods, Hive keys, Premium/developer
/// state, passcode or device/account identifiers, and never a list of
/// individual transactions. Custom category names are replaced with
/// "Custom category N".
class AiFinancialContext {
  const AiFinancialContext._(this.topic, this.json);

  final AiTopic topic;

  /// JSON-ready map: only strings, numbers, bools, lists and maps.
  final Map<String, Object?> json;

  /// Sections present (for transparency in "What is shared?").
  Set<String> get sections => json.keys.where(AiContextSection.all.contains).toSet();

  String encode() => jsonEncode(json);
}

/// Builds [AiFinancialContext] from the same normalized data the local
/// companion uses ([InsightInput]). The user's question only selects a
/// [AiTopic]; it can never add fields, raw records or more history.
class AiFinancialContextBuilder {
  const AiFinancialContextBuilder();

  /// Upper bound on categories sent (the rest are combined).
  static const maxCategories = 5;
  static const maxOtherCurrencies = 4;
  static const maxInsights = 4;

  /// Built-in category names (the part after the emoji). Anything else is
  /// a user-created category and is never sent verbatim.
  static const builtInCategoryNames = {
    'Food', 'Coffee', 'Grocery', 'Transport', 'Shopping', 'Bills', 'Entertainment',
    'Health', 'Gift', 'Travel', 'Phone', 'Car', 'Home', 'Rent', 'Baby', 'Electricity',
    'Water', 'Gas', 'Maintenance', 'Internet', 'Investment', 'Other', 'Salary',
  };

  static bool isBuiltInCategory(String raw) => builtInCategoryNames.contains(_nameOf(raw));

  AiFinancialContext build({
    required InsightInput input,
    required AiTopic topic,
    required String language,
  }) {
    final now = input.now;
    final today = DateTime(now.year, now.month, now.day);
    final past = input.transactions.where((t) => !t.date.isAfter(now)).toList();
    final labels = _CategoryLabels(language);

    bool inMonth(InsightTransaction t, int y, int m) => t.date.year == y && t.date.month == m;
    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevDays = DateTime(prevStart.year, prevStart.month + 1, 0).day;
    final cutoff = math.min(now.day, prevDays);
    bool inPrevSamePoint(InsightTransaction t) =>
        inMonth(t, prevStart.year, prevStart.month) && t.date.day <= cutoff;

    // Focus currency: same rule as the local companion.
    final monthExpenses = past.where((t) => t.isExpense && inMonth(t, now.year, now.month));
    final monthAll = past.where((t) => inMonth(t, now.year, now.month)).toList();
    final currency = _focusCurrency(monthAll, input.budgetCurrency);

    final json = <String, Object?>{
      'currency': currency,
      AiContextSection.month: {
        'period': _period(now.year, now.month),
        'dayOfMonth': now.day,
        'daysInMonth': DateTime(now.year, now.month + 1, 0).day,
        'income': _sum(monthAll.where((t) => !t.isExpense && t.currency == currency)),
        'expense': _sum(monthExpenses.where((t) => t.currency == currency)),
        'entryCount': monthAll.where((t) => t.currency == currency).length,
      },
    };

    final wantsAll = topic == AiTopic.overview;

    if (wantsAll || topic == AiTopic.comparison) {
      final prev = past.where((t) => t.currency == currency && inPrevSamePoint(t));
      final prevExpense = _sum(prev.where((t) => t.isExpense));
      final curExpense = (json[AiContextSection.month] as Map)['expense'] as double;
      json[AiContextSection.previousMonth] = {
        'period': _period(prevStart.year, prevStart.month),
        'throughDay': cutoff,
        'expenseSamePoint': prevExpense,
        'incomeSamePoint': _sum(prev.where((t) => !t.isExpense)),
        'expenseChangePercent': prevExpense > 0 && curExpense > 0
            ? ((curExpense - prevExpense) / prevExpense * 100).round()
            : null,
      };
    }

    if (wantsAll || topic == AiTopic.budget) {
      final budget = _budget(input, monthExpenses.toList());
      if (budget != null) json[AiContextSection.budget] = budget;
    }

    if (wantsAll || topic == AiTopic.categories || topic == AiTopic.comparison) {
      json[AiContextSection.categories] = _categories(
        past.where((t) => t.isExpense && t.currency == currency).toList(),
        inThisMonth: (t) => inMonth(t, now.year, now.month),
        inPrevious: inPrevSamePoint,
        labels: labels,
        withPrevious: topic != AiTopic.categories,
        limit: wantsAll ? 3 : maxCategories,
      );
    }

    if (wantsAll || topic == AiTopic.week) {
      json[AiContextSection.recentWeek] = _recentWeek(past, today, currency);
    }

    if (wantsAll || topic == AiTopic.week || topic == AiTopic.recurring) {
      json[AiContextSection.recurring] = _recurring(input.recurring, today, currency);
    }

    final others = _otherCurrencies(monthAll, currency);
    if (others.isNotEmpty) json[AiContextSection.otherCurrencies] = others;

    final insights = _insights(input, labels);
    if (insights.isNotEmpty) json[AiContextSection.insights] = insights;

    return AiFinancialContext._(topic, json);
  }

  // ───────────────────────────── sections ─────────────────────────────

  Map<String, Object?>? _budget(InsightInput input, List<InsightTransaction> monthExpenses) {
    final amount = input.monthlyBudget;
    if (amount <= 0) return null;
    // Same rule as Home: only when this month's spending is all in the
    // budget's currency.
    if (monthExpenses.any((t) => t.currency != input.budgetCurrency)) return null;
    final spent = _sum(monthExpenses);
    return {
      'currency': input.budgetCurrency,
      'amount': _r(amount),
      'spent': spent,
      'remaining': _r(amount - spent),
      'usedPercent': (spent / amount * 100).round(),
    };
  }

  List<Map<String, Object?>> _categories(
    List<InsightTransaction> expenses, {
    required bool Function(InsightTransaction) inThisMonth,
    required bool Function(InsightTransaction) inPrevious,
    required _CategoryLabels labels,
    required bool withPrevious,
    required int limit,
  }) {
    final cur = <String, double>{}, prev = <String, double>{};
    for (final t in expenses) {
      if (inThisMonth(t)) {
        cur[t.category] = (cur[t.category] ?? 0) + t.amount;
      } else if (inPrevious(t)) {
        prev[t.category] = (prev[t.category] ?? 0) + t.amount;
      }
    }
    final total = cur.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const [];
    final sorted = cur.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });

    final out = <Map<String, Object?>>[];
    for (final e in sorted.take(limit)) {
      final before = prev[e.key] ?? 0;
      out.add({
        'name': labels.label(e.key),
        'custom': !isBuiltInCategory(e.key),
        'expense': _r(e.value),
        'sharePercent': (e.value / total * 100).round(),
        if (withPrevious) 'previousSamePoint': _r(before),
        if (withPrevious)
          'changePercent': before > 0 ? ((e.value - before) / before * 100).round() : null,
      });
    }
    if (sorted.length > limit) {
      final rest = sorted.skip(limit).fold(0.0, (s, e) => s + e.value);
      out.add({
        'name': labels.combinedLabel,
        'custom': false,
        'expense': _r(rest),
        'sharePercent': (rest / total * 100).round(),
      });
    }
    return out;
  }

  Map<String, Object?> _recentWeek(List<InsightTransaction> past, DateTime today, String currency) {
    final weeks = MoneyInsightEngine.recentWeekHistoryWeeks;
    final sums = List<double>.filled(weeks + 1, 0);
    final logged = List<bool>.filled(weeks + 1, false);
    for (final t in past) {
      final d = DateTime.utc(t.date.year, t.date.month, t.date.day);
      final days = DateTime.utc(today.year, today.month, today.day).difference(d).inDays;
      if (days < 0) continue;
      final p = days ~/ 7;
      if (p > weeks) continue;
      logged[p] = true;
      if (t.isExpense && t.currency == currency) sums[p] += t.amount;
    }
    final complete = [for (var p = 1; p <= weeks; p++) logged[p]].every((x) => x);
    return {
      'last7DaysExpense': _r(sums[0]),
      'previousWeeks': weeks,
      // Only meaningful when every previous week has logged entries.
      'previousWeeklyAverage':
          complete ? _r(sums.sublist(1).fold(0.0, (a, b) => a + b) / weeks) : null,
    };
  }

  Map<String, Object?> _recurring(
      List<InsightRecurring> recurring, DateTime today, String currency) {
    final last = DateTime(today.year, today.month, today.day + MoneyInsightEngine.upcomingWindowDays);
    var count = 0, otherCurrencyCount = 0;
    double total = 0;
    for (final r in recurring) {
      if (!r.isActive || !r.isExpense) continue;
      final next = MoneyInsightEngine.nextOccurrenceAfter(r, today);
      if (next == null || next.isAfter(last)) continue;
      if (r.currency == currency) {
        count++;
        total += r.amount;
      } else {
        otherCurrencyCount++;
      }
    }
    return {
      'windowDays': MoneyInsightEngine.upcomingWindowDays,
      'upcomingCount': count,
      'upcomingTotal': _r(total),
      if (otherCurrencyCount > 0) 'upcomingInOtherCurrencies': otherCurrencyCount,
    };
  }

  /// Month totals for other currencies, never added to the focus currency.
  List<Map<String, Object?>> _otherCurrencies(List<InsightTransaction> monthAll, String currency) {
    final byCurrency = <String, List<InsightTransaction>>{};
    for (final t in monthAll) {
      if (t.currency == currency) continue;
      byCurrency.putIfAbsent(t.currency, () => []).add(t);
    }
    final keys = byCurrency.keys.toList()..sort();
    return [
      for (final c in keys.take(maxOtherCurrencies))
        {
          'currency': c,
          'income': _sum(byCurrency[c]!.where((t) => !t.isExpense)),
          'expense': _sum(byCurrency[c]!.where((t) => t.isExpense)),
        },
    ];
  }

  /// The local companion's own findings, as structured facts (no sentences,
  /// so no custom category name can slip through).
  List<Map<String, Object?>> _insights(InsightInput input, _CategoryLabels labels) {
    final out = <Map<String, Object?>>[];
    for (final i in const MoneyInsightEngine().generate(input)) {
      if (i.type == InsightType.getStarted) continue;
      out.add({
        'type': i.type.name,
        'mood': i.mood.name,
        if (i.percent != null) 'percent': i.percent,
        if (i.amount != null) 'amount': _r(i.amount!),
        if (i.currency != null) 'currency': i.currency,
        if (i.category != null) 'category': labels.label(i.category!),
        if (i.args['count'] is int) 'count': i.args['count'],
        if (i.args['days'] is int) 'days': i.args['days'],
      });
      if (out.length >= maxInsights) break;
    }
    return out;
  }

  // ───────────────────────────── helpers ─────────────────────────────

  static String _nameOf(String raw) {
    final trimmed = raw.trim();
    final space = trimmed.indexOf(' ');
    return space < 0 ? trimmed : trimmed.substring(space + 1).trim();
  }

  static String _focusCurrency(List<InsightTransaction> month, String preferred) {
    if (month.isEmpty || month.any((t) => t.currency == preferred)) return preferred;
    final counts = <String, int>{};
    for (final t in month) {
      counts[t.currency] = (counts[t.currency] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return sorted.first.key;
  }

  static String _period(int year, int month) {
    final d = DateTime(year, month);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static double _sum(Iterable<InsightTransaction> list) =>
      _r(list.fold(0.0, (s, t) => s + t.amount));

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}

/// Category display names for one request. Built-in categories use the
/// app's translated name; custom ones become "Custom category N" (numbered
/// in order of appearance within this request only).
class _CategoryLabels {
  _CategoryLabels(this.language);

  final String language;
  final _custom = <String, String>{};

  String get combinedLabel => t('ai_category_combined', language);

  String label(String raw) {
    if (AiFinancialContextBuilder.isBuiltInCategory(raw)) {
      return categoryTextNoEmoji(raw, language);
    }
    return _custom.putIfAbsent(
      raw,
      () => t('ai_category_custom', language).replaceAll('{n}', '${_custom.length + 1}'),
    );
  }
}

/// Picks the [AiTopic] for a free-text question with simple keyword
/// matching in the 5 app languages. Unknown questions get [AiTopic.overview]
/// (a small fixed summary), so no wording can request more data.
AiTopic topicForQuestion(String question) {
  final q = question.toLowerCase();
  bool has(List<String> words) => words.any(q.contains);

  if (has(const [
    'budget', 'left', 'remaining', 'presupuesto', 'queda', '예산', '남', '预算', '剩', '予算', '残',
  ])) {
    return AiTopic.budget;
  }
  if (has(const [
    'last month', 'compare', 'compared', 'changed', 'change', 'why', 'higher', 'lower',
    'mes pasado', 'compar', 'cambi', 'por qué', '지난달', '비교', '왜', '달라', '上个月', '上月',
    '比较', '对比', '为什么', '变化', '先月', '比べ', '比較', 'なぜ', '変わ',
  ])) {
    return AiTopic.comparison;
  }
  if (has(const [
    'week', '7 days', 'pay attention', 'attention', 'semana', 'atención', '주', '이번 주',
    '주의', '这周', '本周', '一周', '注意', '今週', '週',
  ])) {
    return AiTopic.week;
  }
  if (has(const [
    'recurring', 'subscription', 'upcoming', 'recurrente', 'suscripci', 'próxim', '반복', '구독',
    '예정', '定期', '订阅', '即将', 'サブスク', '予定',
  ])) {
    return AiTopic.recurring;
  }
  if (has(const [
    'category', 'most', 'biggest', 'spend on', 'spent on', 'categoría', 'más', '카테고리',
    '가장', '많이', '分类', '最多', '类别', 'カテゴリ', '一番', '最も',
  ])) {
    return AiTopic.categories;
  }
  return AiTopic.overview;
}

/// Topic for each fixed quick question.
AiTopic topicForQuickQuestion(MoneyQuestion q) => switch (q) {
      MoneyQuestion.monthStatus => AiTopic.overview,
      MoneyQuestion.topCategory => AiTopic.categories,
      MoneyQuestion.compareLastMonth => AiTopic.comparison,
    };
