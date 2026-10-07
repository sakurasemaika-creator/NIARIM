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
  Offset? _strokeVp;

  // 魚眼パース定規用：ストロークが沿う線（描き始めの向きで決める）と、
  // 向きを決めるまでに動く距離（キャンバスpx）。
  FisheyeCurve? _strokeCurve;
  double _directionDistance = 8;

  void setActiveRuler(Ruler? ruler) {
    _activeRuler = ruler;
    _strokeAnchor = null;
    _strokeVp = null;
    _strokeCurve = null;
  }

  /// 1回のドラッグ（ストローク）開始時に呼び出す。透視定規のスナップ基準を
  /// リセットし、次のsnapToRuler呼び出しが新しいストロークの開始点として
  /// 扱われるようにする。[directionDistance]は、魚眼パース定規でどの線に
  /// 沿うかを決めるまでに動く距離（キャンバスpx。画面上で一定になるよう
  /// 呼び出し側が拡大率から決める）。
  void beginStroke({double? directionDistance}) {
    _strokeAnchor = null;
    _strokeVp = null;
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
      RulerType.onePointPerspective => _snapToPerspective(point, [
        settings.vanishingPoint1 ?? ruler.position,
      ]),
      RulerType.twoPointPerspective => _snapToPerspective(point, [
        settings.vanishingPoint1 ?? const Offset(200, 540),
        settings.vanishingPoint2 ?? const Offset(1720, 540),
      ]),
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
    final angle = atan2(localDy, localDx);
    final localX = rx * cos(angle);
    final localY = ry * sin(angle);
    final wc = cos(ruler.rotation);
    final ws = sin(ruler.rotation);
    return Offset(
      ruler.position.dx + localX * wc - localY * ws,
      ruler.position.dy + localX * ws + localY * wc,
    );
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

  /// 透視定規（1〜3点透視）：消失点から放射状に伸びる直線へスナップする。
  /// ストロークの最初の点で「どの消失点に向かう直線か」を、最も近い消失点を
  /// 選ぶことで決定し（1点透視では常に単一の消失点）、以後の点は同じ直線上へ
  /// 投影し続ける。これにより1本のストロークが常にまっすぐ消失点へ向かう
  /// 直線として描画される。
  Offset _snapToPerspective(Offset point, List<Offset> vanishingPoints) {
    if (_strokeAnchor == null) {
      Offset bestVp = vanishingPoints.first;
      double bestDist = double.infinity;
      for (final vp in vanishingPoints) {
        final d = (point - vp).distance;
        if (d < bestDist) {
          bestDist = d;
          bestVp = vp;
        }
      }
      _strokeAnchor = point;
      _strokeVp = bestVp;
      return point;
    }
    final vp = _strokeVp ?? vanishingPoints.first;
    final dirRaw = _strokeAnchor! - vp;
    if (dirRaw.distance < 1e-6) return point;
    final dir = dirRaw / dirRaw.distance;
    final rel = point - vp;
    final projection = rel.dx * dir.dx + rel.dy * dir.dy;
    return vp + dir * projection;
  }
}
