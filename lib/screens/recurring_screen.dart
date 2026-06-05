import 'package:flutter/material.dart';

import '../models/recurring_item.dart';
import '../utils/i18n.dart';
import '../utils/category_store.dart';
import '../widgets/section_label.dart';

class RecurringScreen extends StatefulWidget {
  final String language;
  final String currency;

  const RecurringScreen({
    super.key,
    required this.language,
    required this.currency,
  });

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringItem> _items = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _items = RecurringItem.loadAll());
  }

  Future<void> _openAddSheet([RecurringItem? existing]) async {
    final saved = await showModalBottomSheet<RecurringItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddRecurringSheet(
        language: widget.language,
        currency: widget.currency,
        existing: existing,
      ),
    );
    if (saved == null) return;
    if (existing == null) {
      await RecurringItem.add(saved);
    } else {
      await RecurringItem.updateById(saved.id, saved);
    }
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('recurring_saved', widget.language))),
    );
  }

  Future<void> _delete(RecurringItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_entry_title', widget.language)),
        content: Text(t('delete_entry_message', widget.language)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel', widget.language)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('delete', widget.language)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await RecurringItem.removeById(item.id);
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('recurring_deleted', widget.language))),
    );
  }

  Future<void> _toggleActive(RecurringItem item) async {
    await RecurringItem.updateById(
      item.id,
      item.copyWith(isActive: !item.isActive),
    );
    _reload();
  }

  String _freqLabel(RecurringItem item) {
    if (item.frequency == 'monthly') {
      return '${t('monthly', widget.language)} ${item.dayOfMonth}';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const daysko = ['월', '화', '수', '목', '금', '토', '일'];
    final idx = (item.dayOfWeek - 1).clamp(0, 6);
    return '${t('weekly', widget.language)} ${widget.language == 'ko' ? daysko[idx] : days[idx]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('recurring_management', widget.language))),
      body: _items.isEmpty
          ? Center(
              child: Text(
                t('no_recurring', widget.language),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF75879A),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = _items[i];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD9E4EE)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD9E4EE)),
                      ),
                      child: Text(
                        item.category.split(' ').first,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    title: Text(
                      '${item.isExpense ? '-' : '+'}${item.amount.toStringAsFixed(2)} ${item.currency}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: item.isExpense
                            ? const Color(0xFFB4544A)
                            : const Color(0xFF1C8B65),
                      ),
                    ),
                    subtitle: Text(
                      _freqLabel(item),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF75879A),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.isActive,
                          onChanged: (_) => _toggleActive(item),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFB4544A),
                          ),
                          onPressed: () => _delete(item),
                        ),
                      ],
                    ),
                    onTap: () => _openAddSheet(item),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Add/Edit sheet
// ─────────────────────────────────────────────────────────────────

class _AddRecurringSheet extends StatefulWidget {
  final String language;
  final String currency;
  final RecurringItem? existing;

  const _AddRecurringSheet({
    required this.language,
    required this.currency,
    this.existing,
  });

  @override
  State<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<_AddRecurringSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isExpense = true;
  String _category = '';
  String _currency = 'USD';
  String _paymentMethod = 'cash';
  String _frequency = 'monthly';
  int _dayOfMonth = 1;
  int _dayOfWeek = 1; // 1=Mon

