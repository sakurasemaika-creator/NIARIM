import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/community_preview_service.dart';

void main() {
  // YouTubeの埋め込みプレーヤーには最小200×200pxの要件がある。
  // 動画エリアがこれを割ると規約を満たせないため、利用者がリサイズ
  // ハンドルをどう動かしても割れないことを機械的に確かめる。
  const minPlayerSide = 200.0;

  test('既定サイズで動画エリアが200×200を満たす', () {
    final s = CommunityPreviewService();
    expect(s.playerSize.width, greaterThanOrEqualTo(minPlayerSide));
    expect(s.playerSize.height, greaterThanOrEqualTo(minPlayerSide));
  });

  test('どこまで縮めても動画エリアは200×200を割らない', () {
    final s = CommunityPreviewService();
    for (final w in [-9999.0, 0.0, 1.0, 100.0, 355.0, 356.0]) {
      s.updateWidth(w);
      expect(
        s.playerSize.height,
        greaterThanOrEqualTo(minPlayerSide),
        reason: '幅$wへ縮めたとき動画エリアの高さが${s.playerSize.height}',
      );
      expect(s.playerSize.width, greaterThanOrEqualTo(minPlayerSide));
    }
  });

  test('画面が最小幅より狭い端末では画面の幅に合わせ、200×200は保つ', () {
    // 以前は最小幅356のまま画面からはみ出し、「詳細へ」と拡大縮小の
    // 取っ手が画面の外に出ていた。高さを200に保てば要件は満たせる。
    final s = CommunityPreviewService();
    s.updateWidth(1000, availableWidth: 320);
    expect(s.width, 320);
    final fresh = CommunityPreviewService();
    for (final screen in [320.0, 340.0, 355.0]) {
      final player = fresh.playerSizeFor(screen);
      expect(player.width, screen);
      expect(player.width, greaterThanOrEqualTo(minPlayerSide));
      expect(player.height, greaterThanOrEqualTo(minPlayerSide));
      expect(fresh.sizeFor(screen).width, lessThanOrEqualTo(screen));
    }
  });

  test('画面幅より広くはならない', () {
    final s = CommunityPreviewService();
    s.updateWidth(9999, availableWidth: 400);
    expect(s.width, lessThanOrEqualTo(400));
  });

  test('最大幅を超えない', () {
    final s = CommunityPreviewService();
    s.updateWidth(9999);
    expect(s.width, CommunityPreviewService.maxWidth);
  });

  test('ウィンドウ高さ＝動画エリア＋コントロールバー', () {
    // コントロールバーは動画エリアの「外側」にある。ここにボタンを置く
    // ことで、プレーヤーの上に何も重ねずに「詳細へ」等を出せる。
    final s = CommunityPreviewService();
    expect(
      s.size.height,
      closeTo(
        s.playerSize.height + CommunityPreviewService.controlBarHeight,
        0.001,
      ),
    );
    expect(s.size.width, s.playerSize.width);
  });

  test('リサイズすると通知が飛ぶ', () {
    final s = CommunityPreviewService();
    var notified = 0;
    s.addListener(() => notified++);
    s.updateWidth(500);
    expect(notified, 1);
    expect(s.width, 500);
  });

  test('16:9が保たれる', () {
    final s = CommunityPreviewService();
    for (final w in [356.0, 400.0, 640.0]) {
      s.updateWidth(w);
      expect(
        s.playerSize.width / s.playerSize.height,
        closeTo(CommunityPreviewService.playerAspect, 0.001),
      );
    }
  });
}
