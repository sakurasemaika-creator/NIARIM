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

  // Desired width survives viewport changes. The view resolves the actual
  // bounds without mutating this state during layout.
  double _width = 356;
  double get width => _width;

  /// Preferred aspect ratio; narrow viewports retain a 200px player height.
  static const double playerAspect = 16 / 9;

  /// Minimum height of one controls row, outside the player rectangle.
  /// The view may use taller or multiple rows for localized, scaled text.
  static const double controlBarHeight = 48;

  /// YouTube requires a player viewport of at least 200 × 200.
  /// https://developers.google.com/youtube/iframe_api_reference#Requirements
  static const double minWidth = 200;

  /// 最大幅。画面幅を超えないよう、呼び出し側でさらに絞る。
  static const double maxWidth = 640;

  /// 動画エリアの大きさ（この矩形の上には何も重ねてはいけない）。
  Size get playerSize => Size(_width, playerHeightFor(_width));

  static double playerHeightFor(double width) =>
      math.max(minWidth, width / playerAspect);

  /// ウィンドウ全体の大きさ（動画エリア＋コントロールバー）。
  Size get size => Size(_width, playerSize.height + controlBarHeight);

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

  /// Resize within player limits. When even 200px is unavailable, the view
  /// presents controls and a details link without mounting a player.
  void updateWidth(double width, {double? availableWidth}) {
    var upper = maxWidth;
    if (availableWidth != null && availableWidth < upper) {
      upper = math.max(minWidth, availableWidth);
    }
    _width = width.clamp(minWidth, upper);
    notifyListeners();
  }
}
