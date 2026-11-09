import 'package:flutter/foundation.dart';

import 'insight.dart';

/// Decides which insight the companion says. No financial logic here.
///
/// * Shows the highest-priority insight, but not the one shown last time
///   (across app launches via [lastShownId] / [onShown]) when there's another.
/// * Keeps the current insight when the data changes but it's still valid,
///   so the bubble doesn't jump around while the user edits entries.
/// * [next] cycles through the available insights.
class CompanionController extends ChangeNotifier {
  CompanionController({String? lastShownId, this.onShown}) : _lastShownId = lastShownId;

  final void Function(String id)? onShown;
  String? _lastShownId;

  List<Insight> _insights = const [];
  int _index = 0;

  /// Increments every time a new line is spoken; the UI animates on change.
  int speakCount = 0;

  List<Insight> get insights => _insights;
  Insight? get current => _insights.isEmpty ? null : _insights[_index];
  bool get hasMore => _insights.length > 1;

  void setInsights(List<Insight> insights) {
    final currentId = current?.id;
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
    _speak();
  }

  void next() {
    if (_insights.isEmpty) return;
    _index = (_index + 1) % _insights.length;
    _speak();
  }

  void _speak() {
    speakCount++;
    final id = current?.id;
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
