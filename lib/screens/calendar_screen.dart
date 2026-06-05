import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../models/currency_summary.dart';
import '../utils/i18n.dart';
import '../utils/currency_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/tx_detail_sheet.dart';

class CalendarPage extends StatefulWidget {
  final List<TxItem> items;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final String language;
  final String currency;
  final String selectedTheme;
  final Future<void> Function(TxItem) onEditItem;
  final Future<void> Function(TxItem) onDeleteItem;

  const CalendarPage({
    super.key,
    required this.items,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.language,
    required this.currency,
    required this.selectedTheme,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime selectedDate;
  bool get _isMB => widget.selectedTheme == 'minimal_black';
  bool get _isCA => widget.selectedTheme == 'cyber_ai';

  @override
  void initState() {
    super.initState();
    selectedDate = _defaultSelectedDate(widget.selectedMonth);
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final monthChanged =
        oldWidget.selectedMonth.year != widget.selectedMonth.year ||
        oldWidget.selectedMonth.month != widget.selectedMonth.month;

    if (monthChanged) {
      selectedDate = _defaultSelectedDate(widget.selectedMonth);
    }
  }

  DateTime _defaultSelectedDate(DateTime month) {
    final today = DateTime.now();

    if (today.year == month.year && today.month == month.month) {
      return DateTime(today.year, today.month, today.day);
    }

    return DateTime(month.year, month.month, 1);
  }

  void _openDetailSheet(BuildContext context, TxItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TxDetailSheet(
        item: item,
        language: widget.language,
        currency: widget.currency,
        onEdit: () => widget.onEditItem(item),
        onDelete: () => widget.onDeleteItem(item),
      ),
    );
  }

  void _showDaySheet(BuildContext context, List<TxItem> dayItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayRecordsSheet(
        date: selectedDate,
        dayItems: dayItems,
        language: widget.language,
        currency: widget.currency,
        selectedTheme: widget.selectedTheme,
        onTapItem: (item) => _openDetailSheet(context, item),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMonthLabel() {
    if (widget.language == 'ko') {
      return '${widget.selectedMonth.year}년 ${widget.selectedMonth.month}월';
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final monthName = months[widget.selectedMonth.month - 1];
    return '$monthName ${widget.selectedMonth.year}';
  }

  String _formatFullMoney(double amount) {
    return formatCurrencyValue(amount, widget.currency);
  }

  List<String> get _weekLabels {
    if (widget.language == 'ko') {
      return const ['일', '월', '화', '수', '목', '금', '토'];
    }
    return const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  }

  Widget _buildHeaderCard(BuildContext context, String monthLabel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 30,
              color: Color(0xFF9C7A22),
            ),
            const SizedBox(width: 10),
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

  Widget _buildWeekHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
      ),
      child: Row(
        children: _weekLabels.map((label) {
          return Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF75879A),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(List<TxItem> monthItems) {
    final firstDay = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month,
      1,
    );
    final daysInMonth = DateUtils.getDaysInMonth(
      widget.selectedMonth.year,
      widget.selectedMonth.month,
    );
    final leadingEmpty = firstDay.weekday % 7;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;

    final groupedByDay = <int, List<TxItem>>{};
    for (final item in monthItems) {
      groupedByDay.putIfAbsent(item.date.day, () => []);
      groupedByDay[item.date.day]!.add(item);
    }

    final today = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        if (index < leadingEmpty || index >= leadingEmpty + daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = index - leadingEmpty + 1;
        final cellDate = DateTime(
          widget.selectedMonth.year,
          widget.selectedMonth.month,
          day,
        );

        final dayItems = groupedByDay[day] ?? [];
        final dayIncome = dayItems
            .where((x) => !x.isExpense)
            .fold(0.0, (sum, x) => sum + x.amount);

        final dayCurrencies = collectItemCurrencies(
          dayItems,
          fallbackCurrency: widget.currency,
        );
        final hasMixedDayCurrencies = dayCurrencies.length > 1;
        final dayCurrency = dayCurrencies.isEmpty
            ? widget.currency
            : dayCurrencies.first;
        final dayExpense = dayItems
            .where((x) => x.isExpense)
            .fold(0.0, (sum, x) => sum + x.amount);

        final isSelected = _isSameDate(cellDate, selectedDate);
        final isToday = _isSameDate(cellDate, today);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() => selectedDate = cellDate);
            _showDaySheet(context, groupedByDay[day] ?? []);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            decoration: BoxDecoration(
              color: _isCA
                  ? (isSelected ? const Color(0xFF1A1A3A) : const Color(0xFF0F0F2A))
                  : (_isMB
                      ? (isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E))
                      : (isSelected ? const Color(0xFFF8EDC3) : const Color(0xFFF8FAFD))),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isCA
                    ? (isSelected ? const Color(0xFF00D4FF) : const Color(0xFF2A2A5A))
                    : (_isMB
                        ? (isSelected ? const Color(0xFFC9A043) : const Color(0xFF333333))
                        : (isSelected
                              ? const Color(0xFF9C7A22)
                              : (isToday ? const Color(0xFFE2C35D) : const Color(0xFFD9E4EE)))),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _isCA
                        ? (isSelected ? const Color(0xFF162040) : const Color(0xFF0A0A1A))
                        : (_isMB
                            ? const Color(0xFF111111)
                            : (isSelected ? const Color(0xFFEDD174) : Colors.white.withOpacity(0.9))),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _isCA
                          ? (isSelected ? const Color(0xFF00D4FF) : Colors.white)
                          : (_isMB
                              ? (isSelected ? const Color(0xFFC9A043) : Colors.white)
                              : (isSelected ? const Color(0xFF5C4A1C) : const Color(0xFF24364A))),
                    ),
                  ),
                ),
                const Spacer(),
                if (dayIncome > 0 || dayExpense > 0)
                  hasMixedDayCurrencies
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E8),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE6D8AA)),
                          ),
                          child: Center(
                            child: Text(
                              widget.language == 'ko' ? '혼합' : 'Mix',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF9C7A22),
                                height: 1.0,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dayIncome > 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '+${formatCurrencyValue(dayIncome, dayCurrency)}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF179C63),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            if (dayIncome > 0 && dayExpense > 0)
                              const SizedBox(height: 2),
                            if (dayExpense > 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '-${formatCurrencyValue(dayExpense, dayCurrency)}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD94B3D),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlySummaryCard({
    required double income,
    required double expense,
    required double balance,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('monthly_summary', widget.language),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMiniCard(
                    label: t('income', widget.language),
                    value: _formatFullMoney(income),
                    icon: Icons.south_west_rounded,
                    bgColor: const Color(0xFFE7F7EE),
                    iconColor: const Color(0xFF179C63),
                    textColor: const Color(0xFF179C63),
                    caIcon: Icons.arrow_downward,
                    caGlowColor: const Color(0xFF00FF88),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryMiniCard(
                    label: t('expense', widget.language),
                    value: _formatFullMoney(expense),
                    icon: Icons.north_east_rounded,
                    bgColor: const Color(0xFFFFECE8),
                    iconColor: const Color(0xFFD94B3D),
                    textColor: const Color(0xFFD94B3D),
                    caIcon: Icons.arrow_upward,
                    caGlowColor: const Color(0xFFFF3366),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isCA ? const Color(0xFF0D1B3E) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFEDD174)),
                borderRadius: BorderRadius.circular(20),
                border: (_isCA || _isMB) ? Border.all(color: _isCA ? const Color(0xFF1A2D5A) : const Color(0xFF333333)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isCA ? const Color(0xFF162040) : (_isMB ? const Color(0xFF111111) : const Color(0xFFF8EDC3)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _isCA ? const Color(0xFF00D4FF) : (_isMB ? const Color(0xFFC9A043) : const Color(0xFF9C7A22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('balance', widget.language),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF8A7440)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFullMoney(balance),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: (_isCA || _isMB) ? Colors.white : const Color(0xFF5C4A1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMixedCurrencyMonthlySummaryCard({
    required List<CurrencySummary> summaries,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('monthly_summary', widget.language),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
              ),
            ),
            const SizedBox(height: 14),
            ...summaries.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;

              return Container(
                margin: EdgeInsets.only(
                  bottom: i == summaries.length - 1 ? 0 : 10,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.currency,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t('income', widget.language)} ${formatCurrencyValue(s.income, s.currency)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF179C63),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${t('expense', widget.language)} ${formatCurrencyValue(s.expense, s.currency)}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD94B3D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t('balance', widget.language)} ${formatCurrencyValue(s.balance, s.currency)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5C4A1C),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMiniCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
    IconData? caIcon,
    Color? caGlowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCA && caIcon != null && caGlowColor != null)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: caGlowColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: caGlowColor.withValues(alpha: 0.5), blurRadius: 8)],
              ),
              child: Icon(caIcon, size: 20, color: caGlowColor),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF627487)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = _formatMonthLabel();

    final monthItems =
        widget.items.where((x) {
          return x.date.year == widget.selectedMonth.year &&
              x.date.month == widget.selectedMonth.month;
        }).toList()..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          if (byDate != 0) return byDate;
          return b.id.compareTo(a.id);
        });

    final monthIncome = monthItems
        .where((x) => !x.isExpense)
        .fold(0.0, (sum, x) => sum + x.amount);

    final monthExpense = monthItems
        .where((x) => x.isExpense)
        .fold(0.0, (sum, x) => sum + x.amount);

    final monthBalance = monthIncome - monthExpense;

    final monthCurrencies = collectItemCurrencies(
      monthItems,
      fallbackCurrency: widget.currency,
    );
    final hasMixedCurrencies = monthCurrencies.length > 1;

    final monthCurrencySummaries = buildCurrencySummaries(
      monthItems,
      fallbackCurrency: widget.currency,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(context, monthLabel),
        const SizedBox(height: 12),
        _buildWeekHeader(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
            boxShadow: (_isCA || _isMB) ? null : const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: _buildCalendarGrid(monthItems),
        ),
        const SizedBox(height: 16),
        if (hasMixedCurrencies) ...[
          buildMixedCurrencyNotice(
            language: widget.language,
            currencies: monthCurrencies,
          ),
          const SizedBox(height: 16),
          _buildMixedCurrencyMonthlySummaryCard(
            summaries: monthCurrencySummaries,
          ),
        ] else
          _buildMonthlySummaryCard(
            income: monthIncome,
            expense: monthExpense,
            balance: monthBalance,
          ),
      ],
    );
  }
}

