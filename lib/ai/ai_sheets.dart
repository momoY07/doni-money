import 'package:flutter/material.dart';

import '../companion/companion_card.dart';
import '../companion/companion_character.dart';
import '../companion/insight.dart';
import '../utils/i18n.dart';
import 'ai_chat_controller.dart';
import 'ai_models.dart';

// ─────────────────────────────── consent ───────────────────────────────

/// Shown before the first remote AI question (and when turning AI on in
/// Settings). Returns true only if the user tapped "Enable AI Conversation".
Future<bool> showAiConsentSheet(BuildContext context, String language) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('ai_consent_title', language),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            for (final k in const [
              'ai_consent_body_service',
              'ai_consent_body_summary',
              'ai_consent_body_not_sent',
              'ai_consent_body_optional',
            ])
              _Bullet(text: t(k, language)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('ai_consent_whats_shared'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurface),
                onPressed: () => showAiSharedInfoSheet(ctx, language),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: Text(t('ai_whats_shared', language)),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('ai_consent_enable'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t('ai_consent_enable', language)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey('ai_consent_cancel'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('ai_consent_cancel', language)),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

/// Human-readable list of what an AI request contains. Kept in sync with
/// AiFinancialContextBuilder and AiRequest (see ai_context.dart).
Future<void> showAiSharedInfoSheet(BuildContext context, String language) {
  Widget header(String key) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(t(key, language),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('ai_whats_shared', language),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            header('ai_shared_sent_header'),
            for (final k in aiSharedSentKeys) _Bullet(text: t(k, language), icon: Icons.north_east_rounded),
            header('ai_shared_not_header'),
            for (final k in aiSharedNotSentKeys) _Bullet(text: t(k, language), icon: Icons.block_rounded),
            const SizedBox(height: 10),
            Text(t('ai_shared_storage', language),
                style: TextStyle(fontSize: 13, color: Theme.of(ctx).hintColor)),
          ],
        ),
      ),
    ),
  );
}

const aiSharedSentKeys = [
  'ai_shared_sent_question',
  'ai_shared_sent_month',
  'ai_shared_sent_topic',
  'ai_shared_sent_currencies',
  'ai_shared_sent_categories',
  'ai_shared_sent_app',
];

const aiSharedNotSentKeys = [
  'ai_shared_not_transactions',
  'ai_shared_not_notes',
  'ai_shared_not_custom',
  'ai_shared_not_app',
  'ai_shared_not_ids',
];

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, this.icon = Icons.circle});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 10),
            child: Icon(icon, size: icon == Icons.circle ? 7 : 15, color: Theme.of(context).hintColor),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.35))),
        ],
      ),
    );
  }
}

// ─────────────────────────────── chat ───────────────────────────────

/// Localized line for a failure. Always paired with the local insight.
String aiFailureText(AiFailure f, String language) => switch (f) {
      AiFailure.offline => t('ai_error_offline', language),
      AiFailure.timeout => t('ai_error_timeout', language),
      AiFailure.rateLimited => t('ai_error_rate_limited', language),
      AiFailure.notConfigured => t('ai_error_not_configured', language),
      AiFailure.unavailable || AiFailure.malformed || AiFailure.blocked =>
        t('ai_error_generic', language),
    };

/// Opens the compact AI chat. The [controller] is created per opening, so
/// the conversation is cleared when the sheet closes.
Future<void> showAiChatSheet(
  BuildContext context, {
  required AiChatController controller,
  required String language,
  required CompanionCharacter character,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: AiChatSheet(
        controller: controller,
        language: language,
        character: character,
      ),
    ),
  ).whenComplete(controller.dispose);
}

class AiChatSheet extends StatefulWidget {
  const AiChatSheet({
    super.key,
    required this.controller,
    required this.language,
    required this.character,
  });

  final AiChatController controller;
  final String language;
  final CompanionCharacter character;

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  AiChatController get _c => widget.controller;
  String get _lang => widget.language;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text, {MoneyQuestion? quick}) async {
    final result = await _c.send(text, quick: quick);
    if (result == AiSendResult.sent || result == AiSendResult.failed) {
      if (quick == null) _input.clear();
    }
  }

  InsightMood get _lastMood {
    for (final m in _c.messages.reversed) {
      if (m.role == AiRole.assistant) return m.mood;
    }
    return InsightMood.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSend = !_c.sending && _input.text.trim().isNotEmpty;
    final pose = poseForMood(_lastMood);
    final avatar = pose == CompanionPose.happy ? widget.character.happyAsset : widget.character.idleAsset;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Image.asset(avatar, width: 40, height: 40, cacheWidth: 160, gaplessPlayback: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t('ai_conversation_title', _lang),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: t('ai_whats_shared', _lang),
                onPressed: () => showAiSharedInfoSheet(context, _lang),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              IconButton(
                tooltip: t('ai_close', _lang),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              for (var i = 0; i < _c.messages.length; i++)
                _bubble(_c.messages[i], isLast: i == _c.messages.length - 1),
              if (_c.sending)
                _assistantRow(
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(t('ai_thinking', _lang)),
                  ]),
                  key: const ValueKey('ai_loading'),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 8 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final q in MoneyQuestion.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(t(q.labelKey, _lang)),
                            onPressed: _c.sending ? null : () => _send(t(q.labelKey, _lang), quick: q),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('ai_input'),
                        controller: _input,
                        maxLength: AiLimits.maxQuestionChars,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) => canSend ? _send(v) : null,
                        decoration: InputDecoration(
                          hintText: t('ai_input_hint', _lang),
                          counterText: _input.text.length > AiLimits.maxQuestionChars - 50
                              ? null
                              : '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      key: const ValueKey('ai_send'),
                      tooltip: t('ai_send', _lang),
                      onPressed: canSend ? () => _send(_input.text) : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
                Text(
                  t('ai_disclaimer', _lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(AiChatMessage m, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    if (m.role == AiRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(m.text, style: TextStyle(color: scheme.onPrimaryContainer)),
        ),
      );
    }

    final failure = m.failure;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failure != null) ...[
          Text(aiFailureText(failure, _lang),
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error)),
          if (m.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t('ai_local_label', _lang),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(m.text),
          ],
          if (isLast && _c.canRetry)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('ai_retry'),
                style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
                onPressed: _c.retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(t('ai_retry', _lang)),
              ),
            ),
        ] else
          Text(m.text),
        if (failure == null && isLast && m.followUps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in m.followUps)
                ActionChip(label: Text(f), onPressed: _c.sending ? null : () => _send(f)),
            ],
          ),
        ],
      ],
    );
    return _assistantRow(content, mood: m.mood);
  }

  Widget _assistantRow(Widget child, {InsightMood mood = InsightMood.neutral, Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    final asset = poseForMood(mood) == CompanionPose.happy
        ? widget.character.happyAsset
        : widget.character.idleAsset;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(asset, width: 30, height: 30, cacheWidth: 120),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
