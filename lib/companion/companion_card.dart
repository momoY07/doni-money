import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/i18n.dart';
import 'companion_character.dart';
import 'companion_controller.dart';
import 'companion_text.dart';
import 'insight.dart';

/// What the character is doing. Each pose is a short one-shot animation;
/// between them the character rests.
enum CompanionPose { idle, notice, speaking, happy }

/// The pose for a new line: positive facts get a small happy hop,
/// heads-up facts a look of attention, everything else plain speaking.
CompanionPose poseForInsight(Insight? insight) => poseForMood(insight?.mood);

/// Same mapping for any mood source (local insights or AI replies).
CompanionPose poseForMood(InsightMood? mood) {
  switch (mood) {
    case InsightMood.positive:
      return CompanionPose.happy;
    case InsightMood.attention:
      return CompanionPose.notice;
    case InsightMood.neutral:
    case null:
      return CompanionPose.speaking;
  }
}

/// Compact Home card: the companion character and one short speech bubble.
///
/// * Tap the card: next insight (or close the question list).
/// * Ask button (Premium): three fixed quick questions; the answer replaces
///   the bubble until the next tap. No text input of any kind.
/// * Free users see a locked preview that opens the paywall.
///
/// Motion is brief and event-driven. While nothing happens the character
/// only "breathes" occasionally, a few times at most, and only while the
/// card is on screen and the app is in the foreground. With Reduce Motion
/// on there is no movement at all.
class CompanionCard extends StatefulWidget {
  final String language;
  final String selectedTheme;
  final bool isPremium;
  final CompanionCharacter character;
  final List<Insight> insights;
  final String? lastShownId;
  final ValueChanged<String> onShown;
  final VoidCallback onOpenPaywall;

  /// Answers a quick question from local data. Null for free users.
  final Insight Function(MoneyQuestion question)? answerFor;

  /// Opens the AI conversation (Premium). Null hides the "Ask AI" chip.
  final VoidCallback? onAskAi;

  const CompanionCard({
    super.key,
    required this.language,
    required this.selectedTheme,
    required this.isPremium,
    required this.character,
    required this.insights,
    required this.lastShownId,
    required this.onShown,
    required this.onOpenPaywall,
    this.answerFor,
    this.onAskAi,
  });