class _DayRecordsSheet extends StatelessWidget {
  final DateTime date;
  final List<TxItem> dayItems;
  final String language;
  final String currency;
  final String selectedTheme;
  final void Function(TxItem) onTapItem;

  const _DayRecordsSheet({
    required this.date,
    required this.dayItems,
    required this.language,
    required this.currency,
    required this.selectedTheme,
    required this.onTapItem,
  });

  String _dateLabel() {
    if (language == 'ko') {
      return '${date.year}년 ${date.month}월 ${date.day}일';
    }
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...dayItems]..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.id.compareTo(a.id);
      });

    final isMB = selectedTheme == 'minimal_black';
    final isCA = selectedTheme == 'cyber_ai';
    return Container(
      decoration: BoxDecoration(
        color: isCA ? const Color(0xFF0F0F2A) : (isMB ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isCA ? const Color(0xFF2A2A5A) : (isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateLabel(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: (isCA || isMB) ? Colors.white : const Color(0xFF24364A),
                      ),
                    ),
                  ),
                  Text(
                    '${sortedItems.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCA ? const Color(0xFF6B6B9A) : (isMB ? const Color(0xFF888888) : const Color(0xFF75879A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (sortedItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Image.asset(
                      themeImage(selectedTheme, 'no_data'),
                      width: 72,
                      height: 72,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('calendar_empty_day', language),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF75879A),
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final x = sortedItems[i];
                    final sign = x.isExpense ? '-' : '+';
                    final amountText = formatCurrencyValue(
                      x.amount,
                      effectiveItemCurrency(x, currency),
                    );
                    return Container(
                      decoration: BoxDecoration(
                        color: isCA ? const Color(0xFF1A1A3A) : (isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD)),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: isCA ? const Color(0xFF2A2A5A) : (isMB ? const Color(0xFF333333) : const Color(0xFFDCE6F0))),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          onTapItem(x);
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCA ? const Color(0xFF0F0F2A) : (isMB ? const Color(0xFF1E1E1E) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isCA ? const Color(0xFF2A2A5A) : (isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
                          ),
                          child: categoryIconWidget(
                            rawCategory: x.category,
                            isCyberAI: isCA,
                            emojiSize: 24,
                            imageSize: 28,
                          ),
                        ),
                        title: Text(
                          x.note.isEmpty ? t('no_memo', language) : x.note,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: (isCA || isMB) ? Colors.white : const Color(0xFF223B36),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isCA ? categoryTextNoEmoji(x.category, language) : categoryText(x.category, language),
                            style: TextStyle(
                              fontSize: 13,
                              color: isCA ? const Color(0xFF6B6B9A) : (isMB ? const Color(0xFF888888) : const Color(0xFF75879A)),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCA
                                ? (x.isExpense ? const Color(0xFF2A1A2A) : const Color(0xFF0A1A2A))
                                : (isMB
                                    ? (x.isExpense ? const Color(0xFF2A1A1A) : const Color(0xFF1A2A1E))
                                    : (x.isExpense ? const Color(0xFFFFF1F0) : const Color(0xFFEFFAF5))),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$sign$amountText',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: x.isExpense
                                  ? const Color(0xFFB4544A)
                                  : const Color(0xFF1C8B65),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('close', language)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
