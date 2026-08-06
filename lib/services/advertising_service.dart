import 'package:flutter/foundation.dart';
import 'premium_service.dart';
import 'ad_provider.dart';
import 'admob_provider.dart';

class AdvertisingService extends ChangeNotifier {
  final PremiumService premiumService;
  late AdProvider _provider;

  AdvertisingService({required this.premiumService});

  Future<void> init() async {
    _provider = AdMobProvider();
    await _provider.initialize();
    premiumService.addListener(_onPremiumChanged);
  }

  bool get shouldShowAds => !premiumService.isPremium;

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
  }

  @override
  void dispose() {
    premiumService.removeListener(_onPremiumChanged);
    super.dispose();
  }
}

enum AdPosition { top, bottom }
