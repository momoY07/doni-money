import 'package:flutter/material.dart';
import '../storage.dart';

// ─── cyber_ai ─────────────────────────────────────────────────────────────────
// DO NOT MODIFY cyIconPath() — cyber_ai theme relies on this exact logic.
String cyIconPath(String rawCategory) {
  final name = rawCategory.contains(' ')
      ? rawCategory.substring(rawCategory.indexOf(' ') + 1).toLowerCase()
      : rawCategory.toLowerCase();
  if (name.contains('coffee')) return 'assets/images/cyber_ai/cy_cat_coffee.png';
  if (name.contains('grocery')) return 'assets/images/cyber_ai/cy_cat_grocery.png';
  if (name.contains('food')) return 'assets/images/cyber_ai/cy_cat_food.png';
  if (name.contains('shopping')) return 'assets/images/cyber_ai/cy_cat_shopping.png';
  if (name.contains('transport')) return 'assets/images/cyber_ai/cy_cat_transport.png';
  if (name.contains('health')) return 'assets/images/cyber_ai/cy_cat_health.png';
  if (name.contains('entertainment')) return 'assets/images/cyber_ai/cy_cat_entertainment.png';
  if (name.contains('education')) return 'assets/images/cyber_ai/cy_cat_education.png';
  if (name.contains('bills')) return 'assets/images/cyber_ai/cy_cat_bills.png';
  if (name.contains('gift')) return 'assets/images/cyber_ai/cy_cat_gift.png';
  if (name.contains('travel')) return 'assets/images/cyber_ai/cy_cat_travel.png';
  if (name.contains('salary')) return 'assets/images/cyber_ai/cy_cat_salary.png';
  return 'assets/images/cyber_ai/cy_cat_other_1.png';
}

// ─── otter ────────────────────────────────────────────────────────────────────
const Map<String, String> _otterCatMap = {
  'Food': 'food',
  'Coffee': 'coffee',
  'Grocery': 'grocery',
  'Transport': 'transport',
  'Shopping': 'shopping',
  'Bills': 'fixed_expense',
  'Entertainment': 'entertainment',
  'Health': 'health',
  'Gift': 'gift',
  'Travel': 'travel',
  'Phone': 'communication',
  'Car': 'car',
  'Rent': 'rent',
  'Baby': 'baby_supplies',
  'Electricity': 'electricity_bill',
  'Water': 'water_bill',
  'Gas': 'gas_bill',
  'Maintenance': 'maintenance_fee',
  'Internet': 'internet_bill',
  'Investment': 'stocks_investment',
  'Other': 'other',
  'Salary': 'salary',
};

/// Returns true for any theme that is not cyber_ai, minimal_black, or dog.
/// Using blacklist so unknown/default values also resolve to otter.
bool isOtterTheme(String theme) =>
    theme != 'cyber_ai' &&
    theme != 'minimal_black' &&
    !theme.contains('dog');

String otterIconPath(String rawCategory) {
  final name = rawCategory.contains(' ')
      ? rawCategory.substring(rawCategory.indexOf(' ') + 1)
      : rawCategory;
  final file = _otterCatMap[name] ?? 'other';
  return 'assets/images/categories/otter/$file.png';
}

// ─── shared widget ────────────────────────────────────────────────────────────
Widget categoryIconWidget({
  required String rawCategory,
  required bool isCyberAI,
  double emojiSize = 24,
  double imageSize = 28,
}) {
  if (isCyberAI) {
    return Image.asset(
      cyIconPath(rawCategory),
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
    );
  }
  final theme =
      Storage.txBox.get('selectedTheme', defaultValue: 'cream') as String;
  if (isOtterTheme(theme)) {
    final emoji = rawCategory.split(' ').first;
    return Image.asset(
      otterIconPath(rawCategory),
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
      errorBuilder: (_, e, s) =>
          Text(emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }
  return Text(
    rawCategory.split(' ').first,
    style: TextStyle(fontSize: emojiSize),
  );
}
