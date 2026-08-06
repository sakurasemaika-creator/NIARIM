import 'ad_provider.dart';
import 'advertising_service.dart';

class AdMobProvider implements AdProvider {
  @override
  Future<void> initialize() async {
    // TODO: await MobileAds.instance.initialize();
  }

  @override
  Future<void> showBanner(AdPosition position) async {
    // TODO: Load and show banner ad
  }

  @override
  Future<void> showSquareAd() async {
    // TODO: Load and show square ad
  }

  @override
  Future<void> hideAllAds() async {
    // TODO: Dispose all active ads
  }
}
