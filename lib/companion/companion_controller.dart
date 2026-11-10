import 'package:flutter/foundation.dart';

import 'insight.dart';

/// Decides which line the companion says. No financial logic here.
///
/// * Shows the highest-priority insight, but not the one shown last time
///   (across app launches via [lastShownId] / [onShown]) when there's another.
/// * Keeps the current insight when the data changes but it's still valid,
///   so the bubble doesn't jump around while the user edits entries.
/// * [next] cycles through the available insights.
/// * A quick-question answer ([showAnswer]) is shown on top of the cycle
///   without changing it: it isn't recorded as "last shown", and leaving it
///   ([next] / [dismissAnswer]) continues the normal insight rotation.
class CompanionController extends ChangeNotifier {
  CompanionController({String? lastShownId, this.onShown}) : _lastShownId = lastShownId;

  final void Function(String id)? onShown;
  String? _lastShownId;

  List<Insight> _insights = const [];
  int _index = 0;

  MoneyQuestion? _question;
  Insight? _answer;

  /// Increments every time a new line is spoken; the UI animates on change.
  int speakCount = 0;

  List<Insight> get insights => _insights;

  /// What the bubble shows: the answer while one is open, else the insight.
  Insight? get current => _answer ?? currentInsight;

  /// The insight in the rotation, ignoring any open answer.
  Insight? get currentInsight => _insights.isEmpty ? null : _insights[_index];
  bool get hasMore => _insights.length > 1;
  bool get showingAnswer => _answer != null;
  MoneyQuestion? get question => _question;

  void setInsights(List<Insight> insights) {
    final currentId = currentInsight?.id;
    if (_sameIds(insights, _insights)) {
      _insights = insights;
      return;
    }
    _insights = insights;
    if (insights.isEmpty) {
      _index = 0;
      notifyListeners();
      return;
    }

    final keep = currentId == null ? -1 : insights.indexWhere((i) => i.id == currentId);
    if (keep >= 0) {
      _index = keep;
      notifyListeners();
      return;
    }

    // Fresh start: the top insight, unless it's exactly what was said last.
    var start = 0;
    if (insights.length > 1 && insights.first.id == _lastShownId) start = 1;
    _index = start;
    // While an answer is open the new insight isn't visible yet: don't
    // record or animate it.
    if (_answer != null) {
      notifyListeners();
      return;
    }
    _speak();
  }

  void next() {
    if (_answer != null) {
      _question = null;
      _answer = null;
    }
    if (_insights.isEmpty) {
      notifyListeners();
      return;
    }
    _index = (_index + 1) % _insights.length;
    _speak();
  }

  /// Shows the answer to [question]. The insight rotation is untouched.
  void showAnswer(MoneyQuestion question, Insight answer) {
    _question = question;
    _answer = answer;
    speakCount++;
    notifyListeners();
  }

  /// Updates the open answer after the data changed (e.g. an entry was
  /// added), without animating. No-op when no answer is open.
  void refreshAnswer(Insight answer) {
    if (_answer == null || _answer!.id == answer.id) return;
    _answer = answer;
    notifyListeners();
  }

  /// Closes the answer and goes back to the insight that was showing.
  void dismissAnswer() {
    if (_answer == null) return;
    _question = null;
    _answer = null;
    notifyListeners();
  }

  void _speak() {
    speakCount++;
    final id = currentInsight?.id;
    if (id != null) {
      _lastShownId = id;
      onShown?.call(id);
    }
    notifyListeners();
  }

  static bool _sameIds(List<Insight> a, List<Insight> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}
