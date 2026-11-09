import '../utils/currency_utils.dart';
import '../utils/i18n.dart';
import 'insight.dart';

/// Localized sentence for an insight: the translated template with each
/// `{name}` filled from [Insight.args]. Amounts use their own currency's
/// format; categories use the translated category name.
String insightText(Insight insight, String language) {
  var text = t(insight.localizationKey, language);
  insight.args.forEach((name, value) {
    text = text.replaceAll('{$name}', _format(value, language));
  });
  if (insight.currencyScoped && insight.currency != null) {
    text = '$text (${insight.currency})';
  }
  return text;
}

String _format(Object value, String language) {
  if (value is InsightAmount) return formatCurrencyValue(value.value, value.currency);
  if (value is InsightCategory) return categoryTextNoEmoji(value.raw, language);
  return value.toString();
}
