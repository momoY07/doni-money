import 'package:flutter/foundation.dart';

import '../companion/companion_character.dart';
import '../companion/insight.dart';
import 'ai_companion_service.dart';
import 'ai_context.dart';
import 'ai_models.dart';

/// One bubble in the chat sheet.
class AiChatMessage {
  const AiChatMessage.user(this.text)
      : role = AiRole.user,
        mood = InsightMood.neutral,
        followUps = const [],
        failure = null,
        isLocal = false;

  AiChatMessage.assistant(AiReply reply, {this.isLocal = false})
      : role = AiRole.assistant,
        text = reply.answer,
        mood = reply.mood,
        followUps = reply.followUps,
        failure = null;

  /// AI unavailable: [text] is the local companion's answer (may be empty).
  const AiChatMessage.failure(AiFailure this.failure, {required this.text, required this.mood})
      : role = AiRole.assistant,
        followUps = const [],
        isLocal = true;

  final AiRole role;
  final String text;
  final InsightMood mood;
  final List<String> followUps;
  final AiFailure? failure;

  /// Answered on the device, not by AI.
  final bool isLocal;
}

enum AiSendResult { sent, failed, needsConsent, blocked }

/// Conversation state for the chat sheet. History lives only in memory for
/// this session; it is never persisted, backed up or stored on the server.
class AiChatController extends ChangeNotifier {
  AiChatController({
    required this.remote,
    required this.local,
    required this.isPremium,
    required this.isEnabled,
    required this.buildContext,
    required this.language,
    required this.character,
    DateTime Function()? clock,
    this.cooldown = const Duration(seconds: 3),
  }) : _clock = clock ?? DateTime.now;

  final AiCompanionService remote;
  final AiCompanionService local;
  final bool Function() isPremium;

  /// Current AI consent; checked before sending and again before showing
  /// a reply, so turning AI off takes effect immediately.
  final bool Function() isEnabled;
  final AiFinancialContext Function(AiTopic topic) buildContext;
  final String Function() language;
  final CompanionCharacter Function() character;
  final Duration cooldown;
  final DateTime Function() _clock;

  final List<AiChatMessage> _messages = [];
  bool _sending = false;
  DateTime? _lastSentAt;
  String? _retryText;
  MoneyQuestion? _retryQuick;

  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get canRetry => !_sending && _retryText != null;

  Future<AiSendResult> send(String text, {MoneyQuestion? quick}) =>
      _send(text, quick: quick, isRetry: false);

  /// Sends the last failed question again (one manual retry per failure).
  Future<AiSendResult> retry() async {
    final text = _retryText;
    if (text == null || _sending) return AiSendResult.blocked;
    if (_messages.isNotEmpty && _messages.last.failure != null) _messages.removeLast();
    if (_messages.isNotEmpty && _messages.last.role == AiRole.user) _messages.removeLast();
    return _send(text, quick: _retryQuick, isRetry: true);
  }

  Future<AiSendResult> _send(String raw, {MoneyQuestion? quick, required bool isRetry}) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > AiLimits.maxQuestionChars) return AiSendResult.blocked;
    if (_sending || !isPremium()) return AiSendResult.blocked;
    if (!isEnabled()) return AiSendResult.needsConsent;
    final now = _clock();
    if (!isRetry && _lastSentAt != null && now.difference(_lastSentAt!) < cooldown) {
      return AiSendResult.blocked;
    }

    // Context is decided here, on the device, before anything is sent. The
    // question text only picks a topic; it cannot add data.
    final topic = quick != null ? topicForQuickQuestion(quick) : topicForQuestion(text);
    final request = AiRequest(
      question: text,
      language: language(),
      character: character(),
      context: buildContext(topic),
      history: [
        for (final m in _messages)
          if (m.failure == null && !m.isLocal) AiChatTurn(m.role, m.text),
      ],
    );

    _messages.add(AiChatMessage.user(text));
    _sending = true;
    _lastSentAt = now;
    _retryText = null;
    notifyListeners();

    try {
      final reply = await remote.ask(request);
      if (!isEnabled()) {
        // Turned off while waiting: discard the reply.
        _sending = false;
        notifyListeners();
        return AiSendResult.blocked;
      }
      _messages.add(AiChatMessage.assistant(reply));
      _sending = false;
      notifyListeners();
      return AiSendResult.sent;
    } on AiException catch (e) {
      AiReply? fallback;
      try {
        fallback = await local.ask(request);
      } catch (_) {
        fallback = null;
      }
      _messages.add(AiChatMessage.failure(
        e.failure,
        text: fallback?.answer ?? '',
        mood: fallback?.mood ?? InsightMood.neutral,
      ));
      _retryText = text;
      _retryQuick = quick;
      _sending = false;
      notifyListeners();
      return AiSendResult.failed;
    }
  }
}
