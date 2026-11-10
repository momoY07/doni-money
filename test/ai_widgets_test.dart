import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_ledger/ai/ai_chat_controller.dart';
import 'package:simple_ledger/ai/ai_companion_service.dart';
import 'package:simple_ledger/ai/ai_context.dart';
import 'package:simple_ledger/ai/ai_models.dart';
import 'package:simple_ledger/ai/ai_sheets.dart';
import 'package:simple_ledger/companion/companion_card.dart';
import 'package:simple_ledger/companion/companion_character.dart';
import 'package:simple_ledger/companion/insight.dart';
import 'package:simple_ledger/companion/money_insight_engine.dart';
import 'package:simple_ledger/utils/i18n.dart';

final _now = DateTime(2026, 11, 18, 10);

InsightInput _input() => InsightInput(
      now: _now,
      budgetCurrency: 'USD',
      transactions: [
        InsightTransaction(date: DateTime(2026, 11, 2), isExpense: true, amount: 42, category: '☕ Coffee', currency: 'USD'),
      ],
    );

class _Fake implements AiCompanionService {
  int calls = 0;
  FutureOr<AiReply> Function() next =
      () => const AiReply(answer: 'You spent 42 USD so far.', mood: InsightMood.positive, followUps: ['Compare with last month?']);
  @override
  Future<AiReply> ask(AiRequest request) async {
    calls++;
    return next();
  }
}

AiChatController _controller(_Fake fake) => AiChatController(
      remote: fake,
      local: LocalAiCompanionService(input: _input),
      isPremium: () => true,
      isEnabled: () => true,
      buildContext: (topic) =>
          const AiFinancialContextBuilder().build(input: _input(), topic: topic, language: 'en'),
      language: () => 'en',
      character: () => CompanionCharacter.otter,
      cooldown: Duration.zero,
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('consent: Enable returns true, Not now returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showAiConsentSheet(context, 'en'),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(t('ai_consent_title', 'en')), findsOneWidget);
    expect(find.text(t('ai_consent_body_not_sent', 'en')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai_consent_cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai_consent_whats_shared')));
    await tester.pumpAndSettle();
    expect(find.text(t('ai_shared_not_notes', 'en')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('ai_consent_enable')));
    await tester.tap(find.byKey(const ValueKey('ai_consent_enable')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  Future<void> pumpChat(WidgetTester tester, AiChatController c) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AiChatSheet(controller: c, language: 'en', character: CompanionCharacter.otter),
      ),
    ));
  }

  testWidgets('chat: loading, answer and follow-ups', (tester) async {
    final fake = _Fake();
    final gate = Completer<AiReply>();
    fake.next = () => gate.future;
    final c = _controller(fake);
    await pumpChat(tester, c);

    // Quick question shortcuts are above the input.
    for (final q in MoneyQuestion.values) {
      expect(find.text(t(q.labelKey, 'en')), findsOneWidget);
    }
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('ai_send'))).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('ai_input')), 'How am I doing?');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ai_send')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ai_loading')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('ai_send'))).onPressed, isNull,
        reason: 'no double-send while loading');

    gate.complete(const AiReply(
        answer: 'You spent 42 USD so far.', mood: InsightMood.positive, followUps: ['Compare with last month?']));
    await _settle(tester);
    expect(find.byKey(const ValueKey('ai_loading')), findsNothing);
    expect(find.text('You spent 42 USD so far.'), findsOneWidget);
    expect(find.text('Compare with last month?'), findsOneWidget);
    expect(fake.calls, 1);
    c.dispose();
  });

  testWidgets('chat: failure shows error, local insight and retry', (tester) async {
    final fake = _Fake()..next = () => throw const AiException(AiFailure.offline);
    final c = _controller(fake);
    await pumpChat(tester, c);

    await tester.tap(find.text(t('question_top_category', 'en')));
    await _settle(tester);
    expect(find.text(t('ai_error_offline', 'en')), findsOneWidget);
    expect(find.text(t('ai_local_label', 'en')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai_retry')), findsOneWidget);

    fake.next = () => const AiReply(answer: 'Back online.', mood: InsightMood.neutral);
    await tester.tap(find.byKey(const ValueKey('ai_retry')));
    await _settle(tester);
    expect(find.text('Back online.'), findsOneWidget);
    expect(find.text(t('ai_error_offline', 'en')), findsNothing);
    expect(find.byKey(const ValueKey('ai_retry')), findsNothing);
    c.dispose();
  });

  testWidgets('Home card shows "Ask AI" only when provided', (tester) async {
    var opened = 0;
    Future<void> pumpCard({VoidCallback? onAskAi}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CompanionCard(
            language: 'en',
            selectedTheme: 'cream',
            isPremium: true,
            character: CompanionCharacter.otter,
            insights: const MoneyInsightEngine().generate(_input()),
            lastShownId: null,
            onShown: (_) {},
            onOpenPaywall: () {},
            answerFor: (q) => const MoneyInsightEngine().answer(q, _input()),
            onAskAi: onAskAi,
          ),
        ),
      ));
      await _settle(tester);
      await tester.tap(find.byTooltip(t('companion_ask', 'en')));
      await _settle(tester);
    }

    await pumpCard();
    expect(find.byKey(const ValueKey('companion_ask_ai')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    await pumpCard(onAskAi: () => opened++);
    expect(find.byKey(const ValueKey('companion_ask_ai')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('companion_ask_ai')));
    await _settle(tester);
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
