/// What a companion insight is about. Order has no meaning; see
/// [Insight.priority] for ranking.
enum InsightType {
  spendingVsLastMonth,
  topCategory,
  budgetUsage,
  upcomingRecurring,
  recordStreak,
  recentActivity,
  getStarted,
}

/// A money amount in one currency. Rendered with that currency's format.
class InsightAmount {
  final double value;
  final String currency;
  const InsightAmount(this.value, this.currency);

  @override
  bool operator ==(Object other) =>
      other is InsightAmount && other.value == value && other.currency == currency;

  @override
  int get hashCode => Object.hash(value, currency);

  @override
  String toString() => '$value $currency';
}

/// A stored category value (e.g. "☕ Coffee"). Rendered as the translated
/// category name.
class InsightCategory {
  final String raw;
  const InsightCategory(this.raw);

  @override
  bool operator ==(Object other) => other is InsightCategory && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => raw;
}

/// One factual observation about the user's local data. Contains no
/// sentences: the UI turns [localizationKey] + [args] into text.
///
/// [args] values are `int`, `String`, [InsightAmount] or [InsightCategory];
/// each fills the `{name}` placeholder of the same name.
class Insight {
  /// Stable for the same observation, so the companion can avoid repeating
  /// itself (e.g. `budgetUsage:72`).
  final String id;
  final InsightType type;

  /// Higher shows first.
  final int priority;
  final String localizationKey;
  final Map<String, Object> args;
  final String? category;
  final double? amount;
  final int? percent;

  /// Currency the numbers are in, when the insight is about money.
  final String? currency;

  /// True when this month mixes currencies and the insight covers only
  /// [currency]; the UI then names the currency.
  final bool currencyScoped;
  final DateTime generatedAt;

  const Insight({
    required this.id,
    required this.type,
    required this.priority,
    required this.localizationKey,
    this.args = const {},
    this.category,
    this.amount,
    this.percent,
    this.currency,
    this.currencyScoped = false,
    required this.generatedAt,
  });

  @override
  String toString() => 'Insight($id, $localizationKey, $args)';
}
