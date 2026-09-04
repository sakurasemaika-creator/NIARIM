import 'package:flutter/widgets.dart';
import '../models/community_work.dart';

/// コミュニティ画面のフローティング動画プレビューウィンドウの表示状態
/// （どの作品を表示中か・ウィンドウの位置とサイズ）を保持するサービス。
///
/// 「動画を再生しながら他の画面を閲覧し続けられる」という要件を満たす
/// ため、この状態は特定の画面（`CommunityScreen`等）のStateではなく
/// アプリ全体で共有されるProviderとして持ち、`app.dart`の
/// `MaterialApp.router`の`builder`（ルーティングされる画面の外側、
/// 常に生き続ける層）でこの状態を監視してウィンドウを描画する。
/// これにより、コミュニティ画面から他の画面へ遷移してもウィンドウは
/// 消えない。
class CommunityPreviewService extends ChangeNotifier {
  CommunityWork? _work;
  CommunityWork? get work => _work;

  Offset _position = const Offset(16, 100);
  Offset get position => _position;

  // ── サイズは「幅」だけを状態として持ち、高さは幅から計算する ──
  //
  // YouTubeの埋め込みプレーヤーには**最小200×200px**という要件がある。
  // 幅と高さを独立に持たせると、利用者がリサイズハンドルを動かした結果
  // 簡単にこれを下回ってしまう（実際、旧実装の最小サイズは200×140で、
  // 動画エリアはさらにコントロールバーぶん低く、要件を満たしていなかった）。
  //
  // そこで幅だけを可変にし、動画エリアは常に16:9、ウィンドウの高さは
  // 「動画エリアの高さ＋コントロールバーの高さ」で導出する。これにより
  // 最小幅さえ守れば最小サイズ要件が構造的に保証される。
  double _width = minWidth;
  double get width => _width;

  /// 動画エリアの縦横比（16:9）。
  static const double playerAspect = 16 / 9;

  /// 下部コントロールバー（再生/一時停止・閉じる・詳細への3ボタン）の高さ。
  /// プレーヤーの**外側**に置くための領域で、ここにボタンを収めることで
  /// 「プレーヤーの上に何も重ねない」という条件を満たす。
  static const double controlBarHeight = 44;

  /// 最小幅。16:9で高さ200pxを確保するのに必要な幅
  /// （200 × 16 / 9 = 355.6 → 356）。これを下回るとYouTubeの埋め込み
  /// プレーヤーの最小サイズ要件を満たせないため、リサイズの下限とする。
  static const double minWidth = 356;

  /// 最大幅。画面幅を超えないよう、呼び出し側でさらに絞る。
  static const double maxWidth = 640;

  /// 動画エリアの大きさ（この矩形の上には何も重ねてはいけない）。
  Size get playerSize => Size(_width, _width / playerAspect);

  /// ウィンドウ全体の大きさ（動画エリア＋コントロールバー）。
  Size get size => Size(_width, _width / playerAspect + controlBarHeight);

  void show(CommunityWork work) {
    _work = work;
    notifyListeners();
  }

  void close() {
    _work = null;
    notifyListeners();
  }

  void updatePosition(Offset position) {
    _position = position;
    notifyListeners();
  }

  /// リサイズ。幅だけを受け取り、高さは幅から導出する。
  ///
  /// [availableWidth]（画面幅など）が与えられた場合は、そこも上限にする。
  /// 画面より広いウィンドウは操作できなくなるため。
  void updateWidth(double width, {double? availableWidth}) {
    var upper = maxWidth;
    if (availableWidth != null && availableWidth < upper) {
      // 画面が最小幅より狭い端末では、最小幅のほうを優先する
      // （プレーヤーの最小サイズ要件は画面の都合では緩められない）。
      upper = availableWidth < minWidth ? minWidth : availableWidth;
    }
    _width = width.clamp(minWidth, upper);
    notifyListeners();
  }
}
