import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../utils/i18n.dart';
import '../utils/currency_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';

class TransactionsPage extends StatefulWidget {
  final List<TxItem> items;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final Future<void> Function(int index) onDelete;
  final Future<void> Function(int index, TxItem item) onEdit;
  final String language;
  final String currency;
  final String listFilter;
  final ValueChanged<String> onListFilterChanged;
  final String listQuery;
  final ValueChanged<String> onListQueryChanged;
  final String selectedTheme;

  const TransactionsPage({
    super.key,
    required this.items,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDelete,
    required this.language,
    required this.currency,
    required this.onEdit,
    required this.listFilter,
    required this.onListFilterChanged,
    required this.listQuery,
    required this.onListQueryChanged,
    required this.selectedTheme,
  });
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.listQuery);
  }

  @override
  void didUpdateWidget(covariant TransactionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.listQuery != _searchCtrl.text) {
      _searchCtrl.value = TextEditingValue(
        text: widget.listQuery,
        selection: TextSelection.collapsed(offset: widget.listQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildHeaderCard(BuildContext context, String monthLabel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset(themeImage(widget.selectedTheme, 'header_list'), width: 34, height: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: widget.onPrevMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: widget.onNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment<String>(
              value: 'all',
              label: Text(t('filter_all', widget.language)),
            ),
            ButtonSegment<String>(
              value: 'expense',
              label: Text(t('filter_expense', widget.language)),
            ),
            ButtonSegment<String>(
              value: 'income',
              label: Text(t('filter_income', widget.language)),
            ),
          ],
          selected: {widget.listFilter},
          onSelectionChanged: (s) {
            _hideKeyboard();
            widget.onListFilterChanged(s.first);
          },
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    final hasQuery = widget.listQuery.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          onChanged: widget.onListQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: t('search_hint', widget.language),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: hasQuery
                ? IconButton(
                    onPressed: () {
                      _hideKeyboard();
                      _searchCtrl.clear();
                      widget.onListQueryChanged('');
                    },
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${widget.selectedMonth.year}-${widget.selectedMonth.month.toString().padLeft(2, '0')}';

    String formatMoney(double amount) =>
        formatCurrencyValue(amount, widget.currency);

    final monthItems =
        widget.items.where((x) {
          return x.date.year == widget.selectedMonth.year &&
              x.date.month == widget.selectedMonth.month;
        }).toList()..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          return b.id.compareTo(a.id);
        });

    final filteredItems = monthItems.where((x) {
      if (widget.listFilter == 'expense') return x.isExpense;
      if (widget.listFilter == 'income') return !x.isExpense;
      return true;
    }).toList();

    final q = widget.listQuery.trim().toLowerCase();

    final searchedItems = filteredItems.where((x) {
      if (q.isEmpty) return true;

      final note = x.note.toLowerCase();
      final rawCategory = x.category.toLowerCase();
      final translatedCategory = categoryText(
        x.category,
        widget.language,
      ).toLowerCase();

      return note.contains(q) ||
          rawCategory.contains(q) ||
          translatedCategory.contains(q);
    }).toList();

    final hasActiveQuery = q.isNotEmpty;
    final hasActiveFilter = widget.listFilter != 'all';

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(context, monthLabel),
        const SizedBox(height: 12),
        _buildFilterCard(),
        const SizedBox(height: 12),
        _buildSearchCard(),
        if (monthItems.isNotEmpty && (hasActiveQuery || hasActiveFilter)) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${searchedItems.length} / ${monthItems.length}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6C7D90)),
            ),
          ),
        ],
        const SizedBox(height: 12),

        if (searchedItems.isEmpty) ...[
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Image.asset(themeImage(widget.selectedTheme, 'no_data'), width: 90, height: 90),
                const SizedBox(height: 12),
                Text(
                  monthItems.isEmpty
                      ? t('no_entries_yet', widget.language)
                      : (hasActiveQuery
                            ? t('no_search_results', widget.language)
                            : t('no_filtered_entries', widget.language)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  monthItems.isEmpty
                      ? (['dog', 'dog_dark'].contains(widget.selectedTheme)
                            ? '강아지가 첫 기록을 기다리고 있어요!'
                            : t('otter_waiting_first_log', widget.language))
                      : (hasActiveQuery
                            ? t('try_another_keyword', widget.language)
                            : t('try_another_filter', widget.language)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    color: Color(0xFF6C7D90),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...searchedItems.map((x) {
            final sign = x.isExpense ? '-' : '+';
            final amt = formatCurrencyValue(
              x.amount,
              effectiveItemCurrency(x, widget.currency),
            );
            final date =
                '${x.date.year}-${x.date.month.toString().padLeft(2, '0')}-${x.date.day.toString().padLeft(2, '0')}';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () async {
                  final originalIndex = widget.items.indexWhere(
                    (item) => item.id == x.id,
                  );
                  if (originalIndex == -1) return;
                  await widget.onEdit(originalIndex, x);
                },
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(t('delete_entry_title', widget.language)),
                      content: Text(t('delete_entry_message', widget.language)),
                      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      actions: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(t('delete', widget.language)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(t('cancel', widget.language)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    final originalIndex = widget.items.indexWhere(
                      (item) => item.id == x.id,
                    );
                    if (originalIndex == -1) return;

                    await widget.onDelete(originalIndex);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('deleted', widget.language))),
                      );
                    }
                  }
                },
                leading: categoryIconWidget(
                  rawCategory: x.category,
                  isCyberAI: widget.selectedTheme == 'cyber_ai',
                  emojiSize: 22,
                  imageSize: 28,
                ),
                title: Text(
                  x.note.isEmpty ? t('no_memo', widget.language) : x.note,
                ),
                subtitle: Text(
                  '${widget.selectedTheme == 'cyber_ai' ? categoryTextNoEmoji(x.category, widget.language) : categoryText(x.category, widget.language)} · $date',
                ),
                trailing: Text('$sign$amt'),
              ),
            );
          }),
        ],
      ],
    );
  }
}
