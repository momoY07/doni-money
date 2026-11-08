import '../models/recurring_item.dart';
import '../models/tx_item.dart';
import 'money_insight_engine.dart';

/// Builds the engine input from the app's own models. Legacy entries with
/// no currency are treated as the selected currency, like the rest of the
/// app (see `effectiveItemCurrency`).
InsightInput buildInsightInput({
  required List<TxItem> transactions,
  required List<RecurringItem> recurring,
  required double monthlyBudget,
  required String selectedCurrency,
  required DateTime now,
}) {
  String resolve(String c) => c.trim().isEmpty ? selectedCurrency : c.trim();
  return InsightInput(
    now: now,
    budgetCurrency: selectedCurrency,
    monthlyBudget: monthlyBudget,
    transactions: [
      for (final t in transactions)
        InsightTransaction(
          date: t.date,
          isExpense: t.isExpense,
          amount: t.amount,
          category: t.category,
          currency: resolve(t.entryCurrency),
        ),
    ],
    recurring: [
      for (final r in recurring)
        InsightRecurring(
          isActive: r.isActive,
          isExpense: r.isExpense,
          amount: r.amount,
          category: r.category,
          currency: resolve(r.currency),
          frequency: r.frequency,
          dayOfMonth: r.dayOfMonth,
          dayOfWeek: r.dayOfWeek,
        ),
    ],
  );
}
