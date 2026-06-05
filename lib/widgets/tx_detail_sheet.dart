import 'package:flutter/material.dart';

import '../models/tx_item.dart';
import '../utils/i18n.dart';
import '../utils/currency_utils.dart';

class TxDetailSheet extends StatelessWidget {
  final TxItem item;
  final String language;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const TxDetailSheet({
    super.key,
    required this.item,
    required this.language,
    required this.currency,
    required this.onEdit,
    this.onDelete,
  });

  String _paymentLabel() {
    switch (item.paymentMethod) {
      case 'card':
        return t('card', language);
      case 'cash':
        return t('cash', language);
      case 'bank':
        return t('bank', language);
      default:
        return item.paymentMethod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${item.date.year}-'
        '${item.date.month.toString().padLeft(2, '0')}-'
        '${item.date.day.toString().padLeft(2, '0')}';
    final amt = formatCurrencyValue(
      item.amount,
      effectiveItemCurrency(item, currency),
    );
    final sign = item.isExpense ? '-' : '+';
    final amtColor = item.isExpense
        ? const Color(0xFFB4544A)
        : const Color(0xFF1C8B65);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD9E4EE)),
                  ),
                  child: Text(
                    item.category.split(' ').first,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('tx_detail', language),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF75879A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.note.isEmpty
                            ? t('no_memo', language)
                            : item.note,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF24364A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$sign$amt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: amtColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.category_rounded,
              text: categoryText(item.category, language),
            ),
            _DetailRow(
              icon: item.isExpense
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              text: item.isExpense
                  ? t('expense', language)
                  : t('income', language),
              textColor: item.isExpense
                  ? const Color(0xFFB4544A)
                  : const Color(0xFF1C8B65),
            ),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              text: dateStr,
            ),
            if (item.paymentMethod.isNotEmpty)
              _DetailRow(
                icon: Icons.payment_rounded,
                text: _paymentLabel(),
              ),
            if (item.entryCurrency.isNotEmpty)
              _DetailRow(
                icon: Icons.currency_exchange_rounded,
                text: item.entryCurrency,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                    child: Text(t('edit', language)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: onDelete != null
                      ? FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFECE8),
                            foregroundColor: const Color(0xFFB4544A),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete!();
                          },
                          child: Text(t('delete', language)),
                        )
                      : FilledButton.tonal(
                          onPressed: () => Navigator.pop(context),
                          child: Text(t('close', language)),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? textColor;

  const _DetailRow({required this.icon, required this.text, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF75879A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor ?? const Color(0xFF24364A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
