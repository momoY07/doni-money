import 'package:flutter/foundation.dart';

/// Where the AI proxy lives. Set at build time, e.g.
/// `--dart-define=AI_PROXY_URL=https://ai.example.com` (Xcode: add it to
/// DART_DEFINES). Not a secret: the provider key exists only on the server.
/// Without it, AI Conversation reports "not available" and the local
/// companion keeps working.
abstract final class AiConfig {
  static const _raw = String.fromEnvironment('AI_PROXY_URL');

  static Uri? get endpoint => endpointFrom(_raw, allowInsecureLocal: kDebugMode);

  /// HTTPS only; plain HTTP is accepted for localhost in debug builds.
  static Uri? endpointFrom(String raw, {required bool allowInsecureLocal}) {
    final base = Uri.tryParse(raw.trim());
    if (base == null || !base.hasAuthority) return null;
    final local = base.host == 'localhost' || base.host == '127.0.0.1';
    if (base.scheme != 'https' && !(base.scheme == 'http' && local && allowInsecureLocal)) {
      return null;
    }
    final path = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(path: '$path/v1/companion', query: null, fragment: null);
  }
}
