import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 初回使用時の吹き出し説明の表示済み管理。
/// 各機能ごとに一意なキーで「表示済みかどうか」を永続化する。表示は一度のみ・
/// 再表示なし（再確認はヘルプページから行う）。
class FirstUseTooltipService extends ChangeNotifier {
  static const _prefsKey = 'first_use_tooltips_seen';
  final Set<String> _seen = {};

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen.addAll(prefs.getStringList(_prefsKey) ?? const []);
    } catch (_) {
      // 読み込み失敗時は「未表示」として続行（多少多めに出るだけで実害は小さい）
    }
  }

  bool hasSeen(String key) => _seen.contains(key);

  Future<void> markSeen(String key) async {
    if (_seen.contains(key)) return;
    _seen.add(key);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _seen.toList());
    } catch (_) {
      // 保存失敗時も続行（次回起動時にまた表示される程度の影響に留まる）
    }
  }

  /// デバッグ・テスト用：全ての表示済み状態をリセットする。
  Future<void> resetAll() async {
    _seen.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
