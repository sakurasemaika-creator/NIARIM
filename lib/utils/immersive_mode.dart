import 'package:flutter/services.dart';

/// キャンバス画面・タイムライン画面など、作業領域を広く使いたい画面で
/// Android標準のナビゲーションバー（戻る・ホーム・タブ一覧）を最小化する。
/// ステータスバーは残し、下部のナビゲーションバーのみ隠す。端の縁から
/// スワイプすれば一時的に再表示できる（Android標準のジェスチャー挙動）。
class ImmersiveMode {
  ImmersiveMode._();

  static void enterWorkspace() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  /// ホーム画面など通常の画面へ戻る際に、標準のナビゲーションバー表示へ
  /// 戻す。
  static void exitWorkspace() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
