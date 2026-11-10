import Flutter
import Foundation
import StoreKit

/// Proof of Premium for the AI proxy.
///
/// Returns the App Store-signed JWS (StoreKit 2 `jwsRepresentation`) of the
/// user's active Premium subscription, so the server can verify entitlement
/// with Apple's certificate chain instead of trusting an app flag. Read-only:
/// it never buys, restores or finishes transactions, so the existing
/// in_app_purchase flow is unaffected.
///
/// Channel `doni_money/entitlement`:
///   premiumTransaction({productIds: [String]}) -> String? (JWS) | nil
/// nil when there is no active, unrevoked, verified entitlement, or on
/// iOS < 15 (no StoreKit 2).
final class EntitlementPlugin: NSObject, FlutterPlugin {
  static let channelName = "doni_money/entitlement"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(EntitlementPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "premiumTransaction" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let productIds = Set((args["productIds"] as? [String]) ?? [])
    guard !productIds.isEmpty else {
      result(FlutterError(code: "badArgs", message: "productIds required", details: nil))
      return
    }
    guard #available(iOS 15.0, *) else {
      result(nil)
      return
    }
    Task {
      let jws = await Self.activePremiumJWS(productIds: productIds)
      DispatchQueue.main.async { result(jws) }
    }
  }

  @available(iOS 15.0, *)
  private static func activePremiumJWS(productIds: Set<String>) async -> String? {
    var best: (expires: Date, jws: String)?
    for await entitlement in Transaction.currentEntitlements {
      // Only Apple-verified transactions; unverified ones are ignored.
      guard case .verified(let transaction) = entitlement else { continue }
      guard productIds.contains(transaction.productID),
            transaction.revocationDate == nil else { continue }
      let expires = transaction.expirationDate ?? .distantFuture
      guard expires > Date() else { continue }
      if best == nil || expires > best!.expires {
        best = (expires, entitlement.jwsRepresentation)
      }
    }
    return best?.jws
  }
}
