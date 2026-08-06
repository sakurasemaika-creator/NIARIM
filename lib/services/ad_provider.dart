import 'advertising_service.dart';

abstract class AdProvider {
  Future<void> initialize();
  Future<void> showBanner(AdPosition position);
  Future<void> showSquareAd();
  Future<void> hideAllAds();
}
