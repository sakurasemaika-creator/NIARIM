import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// スタンプ描画の確定処理（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由のバックグラウンドisolateで実行する想定のトップレベル関数）。
Uint8List runStampStrokeInIsolate(
  ({
    Uint8List canvasData,
    int width,
    int height,
    Uint8List texture,
    int texSize,
    List<ui.Offset> points,
    double stampSize,
    bool rotation,
    double scatter,
    double density,
    int opacity,
  })
  args,
) {
  return StampEngine().stampAlongPath(
    canvasData: args.canvasData,
    width: args.width,
    height: args.height,
    texture: args.texture,
    texSize: args.texSize,
    points: args.points,
    stampSize: args.stampSize,
    rotation: args.rotation,
    scatter: args.scatter,
    density: args.density,
    opacity: args.opacity,
  );
}

/// スタンプ描画エンジン（色情報はスタンプ画像自体が保持・
/// ブラシサイズに連動・回転／密度／散布に対応）。
class StampEngine {
  /// [texture]（texSize x texSize、RGBA）をストローク[points]に沿って合成する。
  ///
  /// [density]は「基準密度に対するスタンプ数の倍率」として扱う。
  /// UIの設定範囲0.1〜5.0と一致させ、1.0を基準、2.0なら約2倍の間隔密度、
  /// 0.5なら約半分の密度になる。以前は1.0未満だけ確率的に間引き、1.0〜5.0
  /// がすべて同じ結果になっていたため、幾何学的な再サンプリングへ変更した。
  ///
  /// 入力イベント数によって見た目が変わらないよう、OSから届いた各点へ直接
  /// スタンプするのではなく、パス長に沿った一定距離で再サンプリングする。
  Uint8List stampAlongPath({
    required Uint8List canvasData,
    required int width,
    required int height,
    required Uint8List texture,
    required int texSize,
    required List<ui.Offset> points,
    required double stampSize,
    bool rotation = false,
    double scatter = 0,
    double density = 1.0,
    int opacity = 100,
    int seed = 0,
  }) {
    final result = Uint8List.fromList(canvasData);
    if (points.isEmpty || stampSize <= 0) return result;

    final safeDensity = density.clamp(0.1, 5.0).toDouble();
    final spacing = math.max(1.0, stampSize * 0.6 / safeDensity);
    final sampled = _resamplePath(points, spacing);
    final rand = math.Random(seed);

    for (int i = 0; i < sampled.length; i++) {
      final p = sampled[i];
      // テクスチャを回転しない場合でも、散布方向はストローク進行方向に対して
      // 垂直であるべきなので、パス角は常に計算する。
      final pathAngle = _pathAngle(sampled, i);
      final stampAngle = rotation ? pathAngle : 0.0;

      double ox = p.dx;
      double oy = p.dy;
      if (scatter > 0) {
        final normal = pathAngle + math.pi / 2;
        final off = (rand.nextDouble() * 2 - 1) * scatter;
        ox += math.cos(normal) * off;
        oy += math.sin(normal) * off;
      }
      _blitStamp(
        result,
        width,
        height,
        texture,
        texSize,
        ox,
        oy,
        stampSize,
        stampAngle,
        opacity,
      );
    }
    return result;
  }

  /// 入力イベントの分割数に依存しないよう、折れ線全体の累積距離に沿って
  /// [spacing]間隔で点を置き直す。各セグメントの先頭で間隔をリセットしない。
  ///
  /// 同一直線を2点で受け取った場合と多数のmoveイベントで受け取った場合で、
  /// 浮動小数点の丸め誤差だけを理由にスタンプのラスタ境界が1px変わらないよう、
  /// 再サンプリング後の座標を1e-6px精度へ正規化する。
  List<ui.Offset> _resamplePath(List<ui.Offset> points, double spacing) {
    if (points.length <= 1) {
      return points.map(_stableOffset).toList(growable: false);
    }
    final result = <ui.Offset>[_stableOffset(points.first)];
    var distanceSinceStamp = 0.0;

    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final segmentLength = math.sqrt(dx * dx + dy * dy);
      if (segmentLength <= 1e-9) continue;

      var consumed = 0.0;
      while (distanceSinceStamp + (segmentLength - consumed) >=
          spacing - 1e-9) {
        final needed = math.max(0.0, spacing - distanceSinceStamp);
        consumed += needed;
        final t = (consumed / segmentLength).clamp(0.0, 1.0);
        result.add(_stableOffset(ui.Offset(a.dx + dx * t, a.dy + dy * t)));
        distanceSinceStamp = 0.0;
      }
      distanceSinceStamp += segmentLength - consumed;
      if (distanceSinceStamp.abs() < 1e-9) distanceSinceStamp = 0.0;
    }
    return result;
  }

  ui.Offset _stableOffset(ui.Offset p) => ui.Offset(
    (p.dx * 1000000).round() / 1000000,
    (p.dy * 1000000).round() / 1000000,
  );

  /// 端点も含めてすべてのスタンプがストローク方向へ追従するよう、先頭では
  /// 次点、末尾では前点、中間では前後点を使って接線方向を求める。
  double _pathAngle(List<ui.Offset> points, int index) {
    if (points.length < 2) return 0.0;
    late final ui.Offset from;
    late final ui.Offset to;
    if (index <= 0) {
      from = points[0];
      to = points[1];
    } else if (index >= points.length - 1) {
      from = points[index - 1];
      to = points[index];
    } else {
      from = points[index - 1];
      to = points[index + 1];
    }
    return math.atan2(to.dy - from.dy, to.dx - from.dx);
  }

  void _blitStamp(
    Uint8List dst,
    int w,
    int h,
    Uint8List tex,
    int texSize,
    double cx,
    double cy,
    double size,
    double angle,
    int opacity,
  ) {
    if (size <= 0) return;
    final half = size / 2;
    final minX = (cx - half).floor().clamp(0, w - 1);
    final maxX = (cx + half).ceil().clamp(0, w - 1);
    final minY = (cy - half).floor().clamp(0, h - 1);
    final maxY = (cy + half).ceil().clamp(0, h - 1);
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dx = x - cx;
        final dy = y - cy;
        final rx = dx * cosA - dy * sinA;
        final ry = dx * sinA + dy * cosA;
        final u = ((rx / size) + 0.5) * texSize;
        final v = ((ry / size) + 0.5) * texSize;
        if (u < 0 || u >= texSize || v < 0 || v >= texSize) continue;
        final tIdx = (v.floor() * texSize + u.floor()) * 4;
        final ta = (tex[tIdx + 3] * opacity.clamp(1, 100) / 100.0)
            .round()
            .clamp(0, 255);
        if (ta == 0) continue;
        final dIdx = (y * w + x) * 4;
        final srcA = ta / 255.0;
        final dstA = dst[dIdx + 3] / 255.0;
        final outA = srcA + dstA * (1 - srcA);
        if (outA <= 0) continue;
        dst[dIdx] = ((tex[tIdx] * srcA + dst[dIdx] * dstA * (1 - srcA)) / outA)
            .round()
            .clamp(0, 255);
        dst[dIdx + 1] =
            ((tex[tIdx + 1] * srcA + dst[dIdx + 1] * dstA * (1 - srcA)) / outA)
                .round()
                .clamp(0, 255);
        dst[dIdx + 2] =
            ((tex[tIdx + 2] * srcA + dst[dIdx + 2] * dstA * (1 - srcA)) / outA)
                .round()
                .clamp(0, 255);
        dst[dIdx + 3] = (outA * 255).round().clamp(0, 255);
      }
    }
  }
}
