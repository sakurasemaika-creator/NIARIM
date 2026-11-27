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

  // 透視定規は、描き始めて向きが決まった（既定で8px動いた）ところで、
  // 描き始めの点を通る案内線のうち向きの最も近い1本に沿わせる。
  Offset along(Offset anchor, Offset dir, Offset point) {
    final unit = dir / dir.distance;
    final rel = point - anchor;
    return anchor + unit * (rel.dx * unit.dx + rel.dy * unit.dy);
  }

  void expectNear(Offset actual, Offset expected) {
    expect(actual.dx, closeTo(expected.dx, 0.01));
    expect(actual.dy, closeTo(expected.dy, 0.01));
  }

  test('1点透視定規：消失点へ向かって描くと消失点の線に沿う', () {
    final engine = RulerEngine();
    const vp = Offset(500, 500);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.onePointPerspective,
        position: vp,
        settings: RulerSettings(vanishingPoint1: vp),
      ),
    );
    engine.beginStroke();
    const first = Offset(100, 300);
    expect(engine.snapToRuler(first), first);
    // 向きが決まるまでは描き始めの点に留まる。
    expect(engine.snapToRuler(const Offset(103, 302)), first);
    final second = engine.snapToRuler(const Offset(300, 420));
    expectNear(second, along(first, vp - first, const Offset(300, 420)));
  });

  test('1点透視定規：横・縦に描くと水平・垂直の線に沿う', () {
    final engine = RulerEngine();
    const vp = Offset(500, 500);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.onePointPerspective,
        position: vp,
        settings: RulerSettings(vanishingPoint1: vp),
      ),
    );
    engine.beginStroke();
    engine.snapToRuler(const Offset(100, 300));
    expectNear(
      engine.snapToRuler(const Offset(300, 310)),
      const Offset(300, 300),
    );
    engine.beginStroke();
    engine.snapToRuler(const Offset(100, 300));
    expectNear(
      engine.snapToRuler(const Offset(95, 100)),
      const Offset(100, 100),
    );
  });

  test('1点透視定規：新しいストローク開始でスナップ基準がリセットされる', () {
    final engine = RulerEngine();
    const vp = Offset(0, 0);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.onePointPerspective,
        position: vp,
        settings: RulerSettings(vanishingPoint1: vp),
      ),
    );
    engine.beginStroke();
    engine.snapToRuler(const Offset(100, 0));
    final duringFirstStroke = engine.snapToRuler(const Offset(200, 20));
    expect(duringFirstStroke.dy, closeTo(0, 0.001)); // 水平線上に投影される

    engine.beginStroke(); // 2本目のストローク開始：基準をリセット
    final newAnchor = engine.snapToRuler(const Offset(0, 100));
    expect(newAnchor, const Offset(0, 100)); // 新しい基準点としてそのまま返る
  });

  test('2点透視定規：遠い方の消失点へ向かって描くとその線に沿い、縦にも引ける', () {
    final engine = RulerEngine();
    const vp1 = Offset(0, 0);
    const vp2 = Offset(1000, 0);
    engine.setActiveRuler(
      Ruler(
        type: RulerType.twoPointPerspective,
        position: const Offset(500, 0),
        settings: RulerSettings(vanishingPoint1: vp1, vanishingPoint2: vp2),
      ),
    );
    // vp1に近い点から、遠いvp2の方へ描く（以前はvp1の線に決まっていた）。
    engine.beginStroke();
    const first = Offset(50, 50);
    engine.snapToRuler(first);
    final towardFar = engine.snapToRuler(const Offset(400, 40));
    expectNear(towardFar, along(first, vp2 - first, const Offset(400, 40)));
    // 近いvp1の方へ描けばvp1の線。
    engine.beginStroke();
    engine.snapToRuler(const Offset(500, 300));
    expectNear(
      engine.snapToRuler(const Offset(400, 230)),
      along(
        const Offset(500, 300),
        vp1 - const Offset(500, 300),
        const Offset(400, 230),
      ),
    );
    // 縦に描けば垂直の線。
    engine.beginStroke();
    engine.snapToRuler(const Offset(500, 300));
    expectNear(
      engine.snapToRuler(const Offset(510, 500)),
      const Offset(500, 500),
    );
  });

  test('定規なしの場合はそのまま座標を返す', () {
    final engine = RulerEngine();
    expect(engine.snapToRuler(const Offset(42, 24)), const Offset(42, 24));
  });
}
