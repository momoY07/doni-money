class CurrencySummary {
  final String currency;
  final double income;
  final double expense;

  const CurrencySummary({
    required this.currency,
    required this.income,
    required this.expense,
  });

  double get balance => income - expense;
}
