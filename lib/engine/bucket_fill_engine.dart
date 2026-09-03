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
    // バケツ塗り詳細設定（設定画面「バケツ塗り」で調整）。
    // 拡張px：フラッドフィルで検出した領域の境界を、外側へ指定px分だけ
    // 広げて塗り残し（線画とのわずかな隙間）をカバーする。0なら従来通り。
    int expandPx = 0,
    // 線の下まで潜る：拡張分を線画の上から直接上書きするのではなく、
    // 既存ピクセルの下（背後）へ塗り色を合成する。線画が完全不透明な
    // 部分は見た目が変わらず、アンチエイリアスの半透明部分だけ塗り色が
    // 透けて隙間を埋める。falseなら拡張分もベタで上書きする。
    bool fillUnderLine = false,
  }) {
    if (startX < 0 || startX >= width || startY < 0 || startY >= height)
      return canvasData;
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

    if (targetR == fillR &&
        targetG == fillG &&
        targetB == fillB &&
        targetA == fillA)
      return result;

    // Set<int>はハッシュ計算・ボクシングのオーバーヘッドが大きいため、
    // 訪問済み管理にはUint8Listのビットマップを使う（低スペック端末対策：
    // バケツ塗りは連続ドラッグ中に逐次呼ばれるため速度が重要）。
    final visited = Uint8List(width * height);
    // 拡張処理の起点となる「本来の塗り領域」マスク（許容誤差内で一致した
    // ピクセルのみ。トーンの透明部分の有無に関わらずベタ塗りは常にここが基準）。
    final matched = Uint8List(width * height);
    final startPos = startY * width + startX;
    visited[startPos] = 1;
    final stack = <int>[startPos];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final x = pos % width;
      final y = pos ~/ width;

      if (selectionMask != null && selectionMask[pos] == 0) continue;

      final idx = pos * 4;
      if (!_colorMatch(
        result[idx],
        result[idx + 1],
        result[idx + 2],
        result[idx + 3],
        targetR,
        targetG,
        targetB,
        targetA,
        tolerance,
      )) {
        continue;
      }

      result[idx] = fillR;
      result[idx + 1] = fillG;
      result[idx + 2] = fillB;
      result[idx + 3] = fillA;
      matched[pos] = 1;

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

    if (expandPx > 0) {
      _expandFill(
        result: result,
        matched: matched,
        width: width,
        height: height,
        fillR: fillR,
        fillG: fillG,
        fillB: fillB,
        fillA: fillA,
        expandPx: expandPx,
        underLine: fillUnderLine,
        selectionMask: selectionMask,
      );
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
    int expandPx = 0,
    bool fillUnderLine = false,
  }) {
    if (startX < 0 || startX >= width || startY < 0 || startY >= height)
      return canvasData;
    final result = Uint8List.fromList(canvasData);
    final startIdx = (startY * width + startX) * 4;
    final targetR = result[startIdx];
    final targetG = result[startIdx + 1];
    final targetB = result[startIdx + 2];
    final targetA = result[startIdx + 3];

    // Set<int>はハッシュ計算・ボクシングのオーバーヘッドが大きいため、
    // 訪問済み管理にはUint8Listのビットマップを使う（低スペック端末対策）。
    final visited = Uint8List(width * height);
    final matched = Uint8List(width * height);
    final startPos = startY * width + startX;
    visited[startPos] = 1;
    final stack = <int>[startPos];

    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final x = pos % width;
      final y = pos ~/ width;

      if (selectionMask != null && selectionMask[pos] == 0) continue;

      final idx = pos * 4;
      if (!_colorMatch(
        result[idx],
        result[idx + 1],
        result[idx + 2],
        result[idx + 3],
        targetR,
        targetG,
        targetB,
        targetA,
        tolerance,
      )) {
        continue;
      }
      matched[pos] = 1;

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

    if (expandPx > 0) {
      // トーン塗りの拡張分は境界に最も近いトーン色（塗り開始色）をそのまま
      // ベタで広げる（拡張部分だけトーン柄が途切れると不自然なため）。
      final toneColorR = (toneColor.r * 255).round();
      final toneColorG = (toneColor.g * 255).round();
      final toneColorB = (toneColor.b * 255).round();
      final toneColorA = (toneColor.a * 255).round();
      _expandFill(
        result: result,
        matched: matched,
        width: width,
        height: height,
        fillR: toneColorR,
        fillG: toneColorG,
        fillB: toneColorB,
        fillA: toneColorA,
        expandPx: expandPx,
        underLine: fillUnderLine,
        selectionMask: selectionMask,
      );
    }
    return result;
  }

  /// [matched]（本来の塗り領域）の境界から外側へ[expandPx]分だけ塗り色を
  /// 広げる（多段階の4近傍膨張）。[underLine]がtrueの場合は既存ピクセルを
  /// 上に残したまま背後へ合成し（src-over: 既存 over 塗り色）、falseの
  /// 場合はベタで上書きする。
  void _expandFill({
    required Uint8List result,
    required Uint8List matched,
    required int width,
    required int height,
    required int fillR,
    required int fillG,
    required int fillB,
    required int fillA,
    required int expandPx,
    required bool underLine,
    Uint8List? selectionMask,
  }) {
    final settled = Uint8List.fromList(matched);
    var frontier = <int>[];
    for (int i = 0; i < matched.length; i++) {
      if (matched[i] != 0) frontier.add(i);
    }
    for (int step = 0; step < expandPx && frontier.isNotEmpty; step++) {
      final next = <int>[];
      for (final pos in frontier) {
        final x = pos % width;
        final y = pos ~/ width;

        void tryExpand(int newPos) {
          if (settled[newPos] != 0) return;
          if (selectionMask != null && selectionMask[newPos] == 0) return;
          settled[newPos] = 1;
          final idx = newPos * 4;
          if (underLine) {
            final srcA = result[idx + 3] / 255.0;
            final invA = 1.0 - srcA;
            result[idx] = (result[idx] * srcA + fillR * invA).round().clamp(
              0,
              255,
            );
            result[idx + 1] = (result[idx + 1] * srcA + fillG * invA)
                .round()
                .clamp(0, 255);
            result[idx + 2] = (result[idx + 2] * srcA + fillB * invA)
                .round()
                .clamp(0, 255);
            result[idx + 3] = (result[idx + 3] + fillA * invA).round().clamp(
              0,
              255,
            );
          } else {
            result[idx] = fillR;
            result[idx + 1] = fillG;
            result[idx + 2] = fillB;
            result[idx + 3] = fillA;
          }
          next.add(newPos);
        }

        if (x > 0) tryExpand(pos - 1);
        if (x < width - 1) tryExpand(pos + 1);
        if (y > 0) tryExpand(pos - width);
        if (y < height - 1) tryExpand(pos + width);
      }
      frontier = next;
    }
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
    if (startX < 0 || startX >= width || startY < 0 || startY >= height)
      return mask;
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
      if (!_colorMatch(
        canvasData[idx],
        canvasData[idx + 1],
        canvasData[idx + 2],
        canvasData[idx + 3],
        targetR,
        targetG,
        targetB,
        targetA,
        tolerance,
      )) {
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

  bool _colorMatch(
    int r,
    int g,
    int b,
    int a,
    int tr,
    int tg,
    int tb,
    int ta,
    double tolerance,
  ) {
    return (r - tr).abs() <= tolerance &&
        (g - tg).abs() <= tolerance &&
        (b - tb).abs() <= tolerance &&
        (a - ta).abs() <= tolerance;
  }
}
