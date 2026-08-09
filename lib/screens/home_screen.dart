import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../models/currency_summary.dart';
import '../utils/i18n.dart';
import '../utils/currency_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';

class HomePage extends StatelessWidget {
  final double income;
  final double expense;
  final VoidCallback onAdd;
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final String language;
  final String currency;
  final Set<String> monthCurrencies;
  final List<CurrencySummary> currencySummaries;
  final List<TxItem> recentItems;
  final Future<void> Function(TxItem item) onTapRecentItem;
  final Future<void> Function(TxItem item) onLongPressRecentItem;
  final VoidCallback onOpenList;
  final double monthlyBudget;
  final String selectedTheme;
  final double cumulativeBalance;
  final double carryover;

  const HomePage({
    super.key,
    required this.income,
    required this.expense,
    required this.onAdd,
    this.onAddIncome,
    this.onAddExpense,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.language,
    required this.currency,
    required this.monthCurrencies,
    required this.currencySummaries,
    required this.recentItems,
    required this.onTapRecentItem,
    required this.onLongPressRecentItem,
    required this.onOpenList,
    this.monthlyBudget = 0,
    required this.selectedTheme,
    required this.cumulativeBalance,
    this.carryover = 0.0,
  });

  bool get _isMB => selectedTheme == 'minimal_black';
  bool get _isCA => selectedTheme == 'cyber_ai';
  bool get _isDog => selectedTheme.contains('dog');

  String get _homeMessage {
    if (_isCA) return t('home_message_ca', language);
    if (_isMB) return t('home_message_mb', language);
    if (_isDog) return t('home_message_dog', language);
    return t('home_message', language);
  }

