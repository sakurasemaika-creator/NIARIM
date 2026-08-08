import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/monetization_gate.dart';
import 'premium_service.dart';
import 'ad_provider.dart';
import 'admob_provider.dart';

/// 広告表示の窓口（仕様書13）。画面側はこのサービス経由でのみ広告を扱い、
/// 広告SDK（AdMob）へ直接依存しない。プレミアム時は全広告を非表示にする。
/// `isMonetizationEnabled`がfalseの間（税務上の都合による一時停止期間）は
/// AdMob SDK自体を初期化せず、広告を一切表示しない。
class AdvertisingService extends ChangeNotifier {
  final PremiumService premiumService;
  late AdProvider _provider;

  AdvertisingService({required this.premiumService});

  Future<void> init() async {
    _provider = AdMobProvider(onAdEvent: notifyListeners);
    if (isMonetizationEnabled) {
      await _provider.initialize();
    }
    premiumService.addListener(_onPremiumChanged);
  }

  bool get shouldShowAds => isMonetizationEnabled && !premiumService.isPremium;

  /// ロード済みバナー広告。未ロード・プレミアム時はnull（AdBannerWidgetが描画に使う）。
  BannerAd? get bannerAd => shouldShowAds ? _provider.currentBanner : null;

  /// ロード済み正方形広告。未ロード・プレミアム時はnull（処理中ダイアログが描画に使う）。
  BannerAd? get squareAd => shouldShowAds ? _provider.currentSquareAd : null;

  void _onPremiumChanged() {
    if (premiumService.isPremium) hideAllAds();
    notifyListeners();
  }

  Future<void> showBanner(AdPosition position) async {
    if (!shouldShowAds) return;
    await _provider.showBanner(position);
  }

  Future<void> showSquareAd() async {
    if (!shouldShowAds) return;
    await _provider.showSquareAd();
  }

  Future<void> hideAllAds() async {
    await _provider.hideAllAds();
    notifyListeners();
  }

  @override
  void dispose() {
    premiumService.removeListener(_onPremiumChanged);
    _provider.hideAllAds();
    super.dispose();
  }
}

enum AdPosition { top, bottom }
