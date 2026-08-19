import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/tx_item.dart';
import '../models/currency_summary.dart';
import 'i18n.dart';

const Map<String, (String, int)> _currencyMeta = {
  'USD': ('\$', 2),
  'KRW': ('₩', 0),
  'EUR': ('€', 2),
  'JPY': ('¥', 0),
  'GBP': ('£', 2),
  'CAD': ('CA\$', 2),
  'AUD': ('A\$', 2),
  'CNY': ('元', 2),
  'HKD': ('HK\$', 2),
  'SGD': ('S\$', 2),
  'MXN': ('MX\$', 2),
  'BRL': ('R\$', 2),
  'THB': ('฿', 2),
  'VND': ('₫', 0),
};

String currencySymbol(String currency) =>
    (_currencyMeta[currency] ?? ('\$', 2)).$1;

String formatCurrencyValue(double amount, String currency) {
  final (sym, decimals) = _currencyMeta[currency] ?? ('\$', 2);
  final pattern = decimals == 0 ? '#,##0' : '#,##0.00';
  final formatter = NumberFormat(pattern, 'en_US');
  return '$sym${formatter.format(amount)}';
}

String effectiveItemCurrency(TxItem item, String fallbackCurrency) {
  final value = item.entryCurrency.trim();
  return value.isEmpty ? fallbackCurrency : value;
}

Set<String> collectItemCurrencies(
  Iterable<TxItem> items, {
  required String fallbackCurrency,
}) {
  final result = <String>{};

  for (final item in items) {
    result.add(effectiveItemCurrency(item, fallbackCurrency));
  }

  return result;
}

Widget buildMixedCurrencyNotice({
  required String language,
  required Set<String> currencies,
}) {
  final sortedCurrencies = currencies.toList()..sort();

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E8),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE6D8AA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF8EDC3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFF9C7A22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('mixed_currency_title', language),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF24364A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('mixed_currency_body', language),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6A5A2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${t('mixed_currency_list', language)}: ${sortedCurrencies.join(', ')}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9C7A22),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

List<CurrencySummary> buildCurrencySummaries(
  Iterable<TxItem> items, {
  required String fallbackCurrency,
}) {
  final incomeMap = <String, double>{};
  final expenseMap = <String, double>{};
  final currencies = <String>{};

  for (final item in items) {
    final currency = effectiveItemCurrency(item, fallbackCurrency);
    currencies.add(currency);

    if (item.isExpense) {
      expenseMap[currency] = (expenseMap[currency] ?? 0.0) + item.amount;
    } else {
      incomeMap[currency] = (incomeMap[currency] ?? 0.0) + item.amount;
    }
  }

  final list = currencies.map((currency) {
    return CurrencySummary(
      currency: currency,
      income: incomeMap[currency] ?? 0.0,
      expense: expenseMap[currency] ?? 0.0,
    );
  }).toList();

  list.sort((a, b) => a.currency.compareTo(b.currency));
  return list;
}

double calculateCumulativeBalance(List<TxItem> allItems, DateTime upToMonth) {
  final cutoff = DateTime(upToMonth.year, upToMonth.month + 1);
  return allItems
      .where((x) => x.date.isBefore(cutoff))
      .fold(0.0, (sum, x) => x.isExpense ? sum - x.amount : sum + x.amount);
}

Map<String, double> calculateCumulativeBalanceByCurrency(
  List<TxItem> allItems,
  DateTime upToMonth, {
  required String fallbackCurrency,
}) {
  final cutoff = DateTime(upToMonth.year, upToMonth.month + 1);
  final result = <String, double>{};
  for (final x in allItems) {
    if (!x.date.isBefore(cutoff)) continue;
    final currency = effectiveItemCurrency(x, fallbackCurrency);
    final delta = x.isExpense ? -x.amount : x.amount;
    result[currency] = (result[currency] ?? 0.0) + delta;
  }
  return result;
}

Map<String, double> calculatePrevMonthBalanceByCurrency(
  List<TxItem> allItems,
  DateTime month, {
  required String fallbackCurrency,
}) {
  final prevYear = month.month == 1 ? month.year - 1 : month.year;
  final prevMonth = month.month == 1 ? 12 : month.month - 1;
  final result = <String, double>{};
  for (final x in allItems) {
    if (x.date.year != prevYear || x.date.month != prevMonth) continue;
    final currency = effectiveItemCurrency(x, fallbackCurrency);
    final delta = x.isExpense ? -x.amount : x.amount;
    result[currency] = (result[currency] ?? 0.0) + delta;
  }
  return result;
}
