import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/monetization_gate.dart';

/// プレミアム加入状態・課金処理を管理する（仕様書13）。
/// 実際の課金はGoogle Play Billing（in_app_purchase）経由で行い、
/// purchaseStreamの結果を受けてisPremiumを更新する。
/// `isMonetizationEnabled`がfalseの間（税務上の都合による一時停止期間）は
/// ストアへの接続・商品情報取得・購入操作を一切行わない。
class PremiumService extends ChangeNotifier {
  // ストアに登録するサブスクリプション商品ID
  static const String monthlyProductId = 'miranima_premium_monthly';
  static const String yearlyProductId = 'miranima_premium_yearly';
  static const Set<String> _productIds = {monthlyProductId, yearlyProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// 課金一時停止期間中（税務上の都合）かどうか。trueの間はPremiumScreenで
  /// 購入導線を隠し、代わりに準備中の案内を表示する。
  bool get isMonetizationPaused => !isMonetizationEnabled;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  String? _purchaseError;
  String? get purchaseError => _purchaseError;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;

    if (!isMonetizationEnabled) {
      // 課金一時停止期間：ストアへは一切接続しない。
      _storeAvailable = false;
      return;
    }

    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (_) {
      _storeAvailable = false;
    }
    if (!_storeAvailable) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    try {
      final response = await _iap.queryProductDetails(_productIds);
      _products = response.productDetails;
    } catch (_) {
      _products = [];
    }
  }

  /// 指定商品IDの購入フローを開始する（サブスクリプション、仕様書13）。
  /// 戻り値は購入フローの開始に成功したかどうか。実際の購入完了・失敗結果は
  /// purchaseStream経由で非同期に届き、isPremiumへ反映される。
  Future<bool> buy(String productId) async {
    if (!isMonetizationEnabled) {
      _purchaseError = 'プレミアム機能は準備中です。もうしばらくお待ちください。';
      notifyListeners();
      return false;
    }
    if (!_storeAvailable) {
      _purchaseError = 'ストアに接続できません';
      notifyListeners();
      return false;
    }
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      _purchaseError = '商品情報を取得できませんでした';
      notifyListeners();
      return false;
    }
    _purchaseError = null;
    _purchasePending = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    // サブスクリプションもin_app_purchaseではbuyNonConsumableを使用する。
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// 購入の復元（機種変更・再インストール時、仕様書13）。
  Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchasePending = false;
          _purchaseError = null;
          await setPremium(true);
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _purchaseError = purchase.error?.message ?? '購入処理に失敗しました';
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
    notifyListeners();
  }

  // 無料版の最大動画尺（仕様書12実装チェックリスト：90秒）
  int get maxProjectDurationSeconds => _isPremium ? 999999 : 90;

  bool isFeatureAvailable(PremiumFeature feature) => _isPremium;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum PremiumFeature {
  endCardEdit, watermark, toneCurve, levelAdjustment, unlimitedDuration,
}
