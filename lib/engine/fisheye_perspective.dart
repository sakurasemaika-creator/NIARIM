import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// 魚眼パース（5点の曲線透視）の幾何。
///
/// 座標はすべて**ローカル座標**：魚眼の中心が原点、定規の回転を戻した向き
/// （x＝右、y＝下）。半径[radius]の円が「レンズの縁」で、
/// - 横の線（水平方向に伸びる直線の写り方）は、左右の消失点(±R, 0)を通る円弧
/// - 縦の線（垂直方向に伸びる直線）は、上下の消失点(0, ±R)を通る円弧
/// - 奥行きの線（視線方向に伸びる直線）は、中心（5つ目の消失点）を通る直線
///
/// になる。任意の点を通る線は、各方向にちょうど1本ずつある。
enum FisheyeDirection { horizontal, vertical, depth }

/// 魚眼パースのガイド線1本（円か直線）。
@immutable
class FisheyeCurve {
  /// 中心[center]・半径[radius]の円。
  const FisheyeCurve.circle(Offset this.center, double this.radius)
    : point = null,
      direction = null;

  /// [point]を通り[direction]（長さ1）へ伸びる直線。
  const FisheyeCurve.line(Offset this.point, Offset this.direction)
    : center = null,
      radius = null;

  final Offset? center;
  final double? radius;
  final Offset? point;
  final Offset? direction;

  bool get isLine => point != null;

  /// [q]をこの線の上の最も近い点へ移す。
  Offset project(Offset q) {
    if (isLine) {
      final d = direction!;
      final rel = q - point!;
      return point! + d * (rel.dx * d.dx + rel.dy * d.dy);
    }
    final c = center!;
    final v = q - c;
    final length = v.distance;
    if (length < 1e-9) return c + Offset(radius!, 0);
    return c + v * (radius! / length);
  }

  /// [p]（この線の上の点）での接線の向き（長さ1）。
  Offset tangentAt(Offset p) {
    if (isLine) return direction!;
    final n = p - center!;
    final length = n.distance;
    if (length < 1e-9) return const Offset(1, 0);
    return Offset(-n.dy / length, n.dx / length);
  }
}

/// [p]を通る、[direction]方向のガイド線。
FisheyeCurve fisheyeCurveThrough(
  FisheyeDirection direction,
  Offset p,
  double radius,
) {
  // ほぼ軸の上（円の中心が遠すぎて誤差が出る）なら直線として扱う。
  final straight = radius * 1e-3;
  switch (direction) {
    case FisheyeDirection.horizontal:
      // 中心(0, k)の円が(±R, 0)と p=(u, v)を通る：k = (u²+v²−R²)/2v。
      if (p.dy.abs() < straight) {
        return FisheyeCurve.line(p, const Offset(1, 0));
      }
      final k = (p.dx * p.dx + p.dy * p.dy - radius * radius) / (2 * p.dy);
      return FisheyeCurve.circle(
        Offset(0, k),
        math.sqrt(radius * radius + k * k),
      );
    case FisheyeDirection.vertical:
      if (p.dx.abs() < straight) {
        return FisheyeCurve.line(p, const Offset(0, 1));
      }
      final k = (p.dx * p.dx + p.dy * p.dy - radius * radius) / (2 * p.dx);
      return FisheyeCurve.circle(
        Offset(k, 0),
        math.sqrt(radius * radius + k * k),
      );
    case FisheyeDirection.depth:
      final length = p.distance;
      if (length < straight) {
        return const FisheyeCurve.line(Offset.zero, Offset(1, 0));
      }
      return FisheyeCurve.line(p, p / length);
  }
}

/// [p]から[movement]の向きへ描き始めたストロークが沿うガイド線：
/// [p]を通る3本のうち、接線が[movement]に最も近いもの。中心では奥行きの
/// 線が無数にあるので、動いた向きの直線にする。
FisheyeCurve fisheyeCurveAlong(Offset p, Offset movement, double radius) {
  final length = movement.distance;
  if (length < 1e-9) {
    return fisheyeCurveThrough(FisheyeDirection.horizontal, p, radius);
  }
  final move = movement / length;
  if (p.distance < radius * 1e-3) return FisheyeCurve.line(p, move);
  FisheyeCurve? best;
  var bestScore = -1.0;
  for (final direction in FisheyeDirection.values) {
    final curve = fisheyeCurveThrough(direction, p, radius);
    final t = curve.tangentAt(p);
    final score = (t.dx * move.dx + t.dy * move.dy).abs();
    if (score > bestScore) {
      bestScore = score;
      best = curve;
    }
  }
  return best!;
}

/// 定規として画面に出すガイド線（ローカル座標）：レンズの縁の円、
/// 横と縦の円弧をそれぞれ中心から縁まで[steps]本ずつの間隔で、
/// 奥行きの線を45°おきに8本。
Path fisheyeGuidePath(double radius, {int steps = 4}) {
  final path = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
  void arcThrough(Offset a, Offset b, Offset through) {
    final curve = fisheyeCurveThrough(
      a.dy == 0 ? FisheyeDirection.horizontal : FisheyeDirection.vertical,
      through,
      radius,
    );
    if (curve.isLine) {
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
      return;
    }
    final c = curve.center!;
    final start = (a - c).direction;
    final end = (b - c).direction;
    final mid = (through - c).direction;
    const full = 2 * math.pi;
    final toEnd = (end - start) % full;
    final sweep = (mid - start) % full < toEnd ? toEnd : toEnd - full;
    path.addArc(
      Rect.fromCircle(center: c, radius: curve.radius!),
      start,
      sweep,
    );
  }

  for (var i = -(steps - 1); i <= steps - 1; i++) {
    final offset = radius * i / steps;
    arcThrough(Offset(-radius, 0), Offset(radius, 0), Offset(0, offset));
    arcThrough(Offset(0, -radius), Offset(0, radius), Offset(offset, 0));
  }
  for (var i = 0; i < 8; i++) {
    path
      ..moveTo(0, 0)
      ..lineTo(
        radius * math.cos(i * math.pi / 4),
        radius * math.sin(i * math.pi / 4),
      );
  }
  return path;
}
