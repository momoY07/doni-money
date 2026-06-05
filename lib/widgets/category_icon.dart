import 'package:flutter/material.dart';

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

/// Shows a cy_cat PNG for cyber_ai theme, emoji Text for all others.
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
  return Text(
    rawCategory.split(' ').first,
    style: TextStyle(fontSize: emojiSize),
  );
}
