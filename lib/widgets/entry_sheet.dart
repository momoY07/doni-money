import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../utils/i18n.dart';
import '../utils/category_store.dart';
import '../widgets/category_icon.dart';
import '../widgets/section_label.dart';
import '../storage.dart';

class EntrySheet extends StatefulWidget {
  final String language;
  final TxItem? initialItem;

  const EntrySheet({super.key, required this.language, this.initialItem});

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  bool isExpense = true;
  String category = '🍔 Food';
  DateTime selectedDate = DateTime.now();
  String selectedCurrency = 'USD';
  String paymentMethod = 'cash';
  bool _isCyberAI = false;
  bool _isOtter = false;

  @override
  void initState() {
    super.initState();

    selectedCurrency =
        Storage.txBox.get('selectedCurrency', defaultValue: 'USD') as String;
    final theme = Storage.txBox.get('selectedTheme', defaultValue: 'cream') as String;
    _isCyberAI = theme == 'cyber_ai';
    _isOtter = isOtterTheme(theme);

    final item = widget.initialItem;
    if (item == null) return;

    isExpense = item.isExpense;
    category = item.category;
    selectedDate = item.date;
    amountCtrl.text = item.amount.toString();
    noteCtrl.text = item.note;
    paymentMethod = item.paymentMethod.isEmpty ? 'cash' : item.paymentMethod;

    if (!currentCategories.contains(category) && currentCategories.isNotEmpty) {
      category = currentCategories.first;
    }
  }

  List<String> get currentCategories =>
      isExpense
          ? CategoryStore.expenseCategories()
          : CategoryStore.incomeCategories();

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  String get formattedDate {
    return '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialItem != null;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditMode
                    ? (isExpense
                          ? t('edit_expense', widget.language)
                          : t('edit_income', widget.language))
                    : (isExpense
                          ? t('expense', widget.language)
                          : t('income', widget.language)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              SectionLabel(t('amount', widget.language)),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: t('amount_hint', widget.language),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              SectionLabel(t('currency', widget.language)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCurrency,
                items:
                    const [
                          'USD', 'KRW', 'EUR', 'JPY', 'GBP',
                          'CAD', 'AUD', 'CNY', 'HKD', 'SGD',
                          'MXN', 'BRL', 'THB', 'VND',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) =>
                    setState(() => selectedCurrency = v ?? selectedCurrency),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(t('expense', widget.language)),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(t('income', widget.language)),
                  ),
                ],
                selected: {isExpense},
                onSelectionChanged: (s) {
                  setState(() {
                    isExpense = s.first;
                    if (!currentCategories.contains(category) && currentCategories.isNotEmpty) {
                      category = currentCategories.first;
                    }
                    // 지출로 전환 시 bank는 지원하지 않으므로 cash로 초기화
                    if (isExpense && paymentMethod == 'bank') {
                      paymentMethod = 'cash';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              SectionLabel(t('category', widget.language)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                items: currentCategories
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Row(
                          children: [
                            if (_isCyberAI || _isOtter) ...[
                              categoryIconWidget(
                                rawCategory: c,
                                isCyberAI: _isCyberAI,
                                imageSize: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(categoryTextNoEmoji(c, widget.language)),
                            ] else
                              Text(categoryText(c, widget.language)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => category = v ?? category),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              SectionLabel(t('payment_method', widget.language)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'cash',
                    label: Text(t('cash', widget.language)),
                  ),
                  ButtonSegment<String>(
                    value: 'card',
                    label: Text(t('card', widget.language)),
                  ),
                  if (!isExpense)
                    ButtonSegment<String>(
                      value: 'bank',
                      label: Text(t('bank', widget.language)),
                    ),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (s) =>
                    setState(() => paymentMethod = s.first),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFBFCFCB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${t('date', widget.language)}: $formattedDate',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SectionLabel(t('memo_optional', widget.language)),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final raw = amountCtrl.text.trim();
                    final amount = double.tryParse(raw.replaceAll(',', ''));

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t('enter_valid_amount', widget.language),
                          ),
                        ),
                      );
                      return;
                    }

                    final currentSelectedCurrency = selectedCurrency;

                    final effectiveCurrency =
                        widget.initialItem != null &&
                            widget.initialItem!.entryCurrency.trim().isNotEmpty
                        ? widget.initialItem!.entryCurrency
                        : currentSelectedCurrency;

                    final item = TxItem(
                      id:
                          widget.initialItem?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      isExpense: isExpense,
                      amount: amount,
                      category: category,
                      note: noteCtrl.text.trim(),
                      date: selectedDate,
                      entryCurrency: effectiveCurrency,
                      baseAmount: amount,
                      baseCurrency: effectiveCurrency,
                      exchangeRate: 1.0,
                      currencyMetaVersion: 1,
                      paymentMethod: paymentMethod,
                    );

                    Navigator.pop(context, item);
                  },
                  child: Text(
                    isEditMode
                        ? t('save_changes', widget.language)
                        : t('save', widget.language),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
