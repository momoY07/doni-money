import 'package:flutter/services.dart';

import '../services/purchase_service.dart';

/// Returns the App Store-signed proof (JWS) of an active Premium
/// subscription, or null. The AI proxy verifies it with Apple's certificate
/// chain; the app's own `isPremium` flag is never trusted by the server.
typedef AiEntitlementProof = Future<String?> Function();

abstract final class StoreKitEntitlement {
  static const _channel = MethodChannel('doni_money/entitlement');

  /// Reads `Transaction.currentEntitlements` (StoreKit 2) natively. Debug
  /// developer mode has no transaction, so it gets null here.
  static Future<String?> premiumTransaction() async {
    try {
      final jws = await _channel.invokeMethod<String>('premiumTransaction', {
        'productIds': PurchaseService.premiumProductIds.toList(),
      });
      return (jws == null || jws.isEmpty) ? null : jws;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
