import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/models/ruler.dart';

/// 定規スナップ（Task#78で対応した透視定規の消失点スナップ・楕円/集中線の
/// 回転反映）が実際に狙い通りの座標を返すことを機械的に検証する。実機での
/// 目視確認ができない開発環境のため、幾何計算の正しさをテストで担保する。
void main() {
  test('直線定規：回転した直線上へ正しく投影される', () {
    final engine = RulerEngine();
    engine.setActiveRuler(
      Ruler(
        type: RulerType.line,
        position: const Offset(100, 100),
        rotation: math.pi / 2, // 垂直線
        settings: const RulerSettings(),
      ),
    );
    final snapped = engine.snapToRuler(const Offset(150, 200));
    // 垂直線上（x=100固定）に投影されるはず
    expect(snapped.dx, closeTo(100, 0.001));
    expect(snapped.dy, closeTo(200, 0.001));
  });

  test('楕円定規：回転を考慮して楕円周上へスナップされる', () {
    final engine = RulerEngine();
    engine.setActiveRuler(
      Ruler(
        type: RulerType.ellipse,
        position: const Offset(0, 0),
        rotation: math.pi / 2, // 90度回転（横幅・縦幅が入れ替わる）
        settings: const RulerSettings(radiusX: 100, radiusY: 50),
      ),
    );
    // 90度回転しているため、ワールド座標のY軸方向がローカルのX軸（半径100）になる
    final snapped = engine.snapToRuler(const Offset(0, 200));
    expect(snapped.dx, closeTo(0, 1));
    expect(snapped.dy, closeTo(100, 1));
  });

  test('集中線定規：回転角度がスポーク基準角に反映される', () {
    final engine = RulerEngine();
    engine.setActiveRuler(
      Ruler(
        type: RulerType.radial,
        position: const Offset(0, 0),
        rotation: 0.1,
        settings: const RulerSettings(divisions: 4),
      ),
    );
    // 4分割・回転なしなら0, pi/2, pi, 3pi/2にスナップするが、
    // rotation=0.1が加算されるため、角度0.1近辺の点は0.1へスナップされる。
    final snapped = engine.snapToRuler(const Offset(100, 5));
    final angle = snapped.direction;
    expect(angle, closeTo(0.1, 0.01));
  });

  test('1点透視定規：ストローク開始点と消失点を結ぶ直線へスナップし続ける', () {
    final engine = RulerEngine();
    final vp = const Offset(500, 500);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.onePointPerspective,
        position: vp,
        settings: RulerSettings(vanishingPoint1: vp),
      ),
    );
    engine.beginStroke();
    // 最初の点：そのまま返り、以後のスナップ基準（直線）を確定する
    final first = engine.snapToRuler(const Offset(100, 300));
    expect(first, const Offset(100, 300));
    // 2点目：消失点(500,500)と最初の点(100,300)を結ぶ直線上へ投影される
    final second = engine.snapToRuler(const Offset(300, 700));
    // 直線の方向ベクトル
    final dir = (first - vp);
    final normDir = dir / dir.distance;
    final rel = second - vp;
    final projection = rel.dx * normDir.dx + rel.dy * normDir.dy;
    final expected = vp + normDir * projection;
    expect(second.dx, closeTo(expected.dx, 0.01));
    expect(second.dy, closeTo(expected.dy, 0.01));
  });

  test('1点透視定規：新しいストローク開始でスナップ基準がリセットされる', () {
    final engine = RulerEngine();
    final vp = const Offset(0, 0);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.onePointPerspective,
        position: vp,
        settings: RulerSettings(vanishingPoint1: vp),
      ),
    );
    engine.beginStroke();
    engine.snapToRuler(const Offset(100, 0)); // 1本目：水平線を確定
    final duringFirstStroke = engine.snapToRuler(const Offset(100, 50));
    expect(duringFirstStroke.dy, closeTo(0, 0.001)); // 水平線上に投影される

    engine.beginStroke(); // 2本目のストローク開始：基準をリセット
    final newAnchor = engine.snapToRuler(const Offset(0, 100));
    expect(newAnchor, const Offset(0, 100)); // 新しい基準点としてそのまま返る
  });

  test('2点透視定規：最初の点に近い消失点が選ばれる', () {
    final engine = RulerEngine();
    final vp1 = const Offset(0, 0);
    final vp2 = const Offset(1000, 0);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.twoPointPerspective,
        position: const Offset(500, 0),
        settings: RulerSettings(vanishingPoint1: vp1, vanishingPoint2: vp2),
      ),
    );
    engine.beginStroke();
    // vp1に近い点から開始
    final first = engine.snapToRuler(const Offset(50, 50));
    expect(first, const Offset(50, 50));
    // 以後の点はvp1を通る直線へスナップされるはず
    final second = engine.snapToRuler(const Offset(100, 200));
    final dir = (first - vp1);
    final normDir = dir / dir.distance;
    final rel = second - vp1;
    final projection = rel.dx * normDir.dx + rel.dy * normDir.dy;
    final expected = vp1 + normDir * projection;
    expect(second.dx, closeTo(expected.dx, 0.01));
    expect(second.dy, closeTo(expected.dy, 0.01));
  });

  test('定規なしの場合はそのまま座標を返す', () {
    final engine = RulerEngine();
    expect(engine.snapToRuler(const Offset(42, 24)), const Offset(42, 24));
  });
}
