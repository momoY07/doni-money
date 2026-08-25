import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../utils/i18n.dart';
import '../utils/category_store.dart';
import '../widgets/category_icon.dart';
import '../storage.dart';
import '../utils/currency_utils.dart';

const _kCurrencies = [
  'USD', 'KRW', 'EUR', 'JPY', 'GBP',
  'CAD', 'AUD', 'CNY', 'HKD', 'SGD',
  'MXN', 'BRL', 'THB', 'VND',
];

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
  final _categoryPageCtrl = PageController();
  int _categoryPage = 0;

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
    if (picked != null) setState(() => selectedDate = picked);
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

  Future<void> _pickCurrency() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('currency', widget.language)),
        children: _kCurrencies
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, c),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        c == selectedCurrency ? FontWeight.w700 : FontWeight.normal,
                    color: c == selectedCurrency
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (result != null) setState(() => selectedCurrency = result);
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    _categoryPageCtrl.dispose();
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

  String _dateKeyLabel() {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    if (isToday) {
      const labels = {'ko': '오늘', 'es': 'Hoy', 'zh': '今天', 'ja': '今日'};
      return labels[widget.language] ?? 'Today';
    }
    return '${selectedDate.month}/${selectedDate.day}';
  }

  Widget _buildCategoryPager() {
    const int cols = 4;
    const int rows = 3;
    const int perPage = cols * rows;
    const double rowGap = 8;
    const double colGap = 8;

    final cats = _gridCategories;
    final pageCount = (cats.length / perPage).ceil();
    if (pageCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final indicatorH = pageCount > 1 ? 8.0 + 8.0 : 0.0;
        final rawTileH =
            (constraints.maxHeight - indicatorH - rowGap * (rows - 1)) / rows;
        final tileH = rawTileH.clamp(40.0, 90.0);
        final imageSize = (tileH * 0.44).clamp(22.0, 44.0);
        final emojiSize = (tileH * 0.38).clamp(18.0, 38.0);
        final pageViewH = tileH * rows + rowGap * (rows - 1);

        Widget buildTile(String c) {
          final isSelected = c == category;
          return GestureDetector(
            onTap: () => setState(() => category = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: tileH,
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
                    imageSize: imageSize,
                    emojiSize: emojiSize,
                  ),
                  SizedBox(height: tileH * 0.06),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      categoryTextNoEmoji(c, widget.language),
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: pageViewH,
              child: PageView.builder(
                controller: _categoryPageCtrl,
                scrollDirection: Axis.horizontal,
                itemCount: pageCount,
                onPageChanged: (page) => setState(() => _categoryPage = page),
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * perPage;
                  final pageEnd = start + perPage > cats.length
                      ? cats.length
                      : start + perPage;
                  final pageCats = cats.sublist(start, pageEnd);

                  final rowWidgets = <Widget>[];
                  for (int row = 0; row < rows; row++) {
                    final rowStart = row * cols;
                    if (rowStart >= pageCats.length) break;
                    if (row > 0) rowWidgets.add(SizedBox(height: rowGap));
                    final rowEnd = rowStart + cols > pageCats.length
                        ? pageCats.length
                        : rowStart + cols;
                    final rowCats = pageCats.sublist(rowStart, rowEnd);
                    rowWidgets.add(
                      Row(
                        children: [
                          for (int i = 0; i < cols; i++) ...[
                            if (i > 0) const SizedBox(width: colGap),
                            Expanded(
                              child: i < rowCats.length
                                  ? buildTile(rowCats[i])
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: rowWidgets,
                  );
                },
              ),
            ),
            if (pageCount > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (i) {
                  final active = i == _categoryPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 8 : 6,
                    height: active ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNumpad() {
    final decimals = currencyDecimals(selectedCurrency);
    final dateLabel = _dateKeyLabel();

    Widget numKey(
      String label, {
      bool disabled = false,
      int flex = 1,
      VoidCallback? onTap,
    }) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: GestureDetector(
            onTap: disabled ? null : (onTap ?? () => _numpadInput(label)),
            child: Container(
              height: 44,
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
                  fontSize: 18,
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
        Row(children: [numKey('1'), numKey('2'), numKey('3'), numKey('⌫')]),
        Row(children: [
          numKey('4'),
          numKey('5'),
          numKey('6'),
          numKey(dateLabel, onTap: pickDate),
        ]),
        Row(children: [
          numKey('7'),
          numKey('8'),
          numKey('9'),
          numKey('✓', onTap: _saveEntry),
        ]),
        Row(children: [
          numKey('.', disabled: decimals == 0),
          numKey('0', flex: 2),
          const Expanded(child: SizedBox()),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final showKeyboard = bottomInset > 0;

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          showKeyboard
              ? bottomInset
              : MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단: 지출/수입 토글 + 닫기
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
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
                        if (!currentCategories.contains(category) &&
                            currentCategories.isNotEmpty) {
                          category = currentCategories.first;
                        }
                        // 지출로 전환 시 bank는 지원하지 않으므로 cash로 초기화
                        if (isExpense && paymentMethod == 'bank') {
                          paymentMethod = 'card';
                        }
                        _categoryPage = 0;
                      });
                      _categoryPageCtrl.jumpToPage(0);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 중간: 카테고리 페이저 (남은 공간 차지)
            Expanded(child: _buildCategoryPager()),
            const SizedBox(height: 8),
            // 메모 + 금액 + 통화 한 줄
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText: t('memo_optional', widget.language),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickCurrency,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFBFCFCB)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          amountCtrl.text.isEmpty ? '0' : amountCtrl.text,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF24364A),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selectedCurrency,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF75879A),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: Color(0xFF75879A),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 결제수단 칩
            Row(
              children: [
                for (final method in [
                  'card',
                  'cash',
                  if (!isExpense) 'bank',
                ]) ...[
                  if (method != 'card') const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => paymentMethod = method),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: paymentMethod == method
                            ? Theme.of(context).colorScheme.primaryContainer
                            : const Color(0xFFF2F4F6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: paymentMethod == method
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        t(method, widget.language),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: paymentMethod == method
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : const Color(0xFF24364A),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // 키패드 (메모 키보드가 올라와 있으면 숨김)
            if (!showKeyboard) _buildNumpad(),
          ],
        ),
      ),
    );
  }
}
