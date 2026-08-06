import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'advertising_service.dart';

/// 広告プロバイダーの抽象化層（仕様書13）。
/// 各画面はAdvertisingService経由でのみ広告を扱い、広告SDKへ直接依存しない。
/// ロード済み広告オブジェクト（BannerAd）の型のみ、Flutter上で広告を実際に
/// 描画する都合上google_mobile_adsに依存する。将来的に他社SDKへ差し替える際は
/// 本インターフェース実装側でBannerAd相当のラッパーへ変換する。
abstract class AdProvider {
  Future<void> initialize();
  Future<void> showBanner(AdPosition position);
  Future<void> showSquareAd();
  Future<void> hideAllAds();

  /// ロード済みバナー広告（未ロード時はnull）。
  BannerAd? get currentBanner;

  /// ロード済み正方形（中型レクタングル）広告（未ロード時はnull）。
  BannerAd? get currentSquareAd;
}
