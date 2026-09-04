import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_provider.dart';
import 'advertising_service.dart';

/// AdMob広告プロバイダー。
///
/// AdUnitIDはGoogle公式のテスト用ID（常にテスト広告を返し、収益は発生しない）。
/// ストア公開前に必ずAdMobコンソールで発行した本番用AdUnitIDへ差し替えること。
/// 併せてandroid/app/src/main/AndroidManifest.xmlの
/// com.google.android.gms.ads.APPLICATION_IDも本番用App IDへ差し替える必要がある。
class AdMobProvider implements AdProvider {
  AdMobProvider({this.onAdEvent});

  /// 広告のロード完了・失敗・破棄のたびに呼び出される（AdvertisingServiceの
  /// notifyListenersと連動し、UI側の再描画をトリガーする）。
  final VoidCallback? onAdEvent;

  static String get _bannerAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-3940256099942544/2934735716' // Google公式テストID（iOSバナー）
      : 'ca-app-pub-3940256099942544/6300978111'; // Google公式テストID（Androidバナー）

  // 正方形（中型レクタングル）専用のテストIDはGoogleが公開していないため、
  // バナーと同じテストAdUnitIDをAdSize.mediumRectangleでロードする。
  // 本番運用時はAdMobコンソールで発行した専用AdUnitIDへ差し替える。
  static String get _squareAdUnitId => _bannerAdUnitId;

  BannerAd? _bannerAd;
  BannerAd? _squareAd;

  @override
  BannerAd? get currentBanner => _bannerAd;

  @override
  BannerAd? get currentSquareAd => _squareAd;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<void> showBanner(AdPosition position) async {
    final old = _bannerAd;
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onAdEvent?.call(),
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          if (identical(_bannerAd, failedAd)) _bannerAd = null;
          onAdEvent?.call();
        },
      ),
    );
    _bannerAd = ad;
    await ad.load();
    old?.dispose();
  }

  @override
  Future<void> showSquareAd() async {
    final old = _squareAd;
    final ad = BannerAd(
      adUnitId: _squareAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onAdEvent?.call(),
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          if (identical(_squareAd, failedAd)) _squareAd = null;
          onAdEvent?.call();
        },
      ),
    );
    _squareAd = ad;
    await ad.load();
    old?.dispose();
  }

  @override
  Future<void> hideAllAds() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    _squareAd?.dispose();
    _squareAd = null;
    onAdEvent?.call();
  }
}
