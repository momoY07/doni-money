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
  final bool? initialIsExpense;

  const EntrySheet({super.key, required this.language, this.initialItem, this.initialIsExpense});

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  bool isExpense = true;
  String category = '🍔 Food';
  DateTime selectedDate = DateTime.now();
  String selectedCurrency = 'USD';
  String paymentMethod = 'card';
  bool _isCyberAI = false;

  @override
  void initState() {
    super.initState();

    selectedCurrency =
        Storage.txBox.get('selectedCurrency', defaultValue: 'USD') as String;
    final theme = Storage.txBox.get('selectedTheme', defaultValue: 'cream') as String;
    _isCyberAI = theme == 'cyber_ai';

    final item = widget.initialItem;
    if (item == null) {
      if (widget.initialIsExpense != null) isExpense = widget.initialIsExpense!;
      if (currentCategories.isNotEmpty) category = currentCategories.first;
      return;
    }

    isExpense = item.isExpense;
    category = item.category;
    selectedDate = item.date;
    amountCtrl.text = item.amount.toString();
    noteCtrl.text = item.note;
    paymentMethod = item.paymentMethod.isEmpty ? 'cash' : item.paymentMethod;
  }

  List<String> get currentCategories =>
      isExpense
          ? CategoryStore.expenseCategories()
          : CategoryStore.incomeCategories();

  // 편집 모드에서 삭제된 카테고리가 목록에 없으면 맨 앞에 강제 추가
  List<String> get _gridCategories {
    final cats = currentCategories.toList();
    if (widget.initialItem != null && !cats.contains(category)) {
      cats.insert(0, category);
    }
    return cats;
  }

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

  void _saveEntry() {
    final raw = amountCtrl.text.trim();
    final amount = double.tryParse(raw.replaceAll(',', ''));

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('enter_valid_amount', widget.language))),
      );
      return;
    }

    final effectiveCurrency =
        widget.initialItem != null &&
            widget.initialItem!.entryCurrency.trim().isNotEmpty
        ? widget.initialItem!.entryCurrency
        : selectedCurrency;

    final item = TxItem(
      id: widget.initialItem?.id ??
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
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialItem != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final showDoneBar = bottomInset > 0;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16 + MediaQuery.of(context).viewPadding.top,
                bottom: 16 + bottomInset + (showDoneBar ? 44 : 0),
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
                    focusNode: _amountFocus,
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
                      paymentMethod = 'card';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              SectionLabel(t('category', widget.language)),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 8 * 3) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _gridCategories.map((c) {
                      final isSelected = c == category;
                      return GestureDetector(
                        onTap: () => setState(() => category = c),
                        child: SizedBox(
                          width: tileWidth,
                          height: 76,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                categoryIconWidget(
                                  rawCategory: c,
                                  isCyberAI: _isCyberAI,
                                  imageSize: 28,
                                  emojiSize: 22,
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Text(
                                    categoryTextNoEmoji(c, widget.language),
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),

              SectionLabel(t('payment_method', widget.language)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'card',
                    label: Text(t('card', widget.language)),
                  ),
                  ButtonSegment<String>(
                    value: 'cash',
                    label: Text(t('cash', widget.language)),
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
                  onPressed: _saveEntry,
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
          if (showDoneBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  border: Border(
                    top: BorderSide(color: const Color(0xFFCCCCCC), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => FocusScope.of(context).unfocus(),
                      child: Text(
                        t('keyboard_done', widget.language),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

