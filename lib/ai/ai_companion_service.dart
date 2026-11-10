import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../companion/companion_text.dart';
import '../companion/insight.dart';
import '../companion/money_insight_engine.dart';
import 'ai_context.dart';
import 'ai_entitlement.dart';
import 'ai_models.dart';

/// Answers a companion question. The UI and controller don't know or care
/// which implementation answered.
abstract interface class AiCompanionService {
  /// Throws [AiException] when no answer is available.
  Future<AiReply> ask(AiRequest request);
}

// ─────────────────────────────── remote ───────────────────────────────

/// Minimal HTTP response, so tests can fake the network.
class AiHttpResponse {
  const AiHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

typedef AiHttpPost = Future<AiHttpResponse> Function(
    Uri url, Map<String, String> headers, String body, Duration timeout);

/// Calls the Doni Money AI proxy (never OpenAI directly). The proxy holds
/// the provider key, the instructions and the model choice.
class RemoteAiCompanionService implements AiCompanionService {
  RemoteAiCompanionService({
    required this.endpoint,
    required this.installId,
    required this.entitlement,
    AiHttpPost? post,
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 1,
  }) : _post = post ?? _ioPost;

  final Uri? endpoint;

  /// Random per-install id used only for server-side rate limiting.
  final String installId;

  /// App Store-signed proof of Premium, sent with every request.
  final AiEntitlementProof entitlement;
  final Duration timeout;
  final int maxRetries;
  final AiHttpPost _post;

  /// Request bodies above this are refused on the device (the proxy
  /// refuses them too).
  static const maxBodyBytes = 12 * 1024;

  @override
  Future<AiReply> ask(AiRequest request) async {
    final url = endpoint;
    if (url == null) throw const AiException(AiFailure.notConfigured);
    if (request.question.trim().isEmpty ||
        request.question.length > AiLimits.maxQuestionChars) {
      throw const AiException(AiFailure.blocked);
    }
    final body = jsonEncode(request.toJson());
    if (utf8.encode(body).length > maxBodyBytes) throw const AiException(AiFailure.blocked);
    // No verifiable subscription: don't send anything.
    final proof = await entitlement();
    if (proof == null || proof.isEmpty) throw const AiException(AiFailure.notEntitled);

    var attempt = 0;
    while (true) {
      try {
        return await _once(url, body, proof);
      } on AiException catch (e) {
        if (!e.isTransient || attempt >= maxRetries) rethrow;
        attempt++;
      }
    }
  }

  Future<AiReply> _once(Uri url, String body, String proof) async {
    final AiHttpResponse res;
    try {
      res = await _post(
        url,
        {
          'Content-Type': 'application/json',
          'X-Install-Id': installId,
          'X-Apple-Signed-Transaction': proof,
        },
        body,
        timeout,
      );
    } on TimeoutException {
      throw const AiException(AiFailure.timeout);
    } on SocketException {
      throw const AiException(AiFailure.offline);
    } on HttpException {
      throw const AiException(AiFailure.unavailable);
    } on HandshakeException {
      throw const AiException(AiFailure.unavailable);
    }

    if (res.statusCode == 403) throw const AiException(AiFailure.notEntitled);
    if (res.statusCode == 429) throw const AiException(AiFailure.rateLimited);
    if (res.statusCode == 504) throw const AiException(AiFailure.timeout);
    if (res.statusCode != 200) throw const AiException(AiFailure.unavailable);
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException {
      throw const AiException(AiFailure.malformed);
    }
    return AiReply.parse(decoded);
  }

  static Future<AiHttpResponse> _ioPost(
      Uri url, Map<String, String> headers, String body, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(url).timeout(timeout);
      headers.forEach(req.headers.set);
      req.add(utf8.encode(body));
      final res = await req.close().timeout(timeout);
      // The proxy's reply is small; cap what we read anyway.
      final bytes = <int>[];
      await for (final chunk in res.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 64 * 1024) throw const HttpException('response too large');
      }
      return AiHttpResponse(res.statusCode, utf8.decode(bytes, allowMalformed: true));
    } finally {
      client.close(force: true);
    }
  }
}

// ─────────────────────────────── local ───────────────────────────────

/// On-device answers from [MoneyInsightEngine]: used when AI Conversation is
/// off, unavailable or failing. No network and no free-text understanding:
/// the question's topic (chosen on the device) picks a local answer.
class LocalAiCompanionService implements AiCompanionService {
  const LocalAiCompanionService({required this.input});

  final InsightInput Function() input;

  @override
  Future<AiReply> ask(AiRequest request) async =>
      replyFor(_questionFor(request.context.topic), request.language);

  Insight insightFor(MoneyQuestion? question) {
    const engine = MoneyInsightEngine();
    final data = input();
    if (question != null) return engine.answer(question, data);
    return engine.generate(data).first;
  }

  AiReply replyFor(MoneyQuestion? question, String language) {
    final insight = insightFor(question);
    return AiReply(answer: insightText(insight, language), mood: insight.mood);
  }

  static MoneyQuestion? _questionFor(AiTopic topic) => switch (topic) {
        AiTopic.overview || AiTopic.budget => MoneyQuestion.monthStatus,
        AiTopic.categories => MoneyQuestion.topCategory,
        AiTopic.comparison => MoneyQuestion.compareLastMonth,
        AiTopic.week || AiTopic.recurring => null,
      };
}
