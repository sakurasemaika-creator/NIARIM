import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService extends ChangeNotifier {
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
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
}

enum PremiumFeature {
  endCardEdit, watermark, toneCurve, levelAdjustment, unlimitedDuration,
}
