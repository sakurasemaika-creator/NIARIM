import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/tolerant_preferences.dart';

/// 初回使用時の吹き出し説明の表示済み管理。
/// 各機能ごとに一意なキーで「表示済みかどうか」を永続化する。表示は一度のみで、
/// 設定の「機能の説明をもう一度表示」（[resetAll]）で次に使うときにまた出す。
class FirstUseTooltipService extends ChangeNotifier {
  static const _prefsKey = 'first_use_tooltips_seen';
  final Set<String> _seen = {};
  // 画面の破棄の後に遅れて届く記録（吹き出しを出したまま閉じられた場合）は、
  // 起動のやり直し等でこのServiceが先に破棄されていれば捨てる。
  bool _disposed = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen.addAll(prefs.readStringList(_prefsKey) ?? const []);
    } catch (_) {
      // 読み込み失敗時は「未表示」として続行（多少多めに出るだけで実害は小さい）
    }
  }

  bool hasSeen(String key) => _seen.contains(key);

  Future<void> markSeen(String key) async {
    if (_disposed || _seen.contains(key)) return;
    _seen.add(key);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _seen.toList());
    } catch (_) {
      // 保存失敗時も続行（次回起動時にまた表示される程度の影響に留まる）
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 全ての表示済み状態をリセットする（設定の「機能の説明をもう一度表示」）。
  Future<void> resetAll() async {
    _seen.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
