import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 作品広場の作品の絵がまだ無い（読み込み中・YouTubeの絵を取れない・見本の
/// データ）ときに出す、手描きアニメのコマの下書き。
///
/// 用紙の上に、補助の文字色の線で動きの1コマ（はずむボール・波・振り子・
/// 光・歩く線・回転）を描き、前のコマを淡く重ねる（オニオンスキン）。
/// 以前は差し色のグラデーションで、見本の作品が並ぶ最初の画面が桃色の
/// 壁になっていた。差し色は押す操作と選んでいる状態に取っておく。
/// [variant]（作品ごとに決まる番号）で描くものを変え、並んだときに
/// 同じ絵が続かないようにする。
class CommunitySampleArtwork extends StatelessWidget {
  const CommunitySampleArtwork({super.key, required this.variant, this.child});

  final int variant;

  /// 絵の上に重ねるもの（YouTubeの絵。読み込めればこの下書きを覆う）。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: CustomPaint(
        painter: _SampleSketchPainter(
          variant: variant,
          ink: scheme.onSurfaceVariant,
          rule: scheme.outlineVariant,
        ),
        child: child == null ? null : SizedBox.expand(child: child),
      ),
    );
  }
}

class _SampleSketchPainter extends CustomPainter {
  const _SampleSketchPainter({
    required this.variant,
    required this.ink,
    required this.rule,
  });

  final int variant;
  final Color ink;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.shortestSide;
    final stroke = (unit / 60).clamp(1.2, 2.4);
    Paint pen(double alpha) => Paint()
      ..color = ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // 地の線（コマの下の端の目安）。
    final ground = size.height * .78;
    canvas.drawLine(
      Offset(size.width * .12, ground),
      Offset(size.width * .88, ground),
      Paint()
        ..color = rule
        ..strokeWidth = math.max(1, stroke * .6),
    );
    // 前のコマほど淡く（オニオンスキン）、最後が今のコマ。
    const ghosts = [.14, .24, .38, .7];
    switch (variant % 6) {
      case 0:
        // はずむボール。
        for (var i = 0; i < ghosts.length; i++) {
          final t = i / (ghosts.length - 1);
          final x = size.width * (.24 + .52 * t);
          final y = ground - unit * .1 - unit * .34 * math.sin(math.pi * t);
          canvas.drawCircle(Offset(x, y), unit * .07, pen(ghosts[i]));
        }
      case 1:
        // 波打つ線。
        for (var i = 0; i < ghosts.length; i++) {
          final path = Path();
          final phase = i * .6;
          for (var k = 0; k <= 24; k++) {
            final x = size.width * (.14 + .72 * k / 24);
            final y =
                size.height * .48 +
                unit * .12 * math.sin(k / 24 * 2 * math.pi + phase);
            k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
          }
          canvas.drawPath(path, pen(ghosts[i]));
        }
      case 2:
        // 振り子。
        final pivot = Offset(size.width / 2, size.height * .16);
        for (var i = 0; i < ghosts.length; i++) {
          final a = -.6 + 1.2 * i / (ghosts.length - 1);
          final bob = pivot + Offset(math.sin(a), math.cos(a)) * unit * .46;
          canvas.drawLine(pivot, bob, pen(ghosts[i] * .8));
          canvas.drawCircle(bob, unit * .06, pen(ghosts[i]));
        }
      case 3:
        // ひらく光。
        final c = Offset(size.width / 2, size.height * .46);
        for (var i = 0; i < ghosts.length; i++) {
          final r = unit * (.08 + .07 * i);
          for (var k = 0; k < 8; k++) {
            final a = k * math.pi / 4;
            final dir = Offset(math.cos(a), math.sin(a));
            canvas.drawLine(c + dir * r * .55, c + dir * r, pen(ghosts[i]));
          }
        }
      case 4:
        // 歩く線（脚の動き）。
        for (var i = 0; i < ghosts.length; i++) {
          final x = size.width * (.3 + .13 * i);
          final hip = Offset(x, ground - unit * .3);
          final swing = (i.isEven ? 1 : -1) * unit * .08;
          canvas.drawLine(hip, Offset(x + swing, ground), pen(ghosts[i]));
          canvas.drawLine(hip, Offset(x - swing, ground), pen(ghosts[i]));
          canvas.drawLine(hip, hip - Offset(0, unit * .2), pen(ghosts[i]));
          canvas.drawCircle(
            hip - Offset(0, unit * .26),
            unit * .05,
            pen(ghosts[i]),
          );
        }
      default:
        // 回る四角。
        final c = Offset(size.width / 2, size.height * .46);
        for (var i = 0; i < ghosts.length; i++) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(i * math.pi / 10);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: unit * .3,
                height: unit * .3,
              ),
              Radius.circular(unit * .03),
            ),
            pen(ghosts[i]),
          );
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(_SampleSketchPainter old) =>
      old.variant != variant || old.ink != ink || old.rule != rule;
}
