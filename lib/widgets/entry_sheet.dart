import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../utils/i18n.dart';
import '../utils/category_store.dart';
import '../widgets/category_icon.dart';
import '../widgets/section_label.dart';
import '../storage.dart';
import '../utils/currency_utils.dart';

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
  String _amountRaw = '';

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
    String rawStr = item.amount.toString();
    if (rawStr.endsWith('.0')) rawStr = rawStr.substring(0, rawStr.length - 2);
    _amountRaw = rawStr;
    amountCtrl.text = _formatDisplay(_amountRaw);
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
    super.dispose();
  }

  String _addThousandsSep(String intStr) {
    if (intStr.length <= 3) return intStr;
    final buf = StringBuffer();
    final offset = intStr.length % 3;
    for (int i = 0; i < intStr.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0) buf.write(',');
      buf.write(intStr[i]);
    }
    return buf.toString();
  }

  String _formatDisplay(String raw) {
    if (raw.isEmpty) return '0';
    final parts = raw.split('.');
    final formatted = _addThousandsSep(parts[0]);
    return parts.length == 2 ? '$formatted.${parts[1]}' : formatted;
  }

  void _numpadInput(String key) {
    final decimals = currencyDecimals(selectedCurrency);

    if (key == '⌫') {
      if (_amountRaw.isNotEmpty) {
        setState(() {
          _amountRaw = _amountRaw.substring(0, _amountRaw.length - 1);
          amountCtrl.text = _amountRaw.isEmpty ? '' : _formatDisplay(_amountRaw);
        });
      }
      return;
    }

    if (key == '.') {
      if (decimals == 0 || _amountRaw.contains('.')) return;
      setState(() {
        _amountRaw = _amountRaw.isEmpty ? '0.' : '$_amountRaw.';
        amountCtrl.text = _formatDisplay(_amountRaw);
      });
      return;
    }

    // 숫자 키
    if (_amountRaw.contains('.')) {
      final dec = _amountRaw.split('.')[1];
      if (dec.length >= decimals) return;
    }
    setState(() {
      _amountRaw = _amountRaw == '0' ? key : _amountRaw + key;
      amountCtrl.text = _formatDisplay(_amountRaw);
    });
  }

  Widget _buildNumpad() {
    final decimals = currencyDecimals(selectedCurrency);

    Widget numKey(String label, {bool disabled = false}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: GestureDetector(
            onTap: disabled ? null : () => _numpadInput(label),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: disabled
                    ? const Color(0xFFEEEEEE)
                    : const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? const Color(0xFFBBBBBB)
                      : const Color(0xFF24364A),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [numKey('1'), numKey('2'), numKey('3')]),
        Row(children: [numKey('4'), numKey('5'), numKey('6')]),
        Row(children: [numKey('7'), numKey('8'), numKey('9')]),
        Row(children: [
          numKey('.', disabled: decimals == 0),
          numKey('0'),
          numKey('⌫'),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialItem != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16 + MediaQuery.of(context).viewPadding.top,
            bottom: 16 + bottomInset,
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFBFCFCB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      amountCtrl.text.isEmpty ? '0' : amountCtrl.text,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF24364A)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildNumpad(),
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
                          height: 90,
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
                                  imageSize: 44,
                                  emojiSize: 38,
                                ),
                                const SizedBox(height: 6),
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
    );
  }
}

