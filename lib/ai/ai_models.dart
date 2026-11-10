import '../companion/companion_character.dart';
import '../companion/insight.dart';
import 'ai_context.dart';

/// Client-side limits. The backend enforces the same (or stricter) ones.
abstract final class AiLimits {
  static const maxQuestionChars = 300;
  static const maxHistoryTurns = 4;
  static const maxHistoryTextChars = 600;
  static const maxAnswerChars = 1200;
  static const maxFollowUps = 2;
  static const maxFollowUpChars = 120;
}

enum AiRole { user, assistant }

/// One message in the on-device conversation. Never persisted or backed up.
class AiChatTurn {
  const AiChatTurn(this.role, this.text);
  final AiRole role;
  final String text;

  Map<String, Object?> toJson() => {
        'role': role.name,
        'text': text.length > AiLimits.maxHistoryTextChars
            ? text.substring(0, AiLimits.maxHistoryTextChars)
            : text,
      };
}

/// Exactly what is sent to the proxy for one question.
class AiRequest {
  AiRequest({
    required this.question,
    required this.language,
    required this.character,
    required this.context,
    List<AiChatTurn> history = const [],
  }) : history = history.length > AiLimits.maxHistoryTurns
            ? history.sublist(history.length - AiLimits.maxHistoryTurns)
            : List.unmodifiable(history);

  final String question;
  final String language;
  final CompanionCharacter character;
  final AiFinancialContext context;

  /// The last few turns only ([AiLimits.maxHistoryTurns]).
  final List<AiChatTurn> history;

  Map<String, Object?> toJson() => {
        'version': 1,
        'question': question,
        'language': language,
        'character': character.id,
        'history': [for (final h in history) h.toJson()],
        'context': context.json,
      };
}

/// A validated AI reply. Anything that doesn't fit this shape is rejected.
class AiReply {
  const AiReply({
    required this.answer,
    required this.mood,
    this.followUps = const [],
    this.usedContext = const [],
  });

  final String answer;
  final InsightMood mood;
  final List<String> followUps;
  final List<String> usedContext;

  /// Defensive parse of the proxy's JSON. Unknown fields are ignored; wrong
  /// types, empty answers or oversized values throw [AiException.malformed].
  /// Never returns raw server text that failed validation.
  static AiReply parse(Object? json) {
    if (json is! Map) throw const AiException(AiFailure.malformed);
    final answer = json['answer'];
    if (answer is! String) throw const AiException(AiFailure.malformed);
    final trimmed = answer.trim();
    if (trimmed.isEmpty || trimmed.length > AiLimits.maxAnswerChars) {
      throw const AiException(AiFailure.malformed);
    }

    final moodRaw = json['mood'];
    final mood = InsightMood.values.where((m) => m.name == moodRaw).firstOrNull;
    if (mood == null) throw const AiException(AiFailure.malformed);

    List<String> strings(Object? v, {required int max, required int maxChars}) {
      if (v == null) return const [];
      if (v is! List) throw const AiException(AiFailure.malformed);
      final out = <String>[];
      for (final s in v) {
        if (s is! String) throw const AiException(AiFailure.malformed);
        final x = s.trim();
        if (x.isEmpty || x.length > maxChars) continue;
        out.add(x);
        if (out.length == max) break;
      }
      return out;
    }

    final followUps =
        strings(json['followUps'], max: AiLimits.maxFollowUps, maxChars: AiLimits.maxFollowUpChars);
    final used = strings(json['usedContext'], max: 8, maxChars: 40)
        .where(AiContextSection.all.contains)
        .toList();
    return AiReply(answer: trimmed, mood: mood, followUps: followUps, usedContext: used);
  }
}

/// Why an AI answer isn't available. UI maps each to a short localized line
/// and keeps the local companion available.
enum AiFailure {
  /// No proxy URL configured in this build.
  notConfigured,
  offline,
  timeout,
  rateLimited,
  unavailable,
  malformed,

  /// Refused on the device before any request (consent off, not Premium,
  /// question too long, cooldown, already sending).
  blocked,
}

class AiException implements Exception {
  const AiException(this.failure);
  final AiFailure failure;

  /// Worth one automatic retry.
  bool get isTransient =>
      failure == AiFailure.timeout || failure == AiFailure.offline || failure == AiFailure.unavailable;

  @override
  String toString() => 'AiException(${failure.name})';
}
