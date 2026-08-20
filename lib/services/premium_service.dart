import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/monetization_gate.dart';

/// プレミアム加入状態・課金処理を管理する（仕様書13）。
/// 実際の課金はGoogle Play Billing（in_app_purchase）経由で行い、
/// purchaseStreamの結果を受けてisPremiumを更新する。
///
/// `isMonetizationEnabled`がfalseの間（税務上の都合による一時停止期間）は
/// ストアへの接続・商品情報取得・購入操作を一切行わない。この期間は
/// 「リリース記念キャンペーン」として、全ユーザーへプレミアム機能を無料で
/// 開放する（[isPremium]がtrueを返す）。金銭のやり取りは一切発生しない
/// （広告非表示・購入不可のまま）ため税務上の位置づけは変わらず、
/// ユーザー視点では前向きな施策として提示できる。実際に購入したかどうかは
/// [hasPurchasedPremium]で区別する。
class PremiumService extends ChangeNotifier {
  // ストアに登録するサブスクリプション商品ID
  static const String monthlyProductId = 'niarim_premium_monthly';
  static const String yearlyProductId = 'niarim_premium_yearly';
  static const Set<String> _productIds = {monthlyProductId, yearlyProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  // 購入日時・購入商品ID（登録日・次回更新日の表示用）。サーバー側の
  // レシート検証（Google Play Developer API等）は行っていないため、
  // 実際の請求確定日はストアからは取得できない。ただしサブスクリプションの
  // 更新日は購入日と同じ「日」（年額なら月日、月額なら日）に固定される
  // ため、購入日さえ分かれば暦計算だけで正確に求められる（月をまたぐ
  // 日数の単純な加算だと、月の日数の違いでずれることがあるため、
  // 年・月を直接ずらすDateTimeコンストラクタで計算する）。
  DateTime? _purchaseDate;
  String? _purchasedProductId;

  /// 実際に購入済みかどうか（課金・ストア関連の判定に使用）。
  bool get hasPurchasedPremium => _isPremium;

  /// 購入日時（登録日表示用）。未購入または記録前はnull。
  DateTime? get purchaseDate => _purchaseDate;

  /// 次回更新日。購入日と同じ月日（年額）／同じ日（月額）を維持したまま、
  /// 現在時刻以降で最も近い日を年・月単位でずらして求める（暦計算のため、
  /// 日数の単純な加算と違って月の日数差による誤差が生じない）。
  DateTime? get nextRenewalDateEstimate {
    final start = _purchaseDate;
    if (start == null) return null;
    final isYearly = _purchasedProductId == yearlyProductId;
    final now = DateTime.now();
    if (isYearly) {
      var next = DateTime(now.year, start.month, start.day, start.hour, start.minute);
      if (!next.isAfter(now)) next = DateTime(now.year + 1, start.month, start.day, start.hour, start.minute);
      return next;
    } else {
      // 購入日からの経過月数を求め、そこから1か月ずつ進めて現在時刻を
      // 超える月を探す（DateTime(year, month, day)は月の日数を超える
      // dayを渡すと自動的に翌月へ繰り上がるため、31日始まりの月をまたいでも
      // 破綻しない）。
      var monthsElapsed = (now.year - start.year) * 12 + (now.month - start.month);
      DateTime candidate() =>
          DateTime(start.year, start.month + monthsElapsed, start.day, start.hour, start.minute);
      var next = candidate();
      if (!next.isAfter(now)) {
        monthsElapsed++;
        next = candidate();
      }
      // 直前の月も現在時刻を超えていないか一応確認する（うるう年2/29
      // 購入等、月初側にずれるケースの保険）。
      while (!next.isAfter(now)) {
        monthsElapsed++;
        next = candidate();
      }
      return next;
    }
  }

  /// プレミアム機能を利用できるかどうか（機能制限の判定に使用）。
  /// 実際の購入済み、またはリリース記念キャンペーン期間中はtrue。
  bool get isPremium => _isPremium || isLaunchCampaignActive;

  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// リリース記念キャンペーン期間中（＝課金一時停止期間、税務上の都合）
  /// かどうか。trueの間はPremiumScreenで購入導線を隠し、代わりに
  /// 「プレミアム機能を無料開放中」の案内を表示する。
  bool get isLaunchCampaignActive => !isMonetizationEnabled;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  String? _purchaseError;
  String? get purchaseError => _purchaseError;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    final purchaseMillis = prefs.getInt('premium_purchase_date');
    if (purchaseMillis != null) {
      _purchaseDate = DateTime.fromMillisecondsSinceEpoch(purchaseMillis);
    }
    _purchasedProductId = prefs.getString('premium_purchase_product_id');

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
      _purchaseError = 'ただいまキャンペーン期間中につき、プレミアム機能は無料でご利用いただけます。';
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
          // transactionDateはミリ秒文字列（ストアによっては秒の場合もある
          // ため桁数で判定する）。取得できない場合は現在時刻で代用する。
          final rawDate = purchase.transactionDate;
          DateTime? parsedDate;
          if (rawDate != null) {
            final ms = int.tryParse(rawDate);
            if (ms != null) {
              parsedDate = DateTime.fromMillisecondsSinceEpoch(ms.toString().length > 11 ? ms : ms * 1000);
            }
          }
          await setPremium(true, purchaseDate: parsedDate ?? DateTime.now(), productId: purchase.productID);
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

  Future<void> setPremium(bool value, {DateTime? purchaseDate, String? productId}) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
    if (value && purchaseDate != null) {
      _purchaseDate = purchaseDate;
      _purchasedProductId = productId;
      await prefs.setInt('premium_purchase_date', purchaseDate.millisecondsSinceEpoch);
      if (productId != null) await prefs.setString('premium_purchase_product_id', productId);
    } else if (!value) {
      _purchaseDate = null;
      _purchasedProductId = null;
      await prefs.remove('premium_purchase_date');
      await prefs.remove('premium_purchase_product_id');
    }
    notifyListeners();
  }

  // 無料版の最大動画尺（仕様書12実装チェックリスト：90秒）
  int get maxProjectDurationSeconds => isPremium ? 999999 : 90;

  bool isFeatureAvailable(PremiumFeature feature) => isPremium;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum PremiumFeature {
  endCardEdit, watermark, toneCurve, levelAdjustment, unlimitedDuration,
}