  List<String> get _categories =>
      _isExpense
          ? CategoryStore.expenseCategories()
          : CategoryStore.incomeCategories();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _currency = widget.currency;
    if (e != null) {
      _isExpense = e.isExpense;
      _category = e.category;
      _currency = e.currency.isEmpty ? widget.currency : e.currency;
      _paymentMethod = e.paymentMethod;
      _frequency = e.frequency;
      _dayOfMonth = e.dayOfMonth;
      _dayOfWeek = e.dayOfWeek;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note;
    } else {
      _category = _categories.isNotEmpty ? _categories.first : '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit
                  ? t('edit_recurring', widget.language)
                  : t('add_recurring', widget.language),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            SectionLabel(t('amount', widget.language)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: t('amount_hint', widget.language),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            SectionLabel(t('currency', widget.language)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              items: const ['USD','KRW','EUR','JPY','GBP','CAD','AUD','CNY','HKD','SGD','MXN','BRL','THB','VND']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _currency = v ?? _currency),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(t('expense', widget.language))),
                ButtonSegment(value: false, label: Text(t('income', widget.language))),
              ],
              selected: {_isExpense},
              onSelectionChanged: (s) {
                setState(() {
                  _isExpense = s.first;
                  final cats = _isExpense
                      ? CategoryStore.expenseCategories()
                      : CategoryStore.incomeCategories();
                  if (!cats.contains(_category) && cats.isNotEmpty) _category = cats.first;
                  if (_isExpense && _paymentMethod == 'bank') _paymentMethod = 'cash';
                });
              },
            ),
            const SizedBox(height: 12),

            SectionLabel(t('category', widget.language)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_category) ? _category : (_categories.isNotEmpty ? _categories.first : null),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(categoryText(c, widget.language)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            SectionLabel(t('payment_method', widget.language)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', label: Text(t('cash', widget.language))),
                ButtonSegment(value: 'card', label: Text(t('card', widget.language))),
                if (!_isExpense)
                  ButtonSegment(value: 'bank', label: Text(t('bank', widget.language))),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
            ),
            const SizedBox(height: 12),

            SectionLabel(t('frequency', widget.language)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'monthly', label: Text(t('monthly', widget.language))),
                ButtonSegment(value: 'weekly', label: Text(t('weekly', widget.language))),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            const SizedBox(height: 12),

            if (_frequency == 'monthly') ...[
              SectionLabel(t('day_of_month', widget.language)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                items: List.generate(28, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                    .toList(),
                onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ] else ...[
              SectionLabel(t('day_of_week_label', widget.language)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _dayOfWeek,
                items: widget.language == 'ko'
                    ? const [
                        DropdownMenuItem(value: 1, child: Text('월요일')),
                        DropdownMenuItem(value: 2, child: Text('화요일')),
                        DropdownMenuItem(value: 3, child: Text('수요일')),
                        DropdownMenuItem(value: 4, child: Text('목요일')),
                        DropdownMenuItem(value: 5, child: Text('금요일')),
                        DropdownMenuItem(value: 6, child: Text('토요일')),
                        DropdownMenuItem(value: 7, child: Text('일요일')),
                      ]
                    : const [
                        DropdownMenuItem(value: 1, child: Text('Monday')),
                        DropdownMenuItem(value: 2, child: Text('Tuesday')),
                        DropdownMenuItem(value: 3, child: Text('Wednesday')),
                        DropdownMenuItem(value: 4, child: Text('Thursday')),
                        DropdownMenuItem(value: 5, child: Text('Friday')),
                        DropdownMenuItem(value: 6, child: Text('Saturday')),
                        DropdownMenuItem(value: 7, child: Text('Sunday')),
                      ],
                onChanged: (v) => setState(() => _dayOfWeek = v ?? 1),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),

            SectionLabel(t('memo_optional', widget.language)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final amount = double.tryParse(
                    _amountCtrl.text.trim().replaceAll(',', ''),
                  );
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('enter_valid_amount', widget.language)),
                      ),
                    );
                    return;
                  }
                  final item = RecurringItem(
                    id: widget.existing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    isExpense: _isExpense,
                    amount: amount,
                    category: _category,
                    note: _noteCtrl.text.trim(),
                    currency: _currency,
                    paymentMethod: _paymentMethod,
                    frequency: _frequency,
                    dayOfMonth: _dayOfMonth,
                    dayOfWeek: _dayOfWeek,
                    lastGeneratedKey: widget.existing?.lastGeneratedKey ?? '',
                    isActive: widget.existing?.isActive ?? true,
                  );
                  Navigator.pop(context, item);
                },
                child: Text(
                  isEdit
                      ? t('save_changes', widget.language)
                      : t('save', widget.language),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
