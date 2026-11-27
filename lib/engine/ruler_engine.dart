import 'dart:math';
import 'dart:ui';

import '../models/ruler.dart';
import 'fisheye_perspective.dart';

class RulerEngine {
  Ruler? _activeRuler;
  Ruler? get activeRuler => _activeRuler;

  // 透視定規（1〜3点透視）用：1ストローク中は最初に決定した消失点・直線を
  // 維持し続けるための状態（消失点へ向かう直線に沿って描画補助する）。
  Offset? _strokeAnchor;

  /// The direction of the guide line the stroke follows (unit length).
  Offset? _strokeGuide;

  // 魚眼パース定規用：ストロークが沿う線（描き始めの向きで決める）と、
  // 向きを決めるまでに動く距離（キャンバスpx）。
  FisheyeCurve? _strokeCurve;
  double _directionDistance = 8;

  void setActiveRuler(Ruler? ruler) {
    _activeRuler = ruler;
    _strokeAnchor = null;
    _strokeGuide = null;
    _strokeCurve = null;
  }

  /// 1回のドラッグ（ストローク）開始時に呼び出す。透視定規のスナップ基準を
  /// リセットし、次のsnapToRuler呼び出しが新しいストロークの開始点として
  /// 扱われるようにする。[directionDistance]は、魚眼パース定規でどの線に
  /// 沿うかを決めるまでに動く距離（キャンバスpx。画面上で一定になるよう
  /// 呼び出し側が拡大率から決める）。
  void beginStroke({double? directionDistance}) {
    _strokeAnchor = null;
    _strokeGuide = null;
    _strokeCurve = null;
    if (directionDistance != null) _directionDistance = directionDistance;
  }

  Offset snapToRuler(Offset point) {
    final ruler = _activeRuler;
    // Snap is independent from ruler visibility/existence. Keeping the active
    // ruler here lets its guide and handles remain usable while brush input is
    // temporarily freehand, then resume against the exact same ruler.
    if (ruler == null || !ruler.snapEnabled) return point;
    final settings = ruler.settings;
    return switch (ruler.type) {
      RulerType.line => _snapToLine(point),
      RulerType.circle => _snapToCircle(point),
      RulerType.ellipse => _snapToEllipse(point),
      RulerType.radial => _snapToRadial(point),
      RulerType.onePointPerspective => _snapToPerspective(
        point,
        [settings.vanishingPoint1 ?? ruler.position],
        horizontal: true,
        vertical: true,
      ),
      RulerType.twoPointPerspective => _snapToPerspective(point, [
        settings.vanishingPoint1 ?? const Offset(200, 540),
        settings.vanishingPoint2 ?? const Offset(1720, 540),
      ], vertical: true),
      RulerType.threePointPerspective => _snapToPerspective(point, [
        settings.vanishingPoint1 ?? const Offset(200, 540),
        settings.vanishingPoint2 ?? const Offset(1720, 540),
        settings.vanishingPoint3 ?? const Offset(960, 100),
      ]),
      RulerType.fisheyePerspective => _snapToFisheye(point, ruler),
    };
  }

  /// 魚眼パース定規：描き始めの点を通る3本の線（横の円弧・縦の円弧・
  /// 中心を通る直線）のうち、描き始めた向きに最も近い1本に沿わせる。
  /// 向きが決まるまで（[_directionDistance]動くまで）は描き始めの点に
  /// 留め、決まった後は同じ線の上へ投影し続ける。
  Offset _snapToFisheye(Offset point, Ruler ruler) {
    final radius = ruler.settings.radiusX ?? 300;
    final c = cos(ruler.rotation);
    final s = sin(ruler.rotation);
    Offset toLocal(Offset p) {
      final d = p - ruler.position;
      return Offset(d.dx * c + d.dy * s, -d.dx * s + d.dy * c);
    }

    Offset toWorld(Offset p) =>
        ruler.position + Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);

