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

  Size _size = const Size(220, 160);
  Size get size => _size;

  static const Size minSize = Size(160, 120);
  static const Size maxSize = Size(420, 320);

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

  void updateSize(Size size) {
    _size = Size(
      size.width.clamp(minSize.width, maxSize.width),
      size.height.clamp(minSize.height, maxSize.height),
    );
    notifyListeners();
  }
}
