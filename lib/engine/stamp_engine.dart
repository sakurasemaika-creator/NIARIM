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
    bool smooth,
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
    premultiplied: true,
    smooth: args.smooth,
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
  /// Pass [premultiplied] for canvas tiles and decoded preset textures.
  ///
  /// [smooth] samples the texture with filtering: when the stamp is drawn
  /// smaller than the texture, the texture is first averaged down to the
  /// drawn size (each output texel is the area average of the texels it
  /// covers, so thin spikes fade instead of breaking into dashes), then each
  /// canvas pixel centre reads the texture bilinearly and the square edge of
  /// the stamp is antialiased. Without it every canvas pixel copies the
  /// nearest texel, which keeps pixel-art stamps crisp.
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
    bool premultiplied = false,
    bool smooth = true,
  }) {
    final result = Uint8List.fromList(canvasData);
    if (points.isEmpty || stampSize <= 0) return result;
    final source = smooth
        ? _FilteredStamp.prepare(texture, texSize, stampSize, premultiplied)
        : null;

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
      if (source != null) {
        source.blit(
          result,
          width,
          height,
          ox,
          oy,
          stampSize,
          stampAngle,
          opacity,
          premultiplied,
        );
      } else {
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
          premultiplied,
        );
      }
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
    bool premultiplied,
  ) {
    if (size <= 0) return;
    final half = size / 2;
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);
    final extent = half * (cosA.abs() + sinA.abs());
    final minX = (cx - extent).floor().clamp(0, w - 1);
    final maxX = (cx + extent).ceil().clamp(0, w - 1);
    final minY = (cy - extent).floor().clamp(0, h - 1);
    final maxY = (cy + extent).ceil().clamp(0, h - 1);
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
        if (premultiplied) {
          final srcOpacity = ta / tex[tIdx + 3];
          for (var channel = 0; channel < 3; channel++) {
            dst[dIdx + channel] =
                (tex[tIdx + channel] * srcOpacity +
                        dst[dIdx + channel] * (1 - srcA))
                    .round()
                    .clamp(0, 255);
          }
        } else {
          for (var channel = 0; channel < 3; channel++) {
            dst[dIdx + channel] =
                ((tex[tIdx + channel] * srcA +
                            dst[dIdx + channel] * dstA * (1 - srcA)) /
                        outA)
                    .round()
                    .clamp(0, 255);
          }
        }
        dst[dIdx + 3] = (outA * 255).round().clamp(0, 255);
      }
    }
  }
}

/// A stamp texture made ready for filtered sampling: premultiplied colour as
/// floats, averaged down to about the drawn size when the stamp is smaller
/// than the texture.
class _FilteredStamp {
  _FilteredStamp._(this.texels, this.size)
    : _inkLeft = _inkEdge(texels, size, horizontal: true, first: true),
      _inkRight = _inkEdge(texels, size, horizontal: true, first: false),
      _inkTop = _inkEdge(texels, size, horizontal: false, first: true),
      _inkBottom = _inkEdge(texels, size, horizontal: false, first: false);

  /// Premultiplied RGBA, 0–255 per channel, [size]×[size].
  final Float32List texels;
  final int size;

  /// The texel box that has any ink, one texel larger on each side (the
  /// bilinear reach). Canvas pixels that read outside it are skipped.
  final double _inkLeft, _inkRight, _inkTop, _inkBottom;

  static double _inkEdge(
    Float32List texels,
    int size, {
    required bool horizontal,
    required bool first,
  }) {
    for (var k = 0; k < size; k++) {
      final line = first ? k : size - 1 - k;
      for (var j = 0; j < size; j++) {
        final x = horizontal ? line : j;
        final y = horizontal ? j : line;
        if (texels[(y * size + x) * 4 + 3] > 0) {
          return first ? line - 1.0 : line + 1.0;
        }
      }
    }
    // No ink: an empty box.
    return first ? size.toDouble() : -1.0;
  }

  static _FilteredStamp prepare(
    Uint8List texture,
    int texSize,
    double stampSize,
    bool premultiplied,
  ) {
    final count = texSize * texSize;
    var texels = Float32List(count * 4);
    for (var p = 0, i = 0; p < count; p++, i += 4) {
      final a = texture[i + 3];
      final f = premultiplied ? 1.0 : a / 255;
      texels[i] = texture[i] * f;
      texels[i + 1] = texture[i + 1] * f;
      texels[i + 2] = texture[i + 2] * f;
      texels[i + 3] = a.toDouble();
    }
    var size = texSize;
    // Bilinear sampling alone skips texels when the stamp is drawn smaller
    // than the texture: thin parts alias into dashes and small stamps
    // shimmer from one dab to the next.
    final target = stampSize.ceil().clamp(1, texSize);
    if (target < texSize) {
      texels = _areaAverage(texels, texSize, target);
      size = target;
    }
    return _FilteredStamp._(texels, size);
  }

