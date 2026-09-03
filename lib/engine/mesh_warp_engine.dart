import 'dart:typed_data';
import 'dart:ui' as ui;

/// レイヤー全体の自由変形・メッシュ変形（新機能）。
///
/// 変形前の画像を、rows×cols分割された(rows+1)×(cols+1)個の規則的な
/// 格子点（[regularGrid]）から、ユーザーがドラッグして動かした後の
/// 格子点（[controlPoints]）へワープする。各セル（4点で囲まれた升目）を
/// 対角線で2枚の三角形に分割し、Flutter標準の[ui.Vertices]（テクスチャ
/// 座標付き三角形メッシュ）でGPU描画する。rows=cols=1（4隅のみ）の場合は
/// 「自由変形」（4隅を個別にドラッグできる、通常のアフィン変換では表現
/// できない台形・平行四辺形状の変形も可能）そのものになり、rows・colsを
/// 増やすと「メッシュ変形」（升目を細かくした自由な歪み）になる
/// （両者は同じ仕組みの分割数違いに過ぎない）。
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
  }) {
    assert(controlPoints.length == (rows + 1) * (cols + 1));
    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();

    int idxAt(int r, int c) => r * (cols + 1) + c;
    ui.Offset srcPointAt(int r, int c) =>
        ui.Offset(srcW * c / cols, srcH * r / rows);

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

  /// [image]を、規則的な格子（[regularGrid]相当）から[controlPoints]へ
  /// ワープした結果を、[outputWidth]×[outputHeight]サイズの新しい画像として
  /// 返す（変形確定時にレイヤーのタイルへ書き戻す用）。
  static Future<ui.Image> warp({
    required ui.Image image,
    required int rows,
    required int cols,
    required List<ui.Offset> controlPoints,
    required int outputWidth,
    required int outputHeight,
  }) async {
    final vertices = buildVertices(
      image: image,
      rows: rows,
      cols: cols,
      controlPoints: controlPoints,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        identityMatrix4,
        filterQuality: ui.FilterQuality.low,
      );
    canvas.drawVertices(vertices, ui.BlendMode.srcOver, paint);
    final picture = recorder.endRecording();
    final result = await picture.toImage(outputWidth, outputHeight);
    picture.dispose();
    return result;
  }
}