  Color get _cardBg => _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : Colors.white);
  Color get _containerBg => _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFD));
  Color get _borderColor => _isCA ? const Color(0xFF2A2A5A) : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE));
  Color get _textPrimary => (_isCA || _isMB) ? Colors.white : const Color(0xFF24364A);
  Color get _textSub => _isCA ? const Color(0xFF6B6B9A) : (_isMB ? const Color(0xFF888888) : const Color(0xFF627487));
  Color get _iconAccent => _isCA ? const Color(0xFF00D4FF) : (_isMB ? const Color(0xFFC9A043) : const Color(0xFF5F7FA3));

  Widget _buildMiniStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    Color? caGlowColor,
    IconData? caIcon,
    VoidCallback? onTap,
  }) {
    final borderCol = (_isCA && caGlowColor != null) ? caGlowColor : _borderColor;
    final iconWidget = (_isCA && caIcon != null && caGlowColor != null)
        ? Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: caGlowColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: caGlowColor.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 0),
              ],
            ),
            child: Icon(caIcon, size: 20, color: caGlowColor),
          )
        : Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          );

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              if (onTap != null) ...[
                const Spacer(),
                Icon(Icons.add_circle_outline_rounded, size: 16, color: _textSub),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textSub),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary),
          ),
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: _containerBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderCol),
      boxShadow: (_isCA && caGlowColor != null)
          ? [BoxShadow(color: caGlowColor.withValues(alpha: 0.45), blurRadius: 6, spreadRadius: 0)]
          : null,
    );

    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }

  Widget _buildCarryoverRow(BuildContext context) {
    final isPositive = carryover >= 0;
    final sign = isPositive ? '+' : '';
    final color = isPositive ? const Color(0xFF179C63) : const Color(0xFFD94B3D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPositive
            ? ((_isCA || _isMB) ? const Color(0xFF0A2A1A) : const Color(0xFFEFFAF5))
            : ((_isCA || _isMB) ? const Color(0xFF2A0A0A) : const Color(0xFFFFF1F0)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPositive
              ? ((_isCA || _isMB) ? const Color(0xFF1A4A2A) : const Color(0xFFC3EAD8))
              : ((_isCA || _isMB) ? const Color(0xFF4A1A1A) : const Color(0xFFEFCDCA)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            t('carried_over', language),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          const Spacer(),
          Text(
            '$sign${formatCurrencyValue(carryover, currency)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetBar(BuildContext context, double expense) {
    final ratio = monthlyBudget <= 0 ? 0.0 : (expense / monthlyBudget);
    final isOver = expense > monthlyBudget;
    final remaining = monthlyBudget - expense;
    final barColor = isOver ? const Color(0xFFD94B3D) : const Color(0xFF179C63);
    final bgColor = isOver ? const Color(0xFFFFF4F2) : const Color(0xFFEFFAF5);
    final labelColor = isOver ? const Color(0xFFB4544A) : const Color(0xFF1C8B65);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_small_rounded, size: 16, color: labelColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t('monthly_budget', language),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: labelColor),
                ),
              ),
              Text(
                isOver ? t('budget_exceeded', language) : '${(ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isOver ? const Color(0xFFFFD5D0) : const Color(0xFFCCEFDE),
              color: barColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatCurrencyValue(expense, currency),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF627487)),
              ),
              const Spacer(),
              Text(
                isOver
                    ? '-${formatCurrencyValue(remaining.abs(), currency)}'
                    : '${t('budget_remaining', language)}: ${formatCurrencyValue(remaining, currency)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: labelColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMixedCurrencySummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('monthly_summary', language),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < currencySummaries.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _containerBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currencySummaries[i].currency,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t('income', language)} ${formatCurrencyValue(currencySummaries[i].income, currencySummaries[i].currency)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF179C63)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${t('expense', language)} ${formatCurrencyValue(currencySummaries[i].expense, currencySummaries[i].currency)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD94B3D)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${t('balance', language)} ${formatCurrencyValue(currencySummaries[i].balance, currencySummaries[i].currency)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _isCA ? const Color(0xFF00D4FF) : (_isMB ? const Color(0xFFC9A043) : const Color(0xFF5C4A1C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
    final hasMixedCurrencies = monthCurrencies.length > 1;

    final isMB = selectedTheme == 'minimal_black';
    final isCA = selectedTheme == 'cyber_ai';
    final useSolidBg = isMB || isCA;
    return Stack(
      children: [
        Positioned.fill(
          child: useSolidBg
              ? Container(color: isCA ? const Color(0xFF0A0A1A) : const Color(0xFF1A1A1A))
              : Image.asset(themeImage(selectedTheme, 'bg_home'), fit: BoxFit.cover),
        ),
        if (!useSolidBg)
          Positioned.fill(child: Container(color: const Color(0x88F6FBF9))),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // ── Main header card ──
            Container(
              decoration: BoxDecoration(
                gradient: (_isMB || _isCA) ? null : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF5FCF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: _isCA ? const Color(0xFF0F0F2A) : (_isMB ? const Color(0xFF1E1E1E) : null),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _borderColor),
                boxShadow: (_isMB || _isCA) ? null : const [
                  BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFEAF1F8)),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(themeImage(selectedTheme, 'mascot'), fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('app_title', language),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textSub),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                monthLabel,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: (_isCA || _isMB) ? Colors.white : const Color(0xFF1E3732),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: _isCA ? const Color(0xFF1A1A3A) : (_isMB ? const Color(0xFF2A2A2A) : Colors.white),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            children: [
                              IconButton(onPressed: onPrevMonth, icon: const Icon(Icons.chevron_left)),
                              IconButton(onPressed: onNextMonth, icon: const Icon(Icons.chevron_right)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _homeMessage,
                      style: TextStyle(
                        fontSize: 16, height: 1.45,
                        color: _textSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!hasMixedCurrencies) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStatCard(
                              context: context,
                              label: t('income', language),
                              value: formatCurrencyValue(income, currency),
                              icon: Icons.south_west_rounded,
                              iconBgColor: const Color(0xFFE7F7EE),
                              iconColor: const Color(0xFF179C63),
                              caGlowColor: _isCA ? const Color(0xFF00FF88) : null,
                              caIcon: Icons.arrow_downward,
                              onTap: onAddIncome,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniStatCard(
                              context: context,
                              label: t('expense', language),
                              value: formatCurrencyValue(expense, currency),
                              icon: Icons.north_east_rounded,
                              iconBgColor: const Color(0xFFFFECE8),
                              iconColor: const Color(0xFFD94B3D),
                              caGlowColor: _isCA ? const Color(0xFFFF3366) : null,
                              caIcon: Icons.arrow_upward,
                              onTap: onAddExpense,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ── Balance card ──
                      if (_isCA)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: [
                              BoxShadow(color: Color(0xFF00D4FF).withValues(alpha: 0.35), blurRadius: 6),
                            ],
                          ),
                          padding: const EdgeInsets.all(1),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1B3E),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF162040),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00D4FF)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('total_balance', language),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B6B9A)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrencyValue(cumulativeBalance, currency),
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _isMB ? const Color(0xFF2A2A2A) : const Color(0xFFEDD174),
                            borderRadius: BorderRadius.circular(20),
                            border: _isMB ? Border.all(color: const Color(0xFF333333)) : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: _isMB ? const Color(0xFF333333) : const Color(0xFFF8EDC3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: _isMB ? const Color(0xFFC9A043) : const Color(0xFF9C7A22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('total_balance', language),
                                      style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                        color: _isMB ? const Color(0xFF888888) : const Color(0xFF8A7440),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatCurrencyValue(cumulativeBalance, currency),
                                      style: TextStyle(
                                        fontSize: 24, fontWeight: FontWeight.w900,
                                        color: _isMB ? Colors.white : const Color(0xFF5C4A1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (carryover != 0.0) ...[
                        const SizedBox(height: 10),
                        _buildCarryoverRow(context),
                      ],
                      if (monthlyBudget > 0) ...[
                        const SizedBox(height: 10),
                        _buildBudgetBar(context, expense),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (hasMixedCurrencies) ...[
              const SizedBox(height: 16),
              buildMixedCurrencyNotice(language: language, currencies: monthCurrencies),
              const SizedBox(height: 16),
              _buildMixedCurrencySummaryCard(),
            ],
            const SizedBox(height: 16),
            // ── Add entry button (outline for CA) ──
            if (_isCA)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF00D4FF), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF00D4FF)),
                  label: Text(t('add_entry', language), style: const TextStyle(color: Color(0xFF00D4FF))),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: const Color(0xFF00D4FF),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t('add_entry', language)),
                ),
              ),
            const SizedBox(height: 16),
            // ── Recent entries card ──
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _isCA ? const Color(0xFF1A1A4A) : _borderColor),
                boxShadow: (_isMB || _isCA) ? null : const [
                  BoxShadow(color: Color(0x10000000), blurRadius: 22, offset: Offset(0, 8)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
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
                          child: Icon(Icons.history_rounded, color: _iconAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t('recent_entries', language),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary),
                          ),
                        ),
                        if (recentItems.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _containerBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Text(
                              '${recentItems.length}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textSub),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (recentItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                        decoration: BoxDecoration(
                          color: _containerBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Column(
                          children: [
                            Image.asset(themeImage(selectedTheme, 'no_data'), width: 72, height: 72),
                            const SizedBox(height: 10),
                            Text(
                              t('no_recent_entries', language),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                            ),
                          ],
                        ),
                      )
                    else
                      ...recentItems.asMap().entries.map((entry) {
                        final i = entry.key;
                        final x = entry.value;
                        final sign = x.isExpense ? '-' : '+';
                        final amt = formatCurrencyValue(x.amount, effectiveItemCurrency(x, currency));
                        final date =
                            '${x.date.year}-${x.date.month.toString().padLeft(2, '0')}-${x.date.day.toString().padLeft(2, '0')}';

                        return Container(
                          margin: EdgeInsets.only(bottom: i == recentItems.length - 1 ? 0 : 10),
                          decoration: BoxDecoration(
                            color: _containerBg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _borderColor),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            onTap: () async { await onTapRecentItem(x); },
                            onLongPress: () async { await onLongPressRecentItem(x); },
                            leading: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _borderColor),
                              ),
                              child: categoryIconWidget(
                                rawCategory: x.category,
                                isCyberAI: _isCA,
                                emojiSize: 24,
                                imageSize: 28,
                              ),
                            ),
                            title: Text(
                              x.note.isEmpty ? categoryTextNoEmoji(x.category, language) : x.note,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                x.note.isEmpty ? date : '${categoryTextNoEmoji(x.category, language)} · $date',
                                style: TextStyle(fontSize: 13, color: _textSub, fontWeight: FontWeight.w600),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: (_isCA || _isMB)
                                    ? _containerBg
                                    : (x.isExpense ? const Color(0xFFFFF1F0) : const Color(0xFFEFFAF5)),
                                borderRadius: BorderRadius.circular(14),
                                border: (_isCA || _isMB) ? Border.all(color: _borderColor) : null,
                              ),
                              child: Text(
                                '$sign$amt',
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800,
                                  color: x.isExpense ? const Color(0xFFB4544A) : const Color(0xFF1C8B65),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
