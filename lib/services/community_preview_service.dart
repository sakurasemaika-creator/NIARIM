import 'dart:math' as math;

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

  /// 埋め込みプレーヤーの最小の一辺（YouTubeの要件は200×200以上）。
  static const double minPlayerSide = 200;

  /// 動画エリアの大きさ（この矩形の上には何も重ねてはいけない）。
  Size get playerSize => playerSizeFor(double.infinity);

  /// ウィンドウ全体の大きさ（動画エリア＋コントロールバー）。
  Size get size => sizeFor(double.infinity);

  /// 幅[availableWidth]の画面での動画エリア。画面が[minWidth]より狭い
  /// 端末（幅320〜355の端末、表示サイズを大きくした端末）では画面の幅に
  /// 合わせ、高さは[minPlayerSide]を保つ（16:9より少し縦長になり、動画は
  /// 上下に余白を付けて収まる）。以前は最小幅のまま画面からはみ出し、
  /// 「詳細へ」と拡大縮小の取っ手が画面の外に出ていた。
  Size playerSizeFor(double availableWidth) {
    final width = math.max(math.min(_width, availableWidth), minPlayerSide);
    return Size(width, math.max(width / playerAspect, minPlayerSide));
  }

  /// 幅[availableWidth]の画面でのウィンドウ全体の大きさ。
  Size sizeFor(double availableWidth) {
    final player = playerSizeFor(availableWidth);
    return Size(player.width, player.height + controlBarHeight);
  }

  /// 利用者がウィンドウを動かしたか。
  bool _moved = false;

  /// [work]を開く。[top]を渡すと、利用者がまだウィンドウを動かしていなければ
  /// その高さに出す（開いた画面の上部のバーやタブを覆わないため）。
  void show(CommunityWork work, {double? top}) {
    _work = work;
    if (!_moved && top != null) _position = Offset(_position.dx, top);
    notifyListeners();
  }

  void close() {
    _work = null;
    notifyListeners();
  }

  void updatePosition(Offset position) {
    _position = position;
    _moved = true;
    notifyListeners();
  }

  /// リサイズ。幅だけを受け取り、高さは幅から導出する。
  ///
  /// [availableWidth]（画面幅など）が与えられた場合は、そこも上限にする。
  /// 画面より広いウィンドウは操作できなくなるため。
  void updateWidth(double width, {double? availableWidth}) {
    var upper = maxWidth;
    if (availableWidth != null && availableWidth < upper) {
      upper = math.max(availableWidth, minPlayerSide);
    }
    // 画面が最小幅より狭い端末では画面の幅まで（高さは[playerSizeFor]が
    // 最小の一辺を保つ）。
    _width = width.clamp(math.min(minWidth, upper), upper);
    notifyListeners();
  }
}
