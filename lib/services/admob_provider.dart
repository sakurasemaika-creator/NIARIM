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

  // Debug/widget tests use Google's safe demo IDs. Release builds must
  // provide NIARIM-owned ad units through the signed build configuration;
  // never silently monetize with Google's demo publisher account.
  static const String _releaseAndroidBannerId = String.fromEnvironment(
    'NIARIM_ADMOB_ANDROID_BANNER_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseAndroidRectangleId = String.fromEnvironment(
    'NIARIM_ADMOB_ANDROID_RECTANGLE_AD_UNIT_ID',
    defaultValue: '',
  );
  static String get _bannerAdUnitId => kReleaseMode
      ? (defaultTargetPlatform == TargetPlatform.android
          ? _releaseAndroidBannerId : '')
      : (defaultTargetPlatform == TargetPlatform.iOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111');

  static String get _squareAdUnitId => kReleaseMode
      ? (defaultTargetPlatform == TargetPlatform.android
          ? _releaseAndroidRectangleId : '')
      : _bannerAdUnitId;

  /// Google-issued test IDs until production ad review is complete.
  static String get bannerAdUnitId => _bannerAdUnitId;
  static String get mediumRectangleAdUnitId => _squareAdUnitId;

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
    // Missing release IDs are treated as no ad, never as Google's test ad.
    if (_bannerAdUnitId.isEmpty) return;
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
    if (_squareAdUnitId.isEmpty) return;
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
