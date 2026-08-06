import 'dart:typed_data';
import '../models/autofill_preset.dart';

enum AutofillMode { repaint, colorUpdate }

class AutofillEngine {
  /// 塗りなおし：形状を破棄して領域再判定→塗りなおす
  Uint8List repaint({
    required Uint8List lineartData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    final result = Uint8List(width * height * 4);
    _floodFillRegion(lineartData, result, width, height, part.color);
    return result;
  }

  /// 色更新：形状維持・不透明度ロックして最新色で塗りつぶす
  Uint8List colorUpdate({
    required Uint8List existingData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    final result = Uint8List.fromList(existingData);
    final fr = (part.color >> 16) & 0xFF;
    final fg = (part.color >> 8) & 0xFF;
    final fb = part.color & 0xFF;
    for (int i = 0; i < result.length; i += 4) {
      if (result[i + 3] > 0) {
        result[i]     = fr;
        result[i + 1] = fg;
        result[i + 2] = fb;
      }
    }
    return result;
  }

  /// 4パターン処理の統合エントリポイント
  Uint8List? execute({
    required AutofillMode mode,
    required Uint8List? lineartData,
    required Uint8List? existingData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    if (lineartData == null && existingData == null) return null;
    if (existingData == null) {
      return repaint(lineartData: lineartData!, width: width, height: height, part: part);
    }
    return switch (mode) {
      AutofillMode.repaint => lineartData != null
          ? repaint(lineartData: lineartData, width: width, height: height, part: part)
          : Uint8List(width * height * 4),
      AutofillMode.colorUpdate =>
          colorUpdate(existingData: existingData, width: width, height: height, part: part),
    };
  }

  void _floodFillRegion(
    Uint8List lineartData,
    Uint8List outputData,
    int width,
    int height,
    int fillColor,
  ) {
    final fr = (fillColor >> 16) & 0xFF;
    final fg = (fillColor >> 8) & 0xFF;
    final fb = fillColor & 0xFF;

    final visited = List<bool>.filled(width * height, false);

    bool isLineart(int x, int y) {
      final idx = (y * width + x) * 4;
      return lineartData[idx + 3] > 128;
    }

    void fill(int startX, int startY) {
      if (isLineart(startX, startY)) return;
      final queue = <(int, int)>[(startX, startY)];
      visited[startY * width + startX] = true;
      while (queue.isNotEmpty) {
        final (cx, cy) = queue.removeAt(0);
        final idx = (cy * width + cx) * 4;
        outputData[idx]     = fr;
        outputData[idx + 1] = fg;
        outputData[idx + 2] = fb;
        outputData[idx + 3] = 255;
        for (final (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]) {
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          final ni = ny * width + nx;
          if (visited[ni] || isLineart(nx, ny)) continue;
          visited[ni] = true;
          queue.add((nx, ny));
        }
      }
    }

    final outside = List<bool>.filled(width * height, false);
    final outerQueue = <(int, int)>[];
    for (int x = 0; x < width; x++) {
      if (!isLineart(x, 0)) { outside[x] = true; outerQueue.add((x, 0)); }
      if (!isLineart(x, height-1)) { outside[(height-1)*width+x] = true; outerQueue.add((x, height-1)); }
    }
    for (int y = 1; y < height - 1; y++) {
      if (!isLineart(0, y)) { outside[y*width] = true; outerQueue.add((0, y)); }
      if (!isLineart(width-1, y)) { outside[y*width+width-1] = true; outerQueue.add((width-1, y)); }
    }
    while (outerQueue.isNotEmpty) {
      final (cx, cy) = outerQueue.removeAt(0);
      for (final (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]) {
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        final ni = ny * width + nx;
        if (outside[ni] || isLineart(nx, ny)) continue;
        outside[ni] = true;
        outerQueue.add((nx, ny));
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = y * width + x;
        if (!outside[i] && !isLineart(x, y) && !visited[i]) {
          fill(x, y);
        }
      }
    }
  }

  bool isUpToDate({
    required int lineartHash,
    required int presetHash,
    required int lastUpdateHash,
  }) =>
      (lineartHash ^ presetHash) == lastUpdateHash;
}