  @override
  State<CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<CompanionCard> with SingleTickerProviderStateMixin {
  static const _idleEvery = Duration(seconds: 12);
  static const _maxIdlePlays = 4;

  late final CompanionController _controller;
  late final AnimationController _motion;
  CompanionPose _pose = CompanionPose.idle;
  int _seenSpeak = 0;
  bool _questionsOpen = false;
  Timer? _idleTimer;
  int _idlePlays = 0;
  int _playToken = 0;

  bool get _isCA => widget.selectedTheme == 'cyber_ai';
  bool get _isMB => widget.selectedTheme == 'minimal_black';
  bool get _dark => _isCA || _isMB;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this);
    _controller = CompanionController(lastShownId: widget.lastShownId, onShown: widget.onShown);
    if (widget.isPremium) _controller.setInsights(widget.insights);
    _controller.addListener(_onControllerChanged);
    _seenSpeak = _controller.speakCount;
    if (widget.isPremium && _controller.current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(poseForInsight(_controller.current));
      });
    }
    _restartIdle();
  }

  @override
  void didUpdateWidget(covariant CompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isPremium) {
      _questionsOpen = false;
      return;
    }
    _controller.setInsights(widget.insights);
    final q = _controller.question;
    final answerFor = widget.answerFor;
    if (q != null && answerFor != null) _controller.refreshAnswer(answerFor(q));
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.speakCount != _seenSpeak) {
      _seenSpeak = _controller.speakCount;
      _play(poseForInsight(_controller.current));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _motion.dispose();
    super.dispose();
  }

  // ───────────────────────────── motion ─────────────────────────────

  void _play(CompanionPose pose) {
    _pose = pose;
    final token = ++_playToken;
    if (_reduceMotion) {
      // No movement; the pose still picks the image for a moment.
      _motion.value = 0;
      setState(() {});
      Timer(const Duration(milliseconds: 900), () {
        if (mounted && token == _playToken) setState(() => _pose = CompanionPose.idle);
      });
      return;
    }
    _motion.duration = switch (pose) {
      CompanionPose.idle => const Duration(milliseconds: 1200),
      CompanionPose.notice => const Duration(milliseconds: 950),
      CompanionPose.speaking => const Duration(milliseconds: 900),
      CompanionPose.happy => const Duration(milliseconds: 1150),
    };
    _motion.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && token == _playToken) setState(() => _pose = CompanionPose.idle);
    });
  }

  /// Occasional idle "breath", restarted by every interaction and capped so
  /// a card left on screen goes completely still.
  void _restartIdle() {
    _idleTimer?.cancel();
    _idlePlays = 0;
    if (!widget.isPremium) return;
    _idleTimer = Timer.periodic(_idleEvery, (timer) {
      if (!mounted || _idlePlays >= _maxIdlePlays) {
        timer.cancel();
        return;
      }
      if (_motion.isAnimating || _reduceMotion || !_isVisible()) return;
      _idlePlays++;
      _play(CompanionPose.idle);
    });
  }

  /// On screen, in an active tab/route, and the app in the foreground.
  bool _isVisible() {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    return rect.overlaps(screen);
  }

  // ─────────────────────────── interaction ───────────────────────────

  void _onTap() {
    if (!widget.isPremium) {
      widget.onOpenPaywall();
      return;
    }
    _restartIdle();
    if (_questionsOpen) {
      setState(() => _questionsOpen = false);
      return;
    }
    _controller.next();
  }

  void _toggleQuestions() {
    _restartIdle();
    setState(() => _questionsOpen = !_questionsOpen);
  }

  void _ask(MoneyQuestion q) {
    final answerFor = widget.answerFor;
    if (answerFor == null) return;
    _restartIdle();
    setState(() => _questionsOpen = false);
    _controller.showAnswer(q, answerFor(q));
  }

  // ───────────────────────────── build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final premium = widget.isPremium;
    final insight = premium ? _controller.current : null;
    final message = premium
        ? (insight == null
            ? ''
            : insightText(insight, widget.language, character: widget.character))
        : t('companion_locked', widget.language);
    final question = premium ? _controller.question : null;

    final cardBg = _isCA
        ? const Color(0xFF0F0F2A)
        : (_isMB ? const Color(0xFF1E1E1E) : Colors.white);
    final border = _isCA
        ? const Color(0xFF2A2A5A)
        : (_isMB ? const Color(0xFF333333) : const Color(0xFFD9E4EE));
    final bubbleBg = _isCA
        ? const Color(0xFF1A1A3A)
        : (_isMB ? const Color(0xFF2A2A2A) : const Color(0xFFF3F8FC));
    final textColor = _dark ? Colors.white : const Color(0xFF24364A);
    final subColor = _isCA
        ? const Color(0xFF6B6B9A)
        : (_isMB ? const Color(0xFF888888) : const Color(0xFF627487));
    final accent = _isCA
        ? const Color(0xFF7C7CFF)
        : (_isMB ? Colors.white : const Color(0xFF4A90C2));

    final switchDuration =
        _reduceMotion ? Duration.zero : const Duration(milliseconds: 250);

    return Semantics(
      button: true,
      label: '${t('companion_title', widget.language)}. $message',
      hint: _controller.showingAnswer ? t('companion_back', widget.language) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildCharacter(premium, accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: bubbleBg,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: switchDuration,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previous, ?current],
                            ),
                            child: Column(
                              key: ValueKey('$question|$message'),
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (question != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      t(question.labelKey, widget.language),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: subColor,
                                      ),
                                    ),
                                  ),
                                Text(
                                  message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (premium && widget.answerFor != null)
                        IconButton(
                          tooltip: t('companion_ask', widget.language),
                          visualDensity: VisualDensity.compact,
                          onPressed: _toggleQuestions,
                          icon: Icon(
                            _questionsOpen
                                ? Icons.close_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: _questionsOpen ? accent : subColor,
                          ),
                        )
                      else if (!premium)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.lock_rounded, size: 18, color: subColor),
                        ),
                    ],
                  ),
                  _sizeTransition(
                    _questionsOpen && premium
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10, right: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final q in MoneyQuestion.values)
                                  _QuestionChip(
                                    label: t(q.labelKey, widget.language),
                                    background: bubbleBg,
                                    border: border,
                                    textColor: textColor,
                                    onTap: () => _ask(q),
                                  ),
                                if (widget.onAskAi != null)
                                  _QuestionChip(
                                    key: const ValueKey('companion_ask_ai'),
                                    label: '✨ ${t('ai_ask_ai', widget.language)}',
                                    background: bubbleBg,
                                    border: accent,
                                    textColor: accent,
                                    onTap: () {
                                      setState(() => _questionsOpen = false);
                                      widget.onAskAi!();
                                    },
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Animated open/close of the question list. Under Reduce Motion the list
  /// simply appears (a zero-duration AnimatedSize is not used: it re-lays
  /// itself out during layout).
  Widget _sizeTransition(Widget child) {
    if (_reduceMotion) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _buildCharacter(bool premium, Color accent) {
    const size = 56.0;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final v = _motion.value;
        final pose = premium ? _pose : CompanionPose.idle;
        final active = pose != CompanionPose.idle || _motion.isAnimating;
        final still = _reduceMotion || !_motion.isAnimating;

        double dy = 0, scale = 1, angle = 0, badge = 0, sparkle = 0;
        if (!still) {
          final wave = math.sin(v * math.pi); // 0 → 1 → 0
          switch (pose) {
            case CompanionPose.idle:
              scale = 1 + 0.03 * wave;
            case CompanionPose.notice:
              angle = math.sin(v * math.pi * 3) * 0.10 * (1 - v);
              scale = 1 + 0.05 * wave;
              badge = wave;
            case CompanionPose.speaking:
              dy = -(math.sin(v * math.pi * 2)).abs() * 5;
            case CompanionPose.happy:
              dy = -(math.sin(v * math.pi * 3)).abs() * 8 * (1 - v * 0.5);
              scale = 1 + 0.08 * wave;
              sparkle = wave;
          }
        } else if (_reduceMotion && premium) {
          // Static cue instead of motion.
          badge = pose == CompanionPose.notice ? 1 : 0;
          sparkle = pose == CompanionPose.happy ? 1 : 0;
        }

        final asset = !premium || !active
            ? widget.character.idleAsset
            : switch (pose) {
                CompanionPose.happy => widget.character.happyAsset,
                CompanionPose.speaking => widget.character.speakingAsset,
                CompanionPose.notice || CompanionPose.idle => widget.character.idleAsset,
              };
        final image = Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: 192,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        );

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: premium ? image : Opacity(opacity: 0.55, child: image),
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -4,
                  child: Opacity(
                    opacity: badge.clamp(0.0, 1.0),
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (sparkle > 0)
                Positioned(
                  right: -4,
                  top: -6,
                  child: Opacity(
                    opacity: sparkle.clamp(0.0, 1.0),
                    child: Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestionChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color border;
  final Color textColor;
  final VoidCallback onTap;

  const _QuestionChip({
    super.key,
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: StadiumBorder(side: BorderSide(color: border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      ),
    );
  }
}
