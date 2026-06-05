class TxItem {
  final String id;
  final bool isExpense;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  final String entryCurrency;
  final double baseAmount;
  final String baseCurrency;
  final double exchangeRate;
  final int currencyMetaVersion;
  final String paymentMethod;

  TxItem({
    required this.id,
    required this.isExpense,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.entryCurrency = '',
    double? baseAmount,
    String? baseCurrency,
    this.exchangeRate = 1.0,
    this.currencyMetaVersion = 0,
    this.paymentMethod = '',
  }) : baseAmount = baseAmount ?? amount,
       baseCurrency = baseCurrency ?? entryCurrency;

  bool get hasCurrencyMeta =>
      currencyMetaVersion > 0 && entryCurrency.trim().isNotEmpty;

  factory TxItem.fromMap(Map<String, dynamic> map) {
    final amount = (map['amount'] as num).toDouble();
    final rawEntryCurrency = map['entryCurrency']?.toString() ?? '';
    final rawBaseCurrency = map['baseCurrency']?.toString() ?? '';
    final rawVersion = map['currencyMetaVersion'];

    return TxItem(
      id:
          (map['id'] as String?) ??
          '${map['date']}_${map['amount']}_${map['category']}_${map['note']}',
      isExpense: map['isExpense'] as bool,
      amount: amount,
      category: map['category'] as String,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
      entryCurrency: rawEntryCurrency.trim(),
      baseAmount: map['baseAmount'] is num
          ? (map['baseAmount'] as num).toDouble()
          : amount,
      baseCurrency: rawBaseCurrency.trim().isEmpty
          ? rawEntryCurrency.trim()
          : rawBaseCurrency.trim(),
      exchangeRate: map['exchangeRate'] is num
          ? (map['exchangeRate'] as num).toDouble()
          : 1.0,
      currencyMetaVersion: rawVersion is int
          ? rawVersion
          : (rawVersion is num
                ? rawVersion.toInt()
                : (rawEntryCurrency.trim().isEmpty ? 0 : 1)),
      paymentMethod: map['paymentMethod']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isExpense': isExpense,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'entryCurrency': entryCurrency,
      'baseAmount': baseAmount,
      'baseCurrency': baseCurrency,
      'exchangeRate': exchangeRate,
      'currencyMetaVersion': currencyMetaVersion,
      'paymentMethod': paymentMethod,
    };
  }
}
