import 'dart:typed_data';
import 'dart:ui' as ui;

/// 投げ縄塗りの確定処理（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由のバックグラウンドisolateで実行する想定のトップレベル関数）。
Uint8List runLassoFillInIsolate(
  ({
    bool enclosed,
    List<ui.Offset> points,
    ui.Color color,
    Uint8List canvasData,
    int width,
    int height,
    Uint8List? toneTexture,
    int toneTextureWidth,
    int toneTextureHeight,
    Uint8List? selectionMask,
  })
  args,
) {
  final engine = LassoFillEngine();
  return args.enclosed
      ? engine.fillEnclosed(
          points: args.points,
          color: args.color,
          canvasData: args.canvasData,
          width: args.width,
          height: args.height,
          toneTexture: args.toneTexture,
          toneTextureWidth: args.toneTextureWidth,
          toneTextureHeight: args.toneTextureHeight,
          selectionMask: args.selectionMask,
        )
      : engine.fillLasso(
          points: args.points,
          color: args.color,
          canvasData: args.canvasData,
          width: args.width,
          height: args.height,
          toneTexture: args.toneTexture,
          toneTextureWidth: args.toneTextureWidth,
          toneTextureHeight: args.toneTextureHeight,
          selectionMask: args.selectionMask,
        );
}

/// 投げ縄塗りエンジン
/// 仕様：25_投げ縄塗り仕様.md
class LassoFillEngine {
  /// 通常投げ縄塗り：軌跡そのものをベタ/トーンで描画
  Uint8List fillLasso({
    required List<ui.Offset> points,
    required ui.Color color,
    required Uint8List canvasData,
    required int width,
    required int height,
    Uint8List? selectionMask,
    Uint8List? toneTexture,
    int toneTextureWidth = 64,
    int toneTextureHeight = 64,
  }) {
    if (points.length < 3) return canvasData;
    final result = Uint8List.fromList(canvasData);
    final isEraser = color.a == 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // 投げ縄座標は連続座標なので、各画素の左上端ではなく中心点で
        // 内外判定する。これにより斜辺の外側へ1pxだけはみ出すケースを防ぐ。
        if (!_isInsidePolygon(x + 0.5, y + 0.5, points)) continue;
        if (selectionMask != null && selectionMask[y * width + x] == 0) {
          continue;
        }

        final idx = (y * width + x) * 4;
        if (isEraser) {
          result[idx] = 0;
          result[idx + 1] = 0;
          result[idx + 2] = 0;
          result[idx + 3] = 0;
        } else if (toneTexture != null) {
          final tx = x % toneTextureWidth;
          final ty = y % toneTextureHeight;
          final toneIdx = (ty * toneTextureWidth + tx) * 4;
          if (toneTexture[toneIdx + 3] > 0) {
            result[idx] = (color.r * 255).round();
            result[idx + 1] = (color.g * 255).round();
            result[idx + 2] = (color.b * 255).round();
            result[idx + 3] = (color.a * 255).round();
          }
        } else {
          result[idx] = (color.r * 255).round();
          result[idx + 1] = (color.g * 255).round();
          result[idx + 2] = (color.b * 255).round();
          result[idx + 3] = (color.a * 255).round();
        }
      }
    }
    return result;
  }

  /// fillEnclosed の囲って塗るモード：囲った範囲内にある閉領域（線で閉じた
  /// 透明な領域）をバケツ塗りと同じ考え方ですべて一括で塗る。閉領域は投げ縄の
  /// 内側に半分以上入っているもので、その領域全体を塗る。投げ縄と絵の間の
  /// 余白のようにキャンバスの端まで続く領域は、9割以上を囲んだときだけ塗る
  /// （投げ縄をキャンバスいっぱいに描いても余白は塗らない）。
  /// 透明色選択時は消しゴム動作（仕様25番共通仕様）
  Uint8List fillEnclosed({
    required List<ui.Offset> points,
    required ui.Color color,
    required Uint8List canvasData,
    required int width,
    required int height,
    Uint8List? selectionMask,
    Uint8List? toneTexture,
    int toneTextureWidth = 64,
    int toneTextureHeight = 64,
  }) {
    if (points.length < 3) return canvasData;
    final result = Uint8List.fromList(canvasData);
    final n = width * height;
    final inside = Uint8List(n);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_isInsidePolygon(x + 0.5, y + 0.5, points)) {
          inside[y * width + x] = 1;
        }
      }
    }
    // Set<int>はハッシュ計算・ボクシングのオーバーヘッドが大きいため、
    // 訪問済み管理にはUint8Listのビットマップを使う（低スペック端末対策）。
    final visited = Uint8List(n);
    final queue = Int32List(n);
    final isEraser = color.a == 0;
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final a = (color.a * 255).round();

    for (var seed = 0; seed < n; seed++) {
      if (visited[seed] != 0 || inside[seed] == 0) continue;
      if (canvasData[seed * 4 + 3] != 0) continue; // 不透明ピクセルは境界
      // 透明な領域を投げ縄に関係なく最後までたどり、投げ縄の内側に
      // 半分以上あれば閉領域として塗る。
      var head = 0, tail = 0, within = 0;
      var open = false;
      visited[seed] = 1;
      queue[tail++] = seed;
      while (head < tail) {
        final pos = queue[head++];
        if (inside[pos] != 0) within++;
        final x = pos % width;
        if (x == 0 || x == width - 1 || pos < width || pos >= n - width) {
          open = true;
        }
        void visit(int q) {
          if (visited[q] == 0 && canvasData[q * 4 + 3] == 0) {
            visited[q] = 1;
            queue[tail++] = q;
          }
        }

        if (x > 0) visit(pos - 1);
        if (x < width - 1) visit(pos + 1);
        if (pos >= width) visit(pos - width);
        if (pos < n - width) visit(pos + width);
      }
      // 投げ縄の外の余白（キャンバスの端まで続く領域）は、ほぼ全部を
      // 囲んだときだけ閉領域とみなす。
      if (open ? within * 10 < tail * 9 : within * 2 < tail) continue;
      for (var k = 0; k < tail; k++) {
        final pos = queue[k];
        if (selectionMask != null && selectionMask[pos] == 0) continue;
        final i = pos * 4;
        if (isEraser) {
          result[i] = 0;
          result[i + 1] = 0;
          result[i + 2] = 0;
          result[i + 3] = 0;
        } else if (toneTexture != null) {
          final tx = (pos % width) % toneTextureWidth;
          final ty = (pos ~/ width) % toneTextureHeight;
          final toneIdx = (ty * toneTextureWidth + tx) * 4;
          if (toneTexture[toneIdx + 3] > 0) {
            result[i] = r;
            result[i + 1] = g;
            result[i + 2] = b;
            result[i + 3] = a;
          }
        } else {
          result[i] = r;
          result[i + 1] = g;
          result[i + 2] = b;
          result[i + 3] = a;
        }
      }
    }
    return result;
  }

  /// 点が多角形の内側かどうかを判定（Ray casting法）
  bool _isInsidePolygon(double px, double py, List<ui.Offset> polygon) {
    int crossings = 0;
    final n = polygon.length;
    for (int i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      if ((a.dy <= py && b.dy > py) || (b.dy <= py && a.dy > py)) {
        final t = (py - a.dy) / (b.dy - a.dy);
        if (px < a.dx + t * (b.dx - a.dx)) crossings++;
      }
    }
    return crossings % 2 != 0;
  }
}
