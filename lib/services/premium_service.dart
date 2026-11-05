import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/monetization_gate.dart';
import 'google_auth_service.dart';
import '../utils/runtime_platform.dart';
import '../utils/tolerant_preferences.dart';

/// プレミアム加入状態・課金処理を管理する。
/// 実際の課金はGoogle Play Billing（in_app_purchase）経由で行い、
/// 購入・復元通知をNIARIMバックエンドからGoogle Play Developer APIで
/// 検証できた場合に限り、購入権限を短時間保持する。端末保存値だけでは
/// Premiumを有効にしない。
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

  // 課金一時停止期間中（isMonetizationEnabled==false）はアプリ起動時に
  // このサービスが生成されるだけでストアへ接続してはならない。
  // InAppPurchase.instanceは参照した時点で内部でBilling Clientへの
  // 接続を（awaitされない形で）開始してしまうため、フィールド初期化子で
  // 即座に取得せず、実際に購入操作を行う経路でのみ遅延生成する。
  InAppPurchase? _iapInstance;
  InAppPurchase get _iap => _iapInstance ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  DateTime? _playVerifiedUntil;
  String? _playVerifiedOwner;
  Timer? _playExpiryTimer;
  Timer? _playRefreshTimer;
  Future<Map<String, dynamic>> Function(String, String)? _playVerifier;
  Future<bool> Function()? _playPreflight;

  /// The caller uses the NIARIM authenticated API, never a local purchase flag.
  void bindPlayVerifier(
    Future<Map<String, dynamic>> Function(String productId, String purchaseToken) verify, {
    required Future<bool> Function() canPurchase,
  }) {
    _playVerifier = verify;
    _playPreflight = canPurchase;
    if (_storeAvailable && _boundGoogleAuth?.account != null) {
      unawaited(_restorePlayPurchasesSilently());
    }
  }

  Future<void> _restorePlayPurchasesSilently() async {
    try {
      await restorePurchases();
    } catch (_) {
      // A transient Play outage cannot grant access.
    }
  }

  void _invalidatePlayPremium() {
    _playExpiryTimer?.cancel();
    _playRefreshTimer?.cancel();
    _playVerifiedUntil = null;
    _playVerifiedOwner = null;
    _verifiedExpiryDate = null;
    _isPremium = false;
    notifyListeners();
  }

  /// A device flag/receipt callback alone cannot prove subscription ownership.
  bool get hasVerifiedPlayPremium {
    final now = DateTime.now();
    return _isPremium &&
        _verifiedExpiryDate?.isAfter(now) == true &&
        _playVerifiedUntil?.isAfter(now) == true &&
        _playVerifiedOwner != null &&
        _playVerifiedOwner == _boundGoogleAuth?.account?.id;
  }

  @visibleForTesting
  static bool isValidPlayVerification(
    Map<String, dynamic> value, String productId, DateTime now,
  ) {
    final expiry = value['expiresAtEpochMs'];
    final until = value['verifiedUntilEpochMs'];
    final nowMs = now.millisecondsSinceEpoch;
    return value['verified'] == true &&
        value['productId'] == productId &&
        expiry is int && until is int &&
        expiry > nowMs && until > nowMs && until <= expiry &&
        until <= nowMs + const Duration(minutes: 16).inMilliseconds;
  }

  void _applyVerifiedPlayPremium(
    Map<String, dynamic> response, String ownerId,
  ) {
    _playExpiryTimer?.cancel();
    _playRefreshTimer?.cancel();
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      response['expiresAtEpochMs'] as int,
    );
    final until = DateTime.fromMillisecondsSinceEpoch(
      response['verifiedUntilEpochMs'] as int,
    );
    _verifiedExpiryDate = expiry;
    _playVerifiedUntil = until;
    _playVerifiedOwner = ownerId;
    _isPremium = true;
    final remaining = until.difference(DateTime.now());
    if (remaining > const Duration(minutes: 1)) {
      _playRefreshTimer = Timer(
        remaining - const Duration(minutes: 1),
        () {
          if (_boundGoogleAuth?.account?.id == ownerId) {
            unawaited(_restorePlayPurchasesSilently());
          }
        },
      );
    }
    _playExpiryTimer = Timer(
      remaining > Duration.zero ? remaining : Duration.zero,
      () {
        if (_playVerifiedOwner == ownerId && _playVerifiedUntil == until) {
          _invalidatePlayPremium();
        }
      },
    );
    notifyListeners();
  }
  // Only the authenticated backend may provide coin-purchased Premium.
  // This is intentionally not an editable SharedPreferences entitlement.
  DateTime? _serverCoinPremiumExpiresAt;
  String? _serverCoinPremiumOwnerId;
  Timer? _coinPremiumExpiryTimer;
  GoogleAuthService? _boundGoogleAuth;
  String? _lastGoogleAccountId;

  /// A purchased coin entitlement must not follow the device to another user.
  /// Bind once at app startup even when the rewards screen is never opened.
  void bindGoogleAuth(GoogleAuthService auth) {
    if (identical(_boundGoogleAuth, auth)) return;
    _boundGoogleAuth?.removeListener(_onGoogleAccountChanged);
    _boundGoogleAuth = auth;
    _lastGoogleAccountId = auth.account?.id;
    _coinPremiumExpiryTimer?.cancel();
    _serverCoinPremiumExpiresAt = null;
    _serverCoinPremiumOwnerId = null;
    _invalidatePlayPremium();
    auth.addListener(_onGoogleAccountChanged);
    notifyListeners();
  }

  void _onGoogleAccountChanged() {
    final current = _boundGoogleAuth?.account?.id;
    if (current == _lastGoogleAccountId) return;
    _lastGoogleAccountId = current;
    applyServerCoinPremiumExpiry(null);
    _invalidatePlayPremium();
    if (current != null && _storeAvailable && _playVerifier != null) {
      unawaited(_restorePlayPurchasesSilently());
    }
  }

  bool get hasCoinPremium {
    final expiresAt = _serverCoinPremiumExpiresAt;
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) return false;
    final auth = _boundGoogleAuth;
    return auth == null ||
        (auth.account != null &&
            _serverCoinPremiumOwnerId == auth.account!.id);
  }

  /// Only an account-matched, authenticated API response may update expiry.
  void applyServerCoinPremiumExpiry(DateTime? expiresAt, {String? accountId}) {
    final auth = _boundGoogleAuth;
    if (expiresAt != null && auth != null &&
        (accountId == null || auth.account?.id != accountId)) {
      return;
    }
    _coinPremiumExpiryTimer?.cancel();
    _serverCoinPremiumExpiresAt = expiresAt;
    _serverCoinPremiumOwnerId = expiresAt == null ? null : accountId;
    if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
      _coinPremiumExpiryTimer = Timer(expiresAt.difference(DateTime.now()), () {
        _serverCoinPremiumExpiresAt = null;
        _serverCoinPremiumOwnerId = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // 購入日時・商品IDは参考表示用の端末データ。
  // 請求日や更新日をこの日時から確定扱いしない。
  // 権限には、サーバー検証済みの期限と検証リースを必須とする。
  DateTime? _purchaseDate;
  String? _purchasedProductId;
  // Google Playサーバー検証で受け取った有効期限。
  // アカウント切替・失効時には同時に破棄する。
  DateTime? _verifiedExpiryDate;

  /// 実際に購入済みかどうか（課金・ストア関連の判定に使用）。
  bool get hasPurchasedPremium => hasVerifiedPlayPremium;
  /// A saved product ID alone is never proof of a paid subscription.
  String? get verifiedSubscriptionProductId =>
      hasVerifiedPlayPremium ? _purchasedProductId : null;
  DateTime? get activeCoinPremiumExpiry =>
      hasCoinPremium ? _serverCoinPremiumExpiresAt : null;

  /// 購入日時（登録日表示用）。未購入または記録前はnull。
  DateTime? get purchaseDate => _purchaseDate;

  /// Google Playで検証したサブスクリプションの有効期限。
  DateTime? get verifiedExpiryDate => _verifiedExpiryDate;

  /// 次回更新日。サーバー側レシート検証済みの有効期限があればそれを、
  /// 無ければ購入日から暦計算した推定値を返す（登録日と同じ月日（年額）／
  /// 同じ日（月額）を維持したまま、現在時刻以降で最も近い日を年・月単位で
  /// ずらして求める。暦計算のため、日数の単純な加算と違って月の日数差に
  /// よる誤差が生じない）。
  DateTime? get nextRenewalDate =>
      _verifiedExpiryDate ?? nextRenewalDateEstimate;

  DateTime? get nextRenewalDateEstimate {
    final start = _purchaseDate;
    if (start == null) return null;
    final isYearly = _purchasedProductId == yearlyProductId;
    final now = DateTime.now();
    if (isYearly) {
      var next = DateTime(
        now.year,
        start.month,
        start.day,
        start.hour,
        start.minute,
      );
      if (!next.isAfter(now)) {
        next = DateTime(
          now.year + 1,
          start.month,
          start.day,
          start.hour,
          start.minute,
        );
      }
      return next;
    } else {
      // 購入日からの経過月数を求め、そこから1か月ずつ進めて現在時刻を
      // 超える月を探す（DateTime(year, month, day)は月の日数を超える
      // dayを渡すと自動的に翌月へ繰り上がるため、31日始まりの月をまたいでも
      // 破綻しない）。
      var monthsElapsed =
          (now.year - start.year) * 12 + (now.month - start.month);
      DateTime candidate() => DateTime(
        start.year,
        start.month + monthsElapsed,
        start.day,
        start.hour,
        start.minute,
      );
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
  bool get isPremium => hasVerifiedPlayPremium || hasCoinPremium || isLaunchCampaignActive;

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
    // A locally editable preference is never a billable Premium entitlement.
    _isPremium = false;
    final purchaseMillis = prefs.readInt('premium_purchase_date');
    if (purchaseMillis != null) {
      _purchaseDate = DateTime.fromMillisecondsSinceEpoch(purchaseMillis);
    }
    _purchasedProductId = prefs.readString('premium_purchase_product_id');

    // in_app_purchaseのストア実装はAndroid/iOS専用。widget testや
    // デスクトップ、Flutter Webでinstanceへ触れると、isAvailable()の
    // try/catch外で開始される非同期接続がPlatformExceptionを投げる。
    if (!isMonetizationEnabled || !supportsMobilePluginRuntime) {
      // 課金一時停止期間・非対応OSではストアへ一切接続しない。
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

  /// 指定商品IDの購入フローを開始する（サブスクリプション）。
  /// 戻り値は購入フローの開始に成功したかどうか。実際の購入完了・失敗結果は
  /// purchaseStream経由で非同期に届き、isPremiumへ反映される。
  Future<bool> buy(String productId) async {
    if (!isMonetizationEnabled) {
      _purchaseError = 'ただいまキャンペーン期間中につき、プレミアム機能は無料でご利用いただけます。';
      notifyListeners();
      return false;
    }
    if (_boundGoogleAuth?.account == null || _playVerifier == null ||
        _playPreflight == null) {
      _purchaseError = '購入にはログインとサーバー検証が必要です';
      notifyListeners();
      return false;
    }
    if (!_storeAvailable) {
      _purchaseError = 'ストアに接続できません';
      notifyListeners();
      return false;
    }
    // Do not charge a user if the NIARIM server cannot verify Play purchases.
    final startingAccount = _boundGoogleAuth?.account?.id;
    bool backendReady;
    try {
      backendReady = await _playPreflight!();
    } catch (_) {
      backendReady = false;
    }
    if (!backendReady || startingAccount == null ||
        startingAccount != _boundGoogleAuth?.account?.id) {
      _purchaseError = '購入検証サーバーが利用できないため購入を開始できません';
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

  /// 購入の復元（機種変更・再インストール時）。
  Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      bool verifiedAndReadyToAcknowledge = false;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchasePending = false;
          final verifier = _playVerifier;
          final accountId = _boundGoogleAuth?.account?.id;
          final purchaseToken = purchase.verificationData.serverVerificationData;
          if (verifier == null || accountId == null ||
              purchaseToken.isEmpty || !_productIds.contains(purchase.productID)) {
            _purchaseError = '購入をサーバーで検証できません';
            break;
          }
          try {
            final result = await verifier(purchase.productID, purchaseToken);
            if (_boundGoogleAuth?.account?.id != accountId) break;
            if (!isValidPlayVerification(result, purchase.productID, DateTime.now())) {
              _invalidatePlayPremium();
              _purchaseError = 'Google Playの有効な購入を確認できませんでした';
              break;
            }
            _applyVerifiedPlayPremium(result, accountId);
            _purchaseError = null;
            verifiedAndReadyToAcknowledge = true;
            final rawDate = purchase.transactionDate;
            final ms = rawDate == null ? null : int.tryParse(rawDate);
            final purchaseDate = ms == null
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(
                    rawDate!.length > 11 ? ms : ms * 1000,
                  );
            await setPremium(true,
              purchaseDate: purchaseDate, productId: purchase.productID);
          } catch (_) {
            _purchaseError = '購入検証に失敗しました。購入を復元して再確認してください';
            // Leave purchase unacknowledged for a verified retry.
          }
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _purchaseError = purchase.error?.message ?? '購入処理に失敗しました';
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          break;
      }
      if (purchase.pendingCompletePurchase && verifiedAndReadyToAcknowledge) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  Future<void> setPremium(
    bool value, {
    DateTime? purchaseDate,
    String? productId,
  }) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
    if (value && purchaseDate != null) {
      _purchaseDate = purchaseDate;
      _purchasedProductId = productId;
      await prefs.setInt(
        'premium_purchase_date',
        purchaseDate.millisecondsSinceEpoch,
      );
      if (productId != null) {
        await prefs.setString('premium_purchase_product_id', productId);
      }
    } else if (!value) {
      _purchaseDate = null;
      _purchasedProductId = null;
      await prefs.remove('premium_purchase_date');
      await prefs.remove('premium_purchase_product_id');
    }
    notifyListeners();
  }

  // Google Play検証は _onPurchaseUpdate → _playVerifier 経由で実施。
  // purchaseTokenは端末の永続設定には保存しない。

  // プロジェクト最大尺：無料90秒 / Premium 2時間（7200秒）。
  // PremiumFeature.unlimitedDuration は既存IDとの互換性のため名称のみ維持。
  int get maxProjectDurationSeconds =>
      isFeatureAvailable(PremiumFeature.unlimitedDuration) ? 7200 : 90;

  bool isFeatureAvailable(PremiumFeature feature) => isPremium;

  @override
  void dispose() {
    _boundGoogleAuth?.removeListener(_onGoogleAccountChanged);
    _coinPremiumExpiryTimer?.cancel();
    _playExpiryTimer?.cancel();
    _playRefreshTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

enum PremiumFeature {
  endCardEdit,
  watermark,
  toneCurve,
  levelAdjustment,
  unlimitedDuration,
  customAutomation,
}
