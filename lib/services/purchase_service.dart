import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService extends ChangeNotifier {
  static const String monthlyId =
      'com.sungwoong.easyfinancialledger.premium.monthly';
  static const String yearlyId =
      'com.sungwoong.easyfinancialledger.premium.yearly';
  static const Set<String> _productIds = {monthlyId, yearlyId};

  bool _isPremium = false;
  bool _isDevMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<ProductDetails> _products = [];

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool get isPremium => _isPremium || _isDevMode;
  bool get isDevMode => _isDevMode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ProductDetails> get products => _products;

  ProductDetails? get monthlyProduct =>
      _products.where((p) => p.id == monthlyId).firstOrNull;

  ProductDetails? get yearlyProduct =>
      _products.where((p) => p.id == yearlyId).firstOrNull;


  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    _isDevMode = prefs.getBool('dev_mode') ?? false;
    notifyListeners();

    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return;

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await InAppPurchase.instance.queryProductDetails(_productIds);
      _products = response.productDetails;
      notifyListeners();
    } catch (_) {}
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isLoading = true;
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(purchase);
        case PurchaseStatus.error:
          _isLoading = false;
          _errorMessage = purchase.error?.message;
          notifyListeners();
        case PurchaseStatus.canceled:
          _isLoading = false;
          notifyListeners();
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    _isPremium = true;
    _isLoading = false;
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: product);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> forceDevMode() async {
    _isDevMode = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode', true);
    notifyListeners();
  }

  Future<void> disableDevMode() async {
    _isDevMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode', false);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
