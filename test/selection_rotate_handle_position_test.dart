import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

/// 回転ハンドルの位置計算の不変条件を守る。
///
/// 「全選択（＝選択範囲がキャンバス端まで届く）でも必ず選択範囲の外側」
/// 「四隅の拡大縮小ハンドルと当たり判定が重ならない」の2点が壊れると、
/// 角を掴んだつもりで回転してしまう。実操作でしか気付けない類の不具合
/// なので、幾何だけをここで機械的に見張る。
void main() {
  const r = 8.0;
  const scaleR = 5.0;

  Rect reachableOf(Size widget, Rect drawing, Size canvas) {
    final sx = canvas.width / drawing.width;
    final sy = canvas.height / drawing.height;
    return Rect.fromLTRB(
      -drawing.left * sx,
      -drawing.top * sy,
      (widget.width - drawing.left) * sx,
      (widget.height - drawing.top) * sy,
    );
  }

  test('余白があるときはキャンバスの外側へ出してよい（ピラーボックス）', () {
    // 横に余白があるレイアウト。全選択でも右へ素直に離れる。
    const canvas = Size(400, 600);
    final reachable = reachableOf(
      const Size(500, 600),
      const Rect.fromLTWH(50, 0, 400, 600),
      canvas,
    );
    final bounds = Offset.zero & canvas;
    final h = selectionRotateHandleOf(bounds, r, reachable: reachable);

    expect(h.dx, greaterThan(canvas.width), reason: 'キャンバスの外側へ出る');
    expect(h.dx, lessThanOrEqualTo(reachable.right), reason: 'ウィジェットの内側');
  });

  test('余白が無い側は指が届く範囲まで寄せる（レターボックス）', () {
    // 縦に余白があるレイアウト。横は余白ゼロなので右へは出せない。
    const canvas = Size(400, 300);
    final reachable = reachableOf(
      const Size(400, 400),
      const Rect.fromLTWH(0, 50, 400, 300),
      canvas,
    );
    final bounds = Offset.zero & canvas;
    final h = selectionRotateHandleOf(bounds, r, reachable: reachable);

    expect(h.dx, lessThanOrEqualTo(reachable.right), reason: 'ウィジェットの内側');
    expect(h.dy, lessThan(bounds.top), reason: '上方向には必ず離れている');
  });

  test('全選択でも四隅のハンドルと当たり判定が重ならない', () {
    for (final canvas in const [
      Size(400, 600),
      Size(400, 300),
      Size(1920, 1080),
      Size(96, 96),
    ]) {
      for (final widget in const [
        Size(500, 600),
        Size(400, 400),
        Size(360, 760),
      ]) {
        final fit = canvas.width / canvas.height > widget.width / widget.height
            ? Size(widget.width, widget.width * canvas.height / canvas.width)
            : Size(widget.height * canvas.width / canvas.height, widget.height);
        final drawing = Rect.fromLTWH(
          (widget.width - fit.width) / 2,
          (widget.height - fit.height) / 2,
          fit.width,
          fit.height,
        );
        final bounds = Offset.zero & canvas;
        final h = selectionRotateHandleOf(
          bounds,
          r,
          reachable: reachableOf(widget, drawing, canvas),
        );
        for (final corner in selectionScaleHandlesOf(bounds)) {
          expect(
            (h - corner).distance,
            greaterThan(scaleR),
            reason: 'canvas=$canvas widget=$widget で回転ハンドルが角と重なった',
          );
        }
      }
    }
  });

  test('寄せきったときも回転ハンドルの円がウィジェット外へ欠けない', () {
    // 横に余白が無いレイアウト＝右へ寄せきる場面。余白の確保に四隅の
    // 半径（より小さい）を使うと、差分ぶんだけ円が画面外で欠ける。
    const canvas = Size(400, 300);
    final reachable = reachableOf(
      const Size(400, 400),
      const Rect.fromLTWH(0, 50, 400, 300),
      canvas,
    );
    final bounds = Offset.zero & canvas;
    const rotateR = 14.0;
    final h = selectionRotateHandleOf(
      bounds,
      r,
      rotateRadius: rotateR,
      reachable: reachable,
    );

    expect(
      h.dx + rotateR,
      lessThanOrEqualTo(reachable.right + 0.001),
      reason: '回転ハンドルの円の右端がウィジェットの内側に収まる',
    );
  });

  test('ハンドル半径は画面px基準で、拡大率が上がるほどキャンバスpxでは小さくなる', () {
    expect(selectionHandleRadiusFor(1.0), kSelectionHandleScreenRadius);
    expect(selectionHandleRadiusFor(2.0), kSelectionHandleScreenRadius / 2);
    expect(
      selectionRotateHandleRadiusFor(1.0),
      kSelectionRotateHandleScreenRadius,
    );
    // 回転ハンドルは四隅より大きく、掴み分けられる。
    expect(
      kSelectionRotateHandleScreenRadius,
      greaterThan(kSelectionHandleScreenRadius),
    );
  });
}
