import 'package:flutter/material.dart';
import '../storage.dart';

// ─── cyber_ai (legacy) ────────────────────────────────────────────────────────
// cyIconPath() is no longer called by categoryIconWidget.
// Kept until cy_cat_*.png assets in assets/images/cyber_ai/ are cleaned up.
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

// ─── categories PNG (cyber / otter / dog) ─────────────────────────────────────
// Shared map — file names are identical across cyber/, otter/, and dog/ folders.
const Map<String, String> _catFileMap = {
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

/// Returns the assets/images/categories/ subfolder for the given theme,
/// or null if the theme uses emoji (minimal_black).
/// Blacklist approach: unknown/future/default themes fall through to 'otter'.
String? catFolderForTheme(String theme) {
  if (theme == 'minimal_black') return null;
  if (theme == 'cyber_ai') return 'cyber';
  if (theme.contains('dog')) return 'dog';
  return 'otter';
}

String catIconPath(String rawCategory, String folder) {
  final name = rawCategory.contains(' ')
      ? rawCategory.substring(rawCategory.indexOf(' ') + 1)
      : rawCategory;
  final file = _catFileMap[name] ?? 'other';
  return 'assets/images/categories/$folder/$file.png';
}

// ─── shared widget ────────────────────────────────────────────────────────────
Widget categoryIconWidget({
  required String rawCategory,
  required bool isCyberAI,
  double emojiSize = 24,
  double imageSize = 28,
}) {
  final theme =
      Storage.txBox.get('selectedTheme', defaultValue: 'cream') as String;
  final folder = catFolderForTheme(theme);
  if (folder != null) {
    final emoji = rawCategory.split(' ').first;
    return Image.asset(
      catIconPath(rawCategory, folder),
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