    final anchor = _strokeAnchor;
    if (anchor == null) {
      _strokeAnchor = point;
      return point;
    }
    var curve = _strokeCurve;
    if (curve == null) {
      if ((point - anchor).distance < _directionDistance) return anchor;
      curve = _strokeCurve = fisheyeCurveAlong(
        toLocal(anchor),
        toLocal(point) - toLocal(anchor),
        radius,
      );
    }
    return toWorld(curve.project(toLocal(point)));
  }

  Offset _snapToLine(Offset point) {
    final ruler = _activeRuler!;
    final angle = ruler.rotation;
    final c = cos(angle);
    final s = sin(angle);
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final projection = dx * c + dy * s;
    return Offset(
      ruler.position.dx + projection * c,
      ruler.position.dy + projection * s,
    );
  }

  Offset _snapToCircle(Offset point) {
    final ruler = _activeRuler!;
    final radius = ruler.settings.radiusX ?? 100;
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return point;
    return Offset(
      ruler.position.dx + dx / dist * radius,
      ruler.position.dy + dy / dist * radius,
    );
  }

  Offset _snapToEllipse(Offset point) {
    final ruler = _activeRuler!;
    final rx = ruler.settings.radiusX ?? 100;
    final ry = ruler.settings.radiusY ?? 60;
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    // rotationは楕円全体の回転角度（楕円定規の回転）。
    // 一旦楕円のローカル座標系（回転前）へ変換してから楕円上の最近傍角度を求め、
    // 再度ワールド座標へ回転させて戻す。
    final cr = cos(-ruler.rotation);
    final sr = sin(-ruler.rotation);
    final localDx = dx * cr - dy * sr;
    final localDy = dx * sr + dy * cr;
    if (rx <= 0 || ry <= 0) return point;
    final angle = atan2(localDy / ry, localDx / rx);
    return _fromEllipseAngle(ruler.position, rx, ry, cr, -sr, angle);
  }

  /// Intermediate points on the short arc between two snapped samples.
  /// The maximum radius bounds how far each chord can leave the guide.
  List<Offset> arcBetween(Offset from, Offset to) {
    final ruler = _activeRuler;
    if (ruler == null || !ruler.snapEnabled) return const [];
    if (ruler.type == RulerType.fisheyePerspective) {
      final curve = _strokeCurve;
      final localCenter = curve?.center;
      final radius = curve?.radius;
      if (localCenter == null || radius == null) return const [];
      final c = cos(ruler.rotation), s = sin(ruler.rotation);
      final center =
          ruler.position +
          Offset(
            localCenter.dx * c - localCenter.dy * s,
            localCenter.dx * s + localCenter.dy * c,
          );
      return _arcOnEllipse(from, to, center, radius, radius, 1, 0);
    }
    if (ruler.type != RulerType.circle && ruler.type != RulerType.ellipse) {
      return const [];
    }
    final rx = ruler.settings.radiusX ?? 100;
    final ry = ruler.type == RulerType.circle
        ? rx
        : ruler.settings.radiusY ?? 60;
    final c = ruler.type == RulerType.circle ? 1.0 : cos(ruler.rotation);
    final s = ruler.type == RulerType.circle ? 0.0 : sin(ruler.rotation);
    return _arcOnEllipse(from, to, ruler.position, rx, ry, c, s);
  }

  List<Offset> _arcOnEllipse(
    Offset from,
    Offset to,
    Offset center,
    double rx,
    double ry,
    double c,
    double s,
  ) {
    if (rx <= 0 || ry <= 0 || !rx.isFinite || !ry.isFinite) return const [];
    double angle(Offset point) {
      final d = point - center;
      return atan2((-d.dx * s + d.dy * c) / ry, (d.dx * c + d.dy * s) / rx);
    }

    final start = angle(from);
    final sweep = (angle(to) - start + pi) % (2 * pi) - pi;
    if (!sweep.isFinite) return const [];
    final segments = (sweep.abs() * sqrt(max(rx, ry))).ceil().clamp(1, 512);
    return [
      for (var index = 1; index < segments; index++)
        _fromEllipseAngle(
          center,
          rx,
          ry,
          c,
          s,
          start + sweep * index / segments,
        ),
    ];
  }

  Offset _fromEllipseAngle(
    Offset center,
    double rx,
    double ry,
    double c,
    double s,
    double angle,
  ) {
    final x = rx * cos(angle);
    final y = ry * sin(angle);
    return center + Offset(x * c - y * s, x * s + y * c);
  }

  Offset _snapToRadial(Offset point) {
    final ruler = _activeRuler!;
    final divisions = ruler.settings.divisions ?? 8;
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    // rotationは各スポークの基準角度のオフセット（回転角度は変更可能）。
    final angle = atan2(dy, dx) - ruler.rotation;
    final sliceAngle = 2 * pi / divisions;
    final snappedAngle =
        (angle / sliceAngle).round() * sliceAngle + ruler.rotation;
    final dist = sqrt(dx * dx + dy * dy);
    return Offset(
      ruler.position.dx + dist * cos(snappedAngle),
      ruler.position.dy + dist * sin(snappedAngle),
    );
  }

  /// 透視定規（1〜3点透視）：描き始めの点を通る案内線（各消失点へ向かう
  /// 直線、1点透視では水平・垂直、2点透視では垂直も）のうち、描き始めた
  /// 向きに最も近い1本に沿わせる。向きが決まるまで（[_directionDistance]
  /// 動くまで）は描き始めの点に留め、決まった後は同じ線の上へ投影し続ける。
  ///
  /// 以前は描き始めの点に最も近い消失点の線に決めていたため、2点透視で
  /// 遠い方の消失点へ向かう線・垂直の線、1点透視で水平の線が引けなかった。
  Offset _snapToPerspective(
    Offset point,
    List<Offset> vanishingPoints, {
    bool horizontal = false,
    bool vertical = false,
  }) {
    final anchor = _strokeAnchor;
    if (anchor == null) {
      _strokeAnchor = point;
      return point;
    }
    var guide = _strokeGuide;
    if (guide == null) {
      final drawn = point - anchor;
      if (drawn.distance < _directionDistance) return anchor;
      final along = drawn / drawn.distance;
      // The angle between the drawn direction and a line (either way along
      // it).
      double angleTo(Offset line) =>
          acos((line.dx * along.dx + line.dy * along.dy).abs().clamp(0.0, 1.0));
      Offset? best;
      var bestAngle = double.infinity;
      for (final vp in vanishingPoints) {
        final toVp = vp - anchor;
        if (toVp.distance < 1e-6) continue;
        final line = toVp / toVp.distance;
        final angle = angleTo(line);
        if (angle < bestAngle) {
          bestAngle = angle;
          best = line;
        }
      }
      // Horizontal and vertical help where no vanishing point's line goes:
      // taken only when clearly closer (a line to the vanishing point a few
      // degrees off vertical is not told apart from vertical by the start of
      // a stroke).
      const margin = 8 * pi / 180;
      for (final axis in [
        if (horizontal) const Offset(1, 0),
        if (vertical) const Offset(0, 1),
      ]) {
        final angle = angleTo(axis);
        if (best == null || angle + margin < bestAngle) {
          bestAngle = angle;
          best = axis;
        }
      }
      if (best == null) return point;
      guide = _strokeGuide = best;
    }
    final rel = point - anchor;
    return anchor + guide * (rel.dx * guide.dx + rel.dy * guide.dy);
  }
}
