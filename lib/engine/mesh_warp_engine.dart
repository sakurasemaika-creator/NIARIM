import 'dart:typed_data';
import 'dart:ui' as ui;

/// Warps a source rectangle by a projective four-corner transform or a
/// tessellated multi-cell mesh. The canvas preview and raster use the same path.
class MeshWarpEngine {
  /// [rows]×[cols]分割の規則的な格子点を、[bounds]の範囲へ均等割りで
  /// 生成する（変形ツールを開いた直後の初期状態、および分割数変更時に使う）。
  /// 戻り値は(rows+1)*(cols+1)点、行優先（row-major：まず1行分のcol+1点、
  /// 次の行…の順）。
  static List<ui.Offset> regularGrid(int rows, int cols, ui.Rect bounds) {
    final points = <ui.Offset>[];
    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c <= cols; c++) {
        points.add(
          ui.Offset(
            bounds.left + bounds.width * c / cols,
            bounds.top + bounds.height * r / rows,
          ),
        );
      }
    }
    return points;
  }

  /// [controlPoints]（行優先、(rows+1)*(cols+1)点）を、[image]のピクセル
  /// 座標をテクスチャ座標とした三角形メッシュの[ui.Vertices]へ変換する。
  /// ライブプレビュー描画（[ui.Canvas.drawVertices]）・最終確定時の
  /// ラスタライズの両方で共通利用する。
  static ui.Vertices buildVertices({
    required ui.Image image,
    required int rows,
    required int cols,
    required List<ui.Offset> controlPoints,
    ui.Rect? sourceBounds,
  }) {
    assert(controlPoints.length == (rows + 1) * (cols + 1));
    final bounds = sourceBounds ?? _imageBounds(image);

    int idxAt(int r, int c) => r * (cols + 1) + c;
    ui.Offset srcPointAt(int r, int c) => ui.Offset(
      bounds.left + bounds.width * c / cols,
      bounds.top + bounds.height * r / rows,
    );

    final positions = Float32List((rows + 1) * (cols + 1) * 2);
    final texCoords = Float32List((rows + 1) * (cols + 1) * 2);
    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c <= cols; c++) {
        final i = idxAt(r, c);
        final p = controlPoints[i];
        positions[i * 2] = p.dx;
        positions[i * 2 + 1] = p.dy;
        final s = srcPointAt(r, c);
        texCoords[i * 2] = s.dx;
        texCoords[i * 2 + 1] = s.dy;
      }
    }

    final indices = Uint16List(rows * cols * 6);
    int k = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final i0 = idxAt(r, c);
        final i1 = idxAt(r, c + 1);
        final i2 = idxAt(r + 1, c);
        final i3 = idxAt(r + 1, c + 1);
        // 升目を対角線(i0-i3)で2枚の三角形に分割する。
        indices[k++] = i0;
        indices[k++] = i1;
        indices[k++] = i3;
        indices[k++] = i0;
        indices[k++] = i3;
        indices[k++] = i2;
      }
    }

    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: indices,
    );
  }

  /// 単位行列（[ui.ImageShader]のmatrix4引数に渡す、テクスチャ座標を
  /// そのまま画像ピクセル座標として使うための恒等変換）。
  static final Float64List identityMatrix4 = Float64List.fromList(const [
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  static ui.Rect _imageBounds(ui.Image image) =>
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

  /// Maps the unit square onto a convex quad. Falling back to triangles
  /// keeps intentionally folded or degenerate four-point edits usable.
  static Float64List? _projection(List<ui.Offset> points) {
    final [tl, tr, bl, br] = points;
    final a = tr - br;
    final b = bl - br;
    final difference = tl + br - tr - bl;
    final det = a.dx * b.dy - a.dy * b.dx;
    if (det.abs() < 1e-9) return null;
    final g = (difference.dx * b.dy - difference.dy * b.dx) / det;
    final h = (a.dx * difference.dy - a.dy * difference.dx) / det;
    if (1 + g <= 1e-9 || 1 + h <= 1e-9 || 1 + g + h <= 1e-9) return null;
    return Float64List.fromList([
      tr.dx * (1 + g) - tl.dx,
      tr.dy * (1 + g) - tl.dy,
      0,
      g,
      bl.dx * (1 + h) - tl.dx,
      bl.dy * (1 + h) - tl.dy,
      0,
      h,
      0,
      0,
      1,
      0,
      tl.dx,
      tl.dy,
      0,
      1,
    ]);
  }

  static void draw(
    ui.Canvas canvas, {
    required ui.Image image,
    required int rows,
    required int cols,
    required List<ui.Offset> controlPoints,
    ui.Rect? sourceBounds,
  }) {
    final bounds = sourceBounds ?? _imageBounds(image);
    if (bounds.isEmpty) return;
    final projection = rows == 1 && cols == 1
        ? _projection(controlPoints)
        : null;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
    if (projection != null) {
      canvas.save();
      canvas.transform(projection);
      canvas.drawImageRect(
        image,
        bounds,
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        paint,
      );
      canvas.restore();
      return;
    }
    final vertices = buildVertices(
      image: image,
      rows: rows,
      cols: cols,
      controlPoints: controlPoints,
      sourceBounds: bounds,
    );
    paint.shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      identityMatrix4,
      filterQuality: ui.FilterQuality.low,
    );
    canvas.drawVertices(vertices, ui.BlendMode.srcOver, paint);
  }

  static Future<ui.Image> warp({
    required ui.Image image,
    required int rows,
    required int cols,
    required List<ui.Offset> controlPoints,
    required int outputWidth,
    required int outputHeight,
    ui.Rect? sourceBounds,
    ui.Image? base,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (base != null) canvas.drawImage(base, ui.Offset.zero, ui.Paint());
    draw(
      canvas,
      image: image,
      rows: rows,
      cols: cols,
      controlPoints: controlPoints,
      sourceBounds: sourceBounds,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(outputWidth, outputHeight);
    } finally {
      picture.dispose();
    }
  }
}
