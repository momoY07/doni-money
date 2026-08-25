import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../models/currency_summary.dart';
import '../utils/i18n.dart';
import '../utils/currency_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';

class StatsPage extends StatelessWidget {
  final List<TxItem> items;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final String language;
  final String currency;
  final String selectedTheme;
  final double cumulativeBalance;
  final bool hasHistoryMixedCurrencies;
  final Map<String, double> cumulativeBalanceByCurrency;
  final Map<String, double> carryoverByCurrency;

  const StatsPage({
    super.key,
    required this.items,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.language,
    required this.currency,
    required this.selectedTheme,
    required this.cumulativeBalance,
    required this.hasHistoryMixedCurrencies,
    required this.cumulativeBalanceByCurrency,
    required this.carryoverByCurrency,
  });

  bool get _isMB => selectedTheme == 'minimal_black';
  bool get _isCA => selectedTheme == 'cyber_ai';

  String _formatMoney(double amount) {
    return formatCurrencyValue(amount, currency);
  }

  Widget _buildCumulativeByCurrencyRows() {
    final sortedEntries = cumulativeBalanceByCurrency.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sortedEntries.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(
            children: [
              Text(
                sortedEntries[i].key,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF8A7440)),
                ),
              ),
              const Spacer(),
              Text(
                formatCurrencyValue(sortedEntries[i].value, sortedEntries[i].key),
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: (_isCA || _isMB) ? Colors.white : const Color(0xFF5C4A1C),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _showCategoryEntriesSheet(
    BuildContext context,
    List<TxItem> monthItems,
    String rawCategory,
  ) async {
    final categoryItems =
        monthItems
            .where((x) => x.isExpense && x.category == rawCategory)
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            if (byDate != 0) return byDate;
            return b.id.compareTo(a.id);
          });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFEAF1F8)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.category_rounded,
                      color: _isCA ? const Color(0xFF00D4FF) : (_isMB ? const Color(0xFFC9A043) : const Color(0xFF5F7FA3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${t('category_entries', language)} · ${categoryText(rawCategory, language)}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (categoryItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(t('no_entries_in_category', language)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: categoryItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final x = categoryItems[index];
                      final date =
                          '${x.date.year}-${x.date.month.toString().padLeft(2, '0')}-${x.date.day.toString().padLeft(2, '0')}';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
                          ),
                          child: categoryIconWidget(
                            rawCategory: x.category,
                            isCyberAI: _isCA,
                            emojiSize: 22,
                            imageSize: 26,
                          ),
                        ),
                        title: Text(
                          x.note.isEmpty ? categoryTextNoEmoji(x.category, language) : x.note,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(date),
                        trailing: Text(
                          _formatMoney(x.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB4544A),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('close', language)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, String monthLabel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset(themeImage(selectedTheme, 'nav_stats'), width: 34, height: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: onPrevMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
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
                color: iconBgColor,
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
              color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixedCurrencySummaryCard({
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
              t('monthly_summary', language),
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
                            '${t('income', language)} ${formatCurrencyValue(s.income, s.currency)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF179C63),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${t('expense', language)} ${formatCurrencyValue(s.expense, s.currency)}',
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
                      '${t('balance', language)} ${formatCurrencyValue(s.balance, s.currency)}',
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

  Widget _buildDeltaCard({
    required String title,
    required String value,
    required bool positive,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isCA
            ? const Color(0xFF1A1A3A)
            : (_isMB
                ? const Color(0xFF1E1E1E)
                : (positive ? const Color(0xFFEFFAF5) : const Color(0xFFFFF4F2))),
        borderRadius: BorderRadius.circular(18),
        border: (_isCA || _isMB) ? Border.all(color: _isCA ? const Color(0xFF2A2A5A) : const Color(0xFF333333)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: positive
                  ? const Color(0xFF1C8B65)
                  : const Color(0xFFB4544A),
            ),
          ),
        ],
      ),
    );
  }

  Color _chartColor(int index) {
    if (_isCA) {
      const caColors = [
        Color(0xFF7B2FFF),
        Color(0xFF00D4FF),
        Color(0xFF9B5FFF),
        Color(0xFF00AACC),
        Color(0xFFBB7FFF),
        Color(0xFF40E0FF),
        Color(0xFF5500CC),
        Color(0xFF0099AA),
      ];
      return caColors[index % caColors.length];
    }
    const colors = [
      Color(0xFF5F7FA3),
      Color(0xFF8ED9C8),
      Color(0xFFEDD174),
      Color(0xFFF3A683),
      Color(0xFFA29BFE),
      Color(0xFF81ECEC),
      Color(0xFFFFA8A8),
      Color(0xFF74B9FF),
    ];
    return colors[index % colors.length];
  }

  Widget _buildCombinedDistributionCard({
    required BuildContext context,
    required List<MapEntry<String, double>> sortedCategories,
    required double totalExpense,
    required List<TxItem> monthItems,
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
              t('expense_distribution', language),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('tap_category_to_view', language),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF75879A)),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartSize = constraints.maxWidth < 380 ? 150.0 : 170.0;
                final isNarrow = constraints.maxWidth < 430;

                return Column(
                  children: [
                    if (isNarrow)
                      Center(
                        child: SizedBox(
                          width: chartSize,
                          height: chartSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sections: sortedCategories.asMap().entries
                                      .map(
                                        (e) => PieChartSectionData(
                                          value: e.value.value,
                                          color: _chartColor(e.key),
                                          radius: chartSize * 0.16,
                                          showTitle: false,
                                        ),
                                      )
                                      .toList(),
                                  centerSpaceRadius: chartSize * 0.32,
                                  sectionsSpace:
                                      sortedCategories.length == 1 ? 0 : 2,
                                  startDegreeOffset: -90,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t('expense', language),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF75879A)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMoney(totalExpense),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: chartSize,
                            height: chartSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sections: sortedCategories.asMap().entries
                                        .map(
                                          (e) => PieChartSectionData(
                                            value: e.value.value,
                                            color: _chartColor(e.key),
                                            radius: chartSize * 0.16,
                                            showTitle: false,
                                          ),
                                        )
                                        .toList(),
                                    centerSpaceRadius: chartSize * 0.32,
                                    sectionsSpace:
                                        sortedCategories.length == 1 ? 0 : 2,
                                    startDegreeOffset: -90,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      t('expense', language),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF75879A)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatMoney(totalExpense),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: sortedCategories.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final rawCategory = entry.value.key;
                                final amount = entry.value.value;
                                final ratio = totalExpense <= 0
                                    ? 0.0
                                    : amount / totalExpense;
                                final widthFactor = ratio.clamp(0.0, 1.0);

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == sortedCategories.length - 1
                                        ? 0
                                        : 10,
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      await _showCategoryEntriesSheet(
                                        context,
                                        monthItems,
                                        rawCategory,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD)),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFDCE6F0)),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: _chartColor(index),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              categoryIconWidget(
                                                rawCategory: rawCategory,
                                                isCyberAI: _isCA,
                                                imageSize: 20,
                                                emojiSize: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  categoryTextNoEmoji(
                                                    rawCategory,
                                                    language,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _formatMoney(amount),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFFB4544A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${(widthFactor * 100).toStringAsFixed(1)}%',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF75879A),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: Container(
                                              height: 8,
                                              color: const Color(0xFFE8F2EF),
                                              alignment: Alignment.centerLeft,
                                              child: FractionallySizedBox(
                                                widthFactor: widthFactor,
                                                child: Container(
                                                  height: 8,
                                                  color: _chartColor(index),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    if (isNarrow) ...[
                      const SizedBox(height: 16),
                      Column(
                        children: sortedCategories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final rawCategory = entry.value.key;
                          final amount = entry.value.value;
                          final ratio = totalExpense <= 0
                              ? 0.0
                              : amount / totalExpense;
                          final widthFactor = ratio.clamp(0.0, 1.0);

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == sortedCategories.length - 1
                                  ? 0
                                  : 10,
                            ),
                            child: InkWell(
                              onTap: () async {
                                await _showCategoryEntriesSheet(
                                  context,
                                  monthItems,
                                  rawCategory,
                                );
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD)),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFDCE6F0)),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _chartColor(index),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        categoryIconWidget(
                                          rawCategory: rawCategory,
                                          isCyberAI: _isCA,
                                          imageSize: 20,
                                          emojiSize: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            categoryTextNoEmoji(rawCategory, language),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _formatMoney(amount),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFB4544A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${(widthFactor * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF75879A)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        height: 8,
                                        color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFE8F2EF)),
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: widthFactor,
                                          child: Container(
                                            height: 8,
                                            color: _chartColor(index),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetTrendCard(BuildContext context) {
    final spots = <FlSpot>[];
    final labels = <String>[];
    double minY = 0;
    double maxY = 0;

    for (int i = 5; i >= 0; i--) {
      int mYear = selectedMonth.year;
      int mMonth = selectedMonth.month - i;
      while (mMonth <= 0) {
        mMonth += 12;
        mYear--;
      }
      final m = DateTime(mYear, mMonth);
      final monthItems = items.where(
        (x) => x.date.year == m.year && x.date.month == m.month,
      );
      final income = monthItems
          .where((x) => !x.isExpense)
          .fold(0.0, (s, x) => s + x.amount);
      final expense = monthItems
          .where((x) => x.isExpense)
          .fold(0.0, (s, x) => s + x.amount);
      final balance = income - expense;

      final xVal = (5 - i).toDouble();
      spots.add(FlSpot(xVal, balance));
      labels.add('${m.month}${language == 'ko' ? '월' : ''}');

      if (balance < minY) minY = balance;
      if (balance > maxY) maxY = balance;
    }

    final padding = ((maxY - minY) * 0.2).abs().clamp(100.0, double.infinity);
    final yMin = minY - padding;
    final yMax = maxY + padding;

    String formatYLabel(double v) {
      final sym = currencySymbol(currency);
      final abs = v.abs();
      final sign = v < 0 ? '-' : '';
      if (abs >= 1000000) {
        return '$sign$sym${(abs / 1000000).toStringAsFixed(1)}M';
      }
      if (abs >= 1000) {
        return '$sign$sym${(abs / 1000).toStringAsFixed(1)}K';
      }
      return '$sign$sym${abs.toStringAsFixed(0)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('asset_trend', language),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: minY < 0 ? yMin : 0,
                maxY: yMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFE8F0F7)),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: () {
                        final lo = minY < 0 ? yMin : 0;
                        final range = yMax - lo;
                        return range > 0 ? range / 4 : 1.0;
                      }(),
                      getTitlesWidget: (value, meta) {
                        final labelColor = _isCA
                            ? const Color(0xFF6B6B9A)
                            : (_isMB ? const Color(0xFF888888) : const Color(0xFF75879A));
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            formatYLabel(value),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (value != idx.toDouble()) return const SizedBox.shrink();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF75879A),
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: _isCA ? const Color(0xFF7B2FFF) : const Color(0xFF5F7FA3),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    shadow: _isCA
                        ? const Shadow(
                            color: Color(0xFF7B2FFF),
                            blurRadius: 8,
                          )
                        : const Shadow(color: Colors.transparent),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: _isCA ? const Color(0xFF00D4FF) : Colors.white,
                            strokeWidth: 2.5,
                            strokeColor: _isCA ? const Color(0xFF00D4FF) : const Color(0xFF5F7FA3),
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _isCA
                          ? const Color(0xFF7B2FFF).withValues(alpha: 0.12)
                          : const Color(0xFF5F7FA3).withValues(alpha: 0.08),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final val = s.y;
                      final formatted = formatCurrencyValue(val.abs(), currency);
                      final sign = val >= 0 ? '+' : '-';
                      return LineTooltipItem(
                        '$sign$formatted',
                        const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = selectedMonth;
    final monthLabel =
        '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

    final monthItems = items.where((x) {
      return x.date.year == now.year && x.date.month == now.month;
    }).toList();

    final monthCurrencies = collectItemCurrencies(
      monthItems,
      fallbackCurrency: currency,
    );
    final hasMixedCurrencies = monthCurrencies.length > 1;

    final monthCurrencySummaries = buildCurrencySummaries(
      monthItems,
      fallbackCurrency: currency,
    );

    final income = monthItems
        .where((x) => !x.isExpense)
        .fold(0.0, (sum, x) => sum + x.amount);

    final expense = monthItems
        .where((x) => x.isExpense)
        .fold(0.0, (sum, x) => sum + x.amount);

    final balance = income - expense;

    final expenseItems = monthItems.where((x) => x.isExpense).toList();

    final categoryTotals = <String, double>{};
    for (final x in expenseItems) {
      categoryTotals[x.category] = (categoryTotals[x.category] ?? 0) + x.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final prevMonth = DateTime(now.year, now.month - 1);

    final prevMonthItems = items.where((x) {
      return x.date.year == prevMonth.year && x.date.month == prevMonth.month;
    }).toList();

    final prevIncome = prevMonthItems
        .where((x) => !x.isExpense)
        .fold(0.0, (sum, x) => sum + x.amount);

    final prevExpense = prevMonthItems
        .where((x) => x.isExpense)
        .fold(0.0, (sum, x) => sum + x.amount);

    final prevMonthCurrencies = collectItemCurrencies(
      prevMonthItems,
      fallbackCurrency: currency,
    );

    final canCompareDelta =
        !hasMixedCurrencies &&
        monthCurrencies.isNotEmpty &&
        (prevMonthItems.isEmpty ||
            (prevMonthCurrencies.length == 1 &&
                prevMonthCurrencies.first == monthCurrencies.first));

    final incomeDelta = income - prevIncome;
    final expenseDelta = expense - prevExpense;

    if (monthItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, monthLabel),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
            decoration: BoxDecoration(
              color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
            ),
            child: Column(
              children: [
                Image.asset(themeImage(selectedTheme, 'no_data'), width: 90, height: 90),
                const SizedBox(height: 12),
                Text(
                  t('no_stats_yet_this_month', language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('add_a_few_entries_first', language),
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
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 월 선택기 ──────────────────────────────────────────────
        _buildHeaderCard(context, monthLabel),
        const SizedBox(height: 16),
        // ── 지출 비율 ──────────────────────────────────────────────
        if (!hasMixedCurrencies && sortedCategories.isNotEmpty) ...[
          _buildCombinedDistributionCard(
            context: context,
            sortedCategories: sortedCategories,
            totalExpense: expense,
            monthItems: monthItems,
          ),
          const SizedBox(height: 16),
        ],
        // ── 자산 추이 ──────────────────────────────────────────────
        _buildAssetTrendCard(context),
        const SizedBox(height: 16),
        // ── 수입 / 지출 카드 ────────────────────────────────────────
        if (hasMixedCurrencies) ...[
          buildMixedCurrencyNotice(
            language: language,
            currencies: monthCurrencies,
          ),
          const SizedBox(height: 16),
        ],
        if (!hasMixedCurrencies) ...[
          Row(
            children: [
              Expanded(
                child: _buildMiniSummaryCard(
                  label: t('income', language),
                  value: _formatMoney(income),
                  icon: Icons.south_west_rounded,
                  iconBgColor: const Color(0xFFE7F7EE),
                  iconColor: const Color(0xFF179C63),
                  caIcon: Icons.arrow_downward,
                  caGlowColor: const Color(0xFF00FF88),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniSummaryCard(
                  label: t('expense', language),
                  value: _formatMoney(expense),
                  icon: Icons.north_east_rounded,
                  iconBgColor: const Color(0xFFFFECE8),
                  iconColor: const Color(0xFFD94B3D),
                  caIcon: Icons.arrow_upward,
                  caGlowColor: const Color(0xFFFF3366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── 이번 달 잔액 ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: _isCA ? const Color(0xFF0D1B3E) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFEDD174)),
              borderRadius: BorderRadius.circular(22),
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
                        t('this_month_balance', language),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF8A7440)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatMoney(balance),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: (_isCA || _isMB) ? Colors.white : const Color(0xFF5C4A1C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF444444) : const Color(0x30000000)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('total_balance', language),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF8A7440)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (!hasHistoryMixedCurrencies)
                        Text(
                          _formatMoney(cumulativeBalance),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: (_isCA || _isMB) ? Colors.white : const Color(0xFF5C4A1C),
                          ),
                        )
                      else
                        _buildCumulativeByCurrencyRows(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else
          _buildMixedCurrencySummaryCard(summaries: monthCurrencySummaries),
        // ── 지난달 비교 ────────────────────────────────────────────
        if (canCompareDelta) const SizedBox(height: 16),
        Container(
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
                  t('compared_to_last_month', language),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDeltaCard(
                        title: t('income', language),
                        value:
                            '${incomeDelta >= 0 ? '+' : '-'}${_formatMoney(incomeDelta.abs())}',
                        positive: incomeDelta >= 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDeltaCard(
                        title: t('expense', language),
                        value:
                            '${expenseDelta >= 0 ? '+' : '-'}${_formatMoney(expenseDelta.abs())}',
                        positive: expenseDelta <= 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── 가장 많이 쓴 카테고리 ──────────────────────────────────
        if (!hasMixedCurrencies && sortedCategories.isNotEmpty)
          InkWell(
            onTap: () async {
              await _showCategoryEntriesSheet(
                context,
                monthItems,
                sortedCategories.first.key,
              );
            },
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                gradient: (_isCA || _isMB) ? null : const LinearGradient(
                  colors: [Color(0xFFF8FFFC), Color(0xFFEFFAF5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : null),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('top_spending_category', language),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : Colors.white),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE))),
                          ),
                          child: categoryIconWidget(
                            rawCategory: sortedCategories.first.key,
                            isCyberAI: _isCA,
                            emojiSize: 26,
                            imageSize: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryTextNoEmoji(sortedCategories.first.key, language),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('of_total_expense', language),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF75879A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatMoney(sortedCategories.first.value),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1C8B65),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              expense <= 0
                                  ? '0%'
                                  : '${((sortedCategories.first.value / expense) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF75879A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

