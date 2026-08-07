import 'dart:typed_data';
import 'dart:ui' as ui;

/// バケツ塗りエンジン
/// 仕様：03_描画エンジン.md / 17_ブラシ仕様.md
class BucketFillEngine {
  /// ベタ塗り：指定座標からフラッドフィル
  Uint8List fill({
    required Uint8List canvasData,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required ui.Color fillColor,
    Uint8List? selectionMask,
    double tolerance = 30.0,
  }) {
    if (startX < 0 || startX >= width || startY < 0 || startY >= height) return canvasData;
    final result = Uint8List.fromList(canvasData);
    final startIdx = (startY * width + startX) * 4;
    final targetR = result[startIdx];
    final targetG = result[startIdx + 1];
    final targetB = result[startIdx + 2];
    final targetA = result[startIdx + 3];

    final fillR = (fillColor.r * 255).round();
    final fillG = (fillColor.g * 255).round();
    final fillB = (fillColor.b * 255).round();
    final fillA = (fillColor.a * 255).round();

    if (targetR == fillR && targetG == fillG && targetB == fillB && targetA == fillA) return result;

    // Set<int>はハッシュ計算・ボクシングのオーバーヘッドが大きいため、
    // 訪問済み管理にはUint8Listのビットマップを使う（低スペック端末対策：
    // バケツ塗りは連続ドラッグ中に逐次呼ばれるため速度が重要）。
    final visited = Uint8List(width * height);
    final startPos = startY * width + startX;
    visited[startPos] = 1;
    final stack = <int>[startPos];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final x = pos % width;
      final y = pos ~/ width;

      if (selectionMask != null && selectionMask[pos] == 0) continue;

      final idx = pos * 4;
      if (!_colorMatch(result[idx], result[idx + 1], result[idx + 2], result[idx + 3],
          targetR, targetG, targetB, targetA, tolerance)) {
        continue;
      }

      result[idx] = fillR;
      result[idx + 1] = fillG;
      result[idx + 2] = fillB;
      result[idx + 3] = fillA;

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

  /// トーン塗り：フラッドフィルした領域にトーンテクスチャをループ配置
  /// 修正：トーン透明部分のピクセルもvisitedに追加して無限ループを防止
  Uint8List fillWithTone({
    required Uint8List canvasData,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required ui.Color toneColor,
    required Uint8List toneTexture,
    required int toneWidth,
    required int toneHeight,
    Uint8List? selectionMask,
    double tolerance = 30.0,
  }) {
    if (startX < 0 || startX >= width || startY < 0 || startY >= height) return canvasData;
    final result = Uint8List.fromList(canvasData);
    final startIdx = (startY * width + startX) * 4;
    final targetR = result[startIdx];
    final targetG = result[startIdx + 1];
    final targetB = result[startIdx + 2];
    final targetA = result[startIdx + 3];

    // Set<int>はハッシュ計算・ボクシングのオーバーヘッドが大きいため、
    // 訪問済み管理にはUint8Listのビットマップを使う（低スペック端末対策）。
    final visited = Uint8List(width * height);
    final startPos = startY * width + startX;
    visited[startPos] = 1;
    final stack = <int>[startPos];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final x = pos % width;
      final y = pos ~/ width;

      if (selectionMask != null && selectionMask[pos] == 0) continue;

      final idx = pos * 4;
      if (!_colorMatch(result[idx], result[idx + 1], result[idx + 2], result[idx + 3],
          targetR, targetG, targetB, targetA, tolerance)) {
        continue;
      }

      // トーンテクスチャをループ配置（透明部分はスキップするが必ずvisited済みにする）
      final tx = x % toneWidth;
      final ty = y % toneHeight;
      final toneIdx = (ty * toneWidth + tx) * 4;
      if (toneTexture[toneIdx + 3] > 0) {
        result[idx] = (toneColor.r * 255).round();
        result[idx + 1] = (toneColor.g * 255).round();
        result[idx + 2] = (toneColor.b * 255).round();
        result[idx + 3] = (toneColor.a * 255).round();
      }
      // 透明部分でも隣接ピクセルへ伝播（塗らないが領域は走査する）

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

  /// 自動選択（マジックワンド）：指定座標からフラッドフィルし、色を変更せず
  /// 選択マスク（1byte/px、1=選択・0=非選択）のみを返す。
  Uint8List selectionMask({
    required Uint8List canvasData,
    required int width,
    required int height,
    required int startX,
    required int startY,
    double tolerance = 30.0,
  }) {
    final mask = Uint8List(width * height);
    if (startX < 0 || startX >= width || startY < 0 || startY >= height) return mask;
    final startIdx = (startY * width + startX) * 4;
    final targetR = canvasData[startIdx];
    final targetG = canvasData[startIdx + 1];
    final targetB = canvasData[startIdx + 2];
    final targetA = canvasData[startIdx + 3];

    final visited = Uint8List(width * height);
    final startPos = startY * width + startX;
    visited[startPos] = 1;
    final stack = <int>[startPos];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final x = pos % width;
      final y = pos ~/ width;

      final idx = pos * 4;
      if (!_colorMatch(canvasData[idx], canvasData[idx + 1], canvasData[idx + 2], canvasData[idx + 3],
          targetR, targetG, targetB, targetA, tolerance)) {
        continue;
      }

      mask[pos] = 1;

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
    return mask;
  }

  bool _colorMatch(int r, int g, int b, int a, int tr, int tg, int tb, int ta, double tolerance) {
    return (r - tr).abs() <= tolerance &&
        (g - tg).abs() <= tolerance &&
        (b - tb).abs() <= tolerance &&
        (a - ta).abs() <= tolerance;
  }
}