  /// Box-filters [src] ([n]×[n]) down to [m]×[m], weighting each source
  /// texel by how much of it falls inside the output texel.
  static Float32List _areaAverage(Float32List src, int n, int m) {
    final scale = n / m;
    final starts = Int32List(m);
    final ends = Int32List(m);
    final weights = <Float64List>[];
    for (var o = 0; o < m; o++) {
      final a = o * scale, b = (o + 1) * scale;
      final first = a.floor();
      final last = math.min(n, b.ceil());
      starts[o] = first;
      ends[o] = last;
      final w = Float64List(last - first);
      for (var j = first; j < last; j++) {
        w[j - first] =
            (math.min(b, j + 1.0) - math.max(a, j.toDouble())) / scale;
      }
      weights.add(w);
    }
    // Rows first (n rows of m texels), then columns.
    final rows = Float64List(n * m * 4);
    for (var y = 0; y < n; y++) {
      final srcRow = y * n * 4;
      final dstRow = y * m * 4;
      for (var o = 0; o < m; o++) {
        final w = weights[o];
        var r = 0.0, g = 0.0, bl = 0.0, al = 0.0;
        for (var j = starts[o]; j < ends[o]; j++) {
          final k = w[j - starts[o]];
          final i = srcRow + j * 4;
          r += src[i] * k;
          g += src[i + 1] * k;
          bl += src[i + 2] * k;
          al += src[i + 3] * k;
        }
        final d = dstRow + o * 4;
        rows[d] = r;
        rows[d + 1] = g;
        rows[d + 2] = bl;
        rows[d + 3] = al;
      }
    }
    final out = Float32List(m * m * 4);
    for (var x = 0; x < m; x++) {
      for (var o = 0; o < m; o++) {
        final w = weights[o];
        var r = 0.0, g = 0.0, bl = 0.0, al = 0.0;
        for (var j = starts[o]; j < ends[o]; j++) {
          final k = w[j - starts[o]];
          final i = (j * m + x) * 4;
          r += rows[i] * k;
          g += rows[i + 1] * k;
          bl += rows[i + 2] * k;
          al += rows[i + 3] * k;
        }
        final d = (o * m + x) * 4;
        out[d] = r;
        out[d + 1] = g;
        out[d + 2] = bl;
        out[d + 3] = al;
      }
    }
    return out;
  }

  /// Composites one dab centred at ([cx], [cy]) onto [dst] (source-over).
  void blit(
    Uint8List dst,
    int w,
    int h,
    double cx,
    double cy,
    double drawn,
    double angle,
    int opacity,
    bool premultipliedDst,
  ) {
    if (drawn <= 0) return;
    final half = drawn / 2;
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);
    // One more pixel than the square reaches: its antialiased edge.
    final extent = half * (cosA.abs() + sinA.abs()) + 1;
    final minX = (cx - extent).floor().clamp(0, w - 1);
    final maxX = (cx + extent).ceil().clamp(0, w - 1);
    final minY = (cy - extent).floor().clamp(0, h - 1);
    final maxY = (cy + extent).ceil().clamp(0, h - 1);
    final texelsPerPixel = size / drawn;
    final strength = opacity.clamp(1, 100) / 100;
    final last = size - 1;
    final t = texels;
    final row = size * 4;
    for (var y = minY; y <= maxY; y++) {
      final dy = y + 0.5 - cy;
      for (var x = minX; x <= maxX; x++) {
        final dx = x + 0.5 - cx;
        final rx = dx * cosA - dy * sinA;
        final ry = dx * sinA + dy * cosA;
        // Pixel-area coverage of the square the stamp is drawn in.
        var coverX = half + 0.5 - rx.abs();
        if (coverX <= 0) continue;
        var coverY = half + 0.5 - ry.abs();
        if (coverY <= 0) continue;
        if (coverX > 1) coverX = 1;
        if (coverY > 1) coverY = 1;
        var u = (rx + half) * texelsPerPixel - 0.5;
        if (u <= _inkLeft || u >= _inkRight) continue;
        var v = (ry + half) * texelsPerPixel - 0.5;
        if (v <= _inkTop || v >= _inkBottom) continue;
        if (u < 0) u = 0;
        if (v < 0) v = 0;
        if (u > last) u = last.toDouble();
        if (v > last) v = last.toDouble();
        final x0 = u.floor();
        final y0 = v.floor();
        final fx = u - x0;
        final fy = v - y0;
        final x1 = x0 < last ? x0 + 1 : x0;
        final y1 = y0 < last ? y0 + 1 : y0;
        final i00 = y0 * row + x0 * 4;
        final i10 = y0 * row + x1 * 4;
        final i01 = y1 * row + x0 * 4;
        final i11 = y1 * row + x1 * 4;
        final w00 = (1 - fx) * (1 - fy);
        final w10 = fx * (1 - fy);
        final w01 = (1 - fx) * fy;
        final w11 = fx * fy;
        final alpha =
            t[i00 + 3] * w00 +
            t[i10 + 3] * w10 +
            t[i01 + 3] * w01 +
            t[i11 + 3] * w11;
        if (alpha <= 0) continue;
        final k = strength * coverX * coverY;
        final srcA = alpha * k / 255;
        if (srcA <= 0) continue;
        final d = (y * w + x) * 4;
        final keep = 1 - srcA;
        if (premultipliedDst) {
          for (var c = 0; c < 3; c++) {
            final s =
                (t[i00 + c] * w00 +
                    t[i10 + c] * w10 +
                    t[i01 + c] * w01 +
                    t[i11 + c] * w11) *
                k;
            dst[d + c] = _byte(s + dst[d + c] * keep);
          }
          dst[d + 3] = _byte(srcA * 255 + dst[d + 3] * keep);
        } else {
          final dstA = dst[d + 3] / 255;
          final outA = srcA + dstA * keep;
          for (var c = 0; c < 3; c++) {
            final s =
                (t[i00 + c] * w00 +
                    t[i10 + c] * w10 +
                    t[i01 + c] * w01 +
                    t[i11 + c] * w11) *
                k;
            dst[d + c] = _byte((s + dst[d + c] * dstA * keep) / outA);
          }
          dst[d + 3] = _byte(outA * 255);
        }
      }
    }
  }

  static int _byte(double v) {
    final r = v.round();
    return r < 0 ? 0 : (r > 255 ? 255 : r);
  }
}
