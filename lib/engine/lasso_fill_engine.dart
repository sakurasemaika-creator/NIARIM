import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

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
        if (selectionMask != null && selectionMask[y * width + x] == 0)
          continue;

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

  /// fillEnclosed の囲って塗るモード：囲った範囲内の閉領域をバケツ塗りエンジンで一括塗り
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
    // Set<int>はハッシュ計算・ボクシングのオーバーヘッドが大きいため、
    // 訪問済み管理にはUint8Listのビットマップを使う（低スペック端末対策）。
    final visited = Uint8List(width * height);
    final isEraser = color.a == 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pos = y * width + x;
        if (visited[pos] != 0) continue;
        if (!_isInsidePolygon(x + 0.5, y + 0.5, points)) continue;
        if (selectionMask != null && selectionMask[pos] == 0) continue;

        final idx = pos * 4;
        if (result[idx + 3] != 0) continue; // 不透明ピクセルは境界

        // 未訪問の透明ピクセル → フラッドフィルで閉領域を塗る。
        // flood自体も投げ縄内へ制限し、囲みの外側へ接続している透明領域が
        // 選択範囲外まで広がらないようにする。
        final region = _floodFill(
          result,
          width,
          height,
          x,
          y,
          polygon: points,
          selectionMask: selectionMask,
        );
        for (final pt in region) {
          final rPos = pt.dy.round() * width + pt.dx.round();
          visited[rPos] = 1;
          final rIdx = rPos * 4;
          if (isEraser) {
            result[rIdx] = 0;
            result[rIdx + 1] = 0;
            result[rIdx + 2] = 0;
            result[rIdx + 3] = 0;
          } else if (toneTexture != null) {
            final tx = pt.dx.round() % toneTextureWidth;
            final ty = pt.dy.round() % toneTextureHeight;
            final toneIdx = (ty * toneTextureWidth + tx) * 4;
            if (toneTexture[toneIdx + 3] > 0) {
              result[rIdx] = (color.r * 255).round();
              result[rIdx + 1] = (color.g * 255).round();
              result[rIdx + 2] = (color.b * 255).round();
              result[rIdx + 3] = (color.a * 255).round();
            }
          } else {
            result[rIdx] = (color.r * 255).round();
            result[rIdx + 1] = (color.g * 255).round();
            result[rIdx + 2] = (color.b * 255).round();
            result[rIdx + 3] = (color.a * 255).round();
          }
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

  /// スタックベースのフラッドフィル（透明領域を対象）
  /// visitedチェックをstack.add()前に行い重複push防止。
  /// [polygon]指定時は画素中心が投げ縄内のピクセルだけを探索する。
  List<ui.Offset> _floodFill(
    Uint8List data,
    int width,
    int height,
    int startX,
    int startY, {
    List<ui.Offset>? polygon,
    Uint8List? selectionMask,
  }) {
    final result = <ui.Offset>[];
    if (startX < 0 || startX >= width || startY < 0 || startY >= height)
      return result;
    if (polygon != null &&
        !_isInsidePolygon(startX + 0.5, startY + 0.5, polygon)) {
      return result;
    }
    final startIdx = (startY * width + startX) * 4;
    if (data[startIdx + 3] != 0) return result;

    final visited = Uint8List(width * height);
    final startPos = startY * width + startX;
    visited[startPos] = 1;
    final stack = <int>[startPos];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final x = pos % width;
      final y = pos ~/ width;

      if (selectionMask != null && selectionMask[pos] == 0) continue;
      if (polygon != null && !_isInsidePolygon(x + 0.5, y + 0.5, polygon))
        continue;

      final idx = pos * 4;
      if (data[idx + 3] != 0) continue; // 不透明ピクセルは境界

      result.add(ui.Offset(x.toDouble(), y.toDouble()));

      void tryAdd(int newPos) {
        if (visited[newPos] == 0) {
          visited[newPos] = 1;
          stack.add(newPos);
        }
      }

      if (x > 0) tryAdd(pos - 1);
      if (x < width - 1) tryAdd(pos + 1);
      if (y > 0) tryAdd(pos - width);
      if (y < height - 1) tryAdd(pos + width);
    }
    return result;
  }

  /// 投げ縄の境界ボックスを取得
  ui.Rect getBoundingBox(List<ui.Offset> points) {
    if (points.isEmpty) return ui.Rect.zero;
    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
