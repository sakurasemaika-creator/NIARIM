import 'dart:math';
import 'dart:ui';
import '../models/ruler.dart';

class RulerEngine {
  Ruler? _activeRuler;
  Ruler? get activeRuler => _activeRuler;

  // 透視定規（1〜3点透視）用：1ストローク中は最初に決定した消失点・直線を
  // 維持し続けるための状態（消失点へ向かう直線に沿って描画補助する）。
  Offset? _strokeAnchor;
  Offset? _strokeVp;

  void setActiveRuler(Ruler? ruler) {
    _activeRuler = ruler;
    _strokeAnchor = null;
    _strokeVp = null;
  }

  /// 1回のドラッグ（ストローク）開始時に呼び出す。透視定規のスナップ基準を
  /// リセットし、次のsnapToRuler呼び出しが新しいストロークの開始点として
  /// 扱われるようにする。
  void beginStroke() {
    _strokeAnchor = null;
    _strokeVp = null;
  }

  Offset snapToRuler(Offset point) {
    if (_activeRuler == null) return point;
    final settings = _activeRuler!.settings;
    return switch (_activeRuler!.type) {
      RulerType.line => _snapToLine(point),
      RulerType.circle => _snapToCircle(point),
      RulerType.ellipse => _snapToEllipse(point),
      RulerType.radial => _snapToRadial(point),
      RulerType.onePointPerspective => _snapToPerspective(
          point, [settings.vanishingPoint1 ?? _activeRuler!.position]),
      RulerType.twoPointPerspective => _snapToPerspective(point, [
          settings.vanishingPoint1 ?? const Offset(200, 540),
          settings.vanishingPoint2 ?? const Offset(1720, 540),
        ]),
      RulerType.threePointPerspective => _snapToPerspective(point, [
          settings.vanishingPoint1 ?? const Offset(200, 540),
          settings.vanishingPoint2 ?? const Offset(1720, 540),
          settings.vanishingPoint3 ?? const Offset(960, 100),
        ]),
    };
  }

  Offset _snapToLine(Offset point) {
    final ruler = _activeRuler!;
    final angle = ruler.rotation;
    final c = cos(angle);
    final s = sin(angle);
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final projection = dx * c + dy * s;
    return Offset(ruler.position.dx + projection * c, ruler.position.dy + projection * s);
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
    final snappedAngle = (angle / sliceAngle).round() * sliceAngle + ruler.rotation;
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
