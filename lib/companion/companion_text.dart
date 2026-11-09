import '../utils/currency_utils.dart';
import '../utils/i18n.dart';
import 'companion_character.dart';
import 'insight.dart';

/// Localized sentence for an insight: the translated template with each
/// `{name}` filled from [Insight.args]. Amounts use their own currency's
/// format; categories use the translated category name.
///
/// With a [character], the sentence gets that character's tone:
/// 1. an optional character-specific template (`<key>_<characterId>`, e.g.
///    Cyber AI's shorter analytical wording), falling back to the base key;
/// 2. a small per-character wrapper chosen by [Insight.mood]
///    (`tone_<characterId>_<mood>`, containing `{text}`).
/// Both are filled from the same [Insight.args], so facts and numbers are
/// identical for every character; only the presentation changes.
String insightText(Insight insight, String language, {CompanionCharacter? character}) {
  var text = _template(insight.localizationKey, language, character);
  insight.args.forEach((name, value) {
    text = text.replaceAll('{$name}', _format(value, language));
  });
  if (insight.currencyScoped && insight.currency != null) {
    text = '$text (${insight.currency})';
  }
  if (character == null) return text;
  final wrapperKey = 'tone_${character.id}_${insight.mood.name}';
  final wrapper = t(wrapperKey, language);
  if (wrapper == wrapperKey || !wrapper.contains('{text}')) return text;
  return wrapper.replaceAll('{text}', text);
}

/// Character-specific template key, if one exists for this insight.
String toneKey(String key, CompanionCharacter character) => '${key}_${character.id}';

String _template(String key, String language, CompanionCharacter? character) {
  if (character != null) {
    final override = toneKey(key, character);
    final text = t(override, language);
    if (text != override) return text;
  }
  return t(key, language);
}

String _format(Object value, String language) {
  if (value is InsightAmount) return formatCurrencyValue(value.value, value.currency);
  if (value is InsightCategory) return categoryTextNoEmoji(value.raw, language);
  return value.toString();
}
