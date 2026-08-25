import 'dart:math' as math;
import 'dart:typed_data';
import '../models/autofill_gradient.dart';
import '../models/autofill_preset.dart';

enum AutofillMode { repaint, colorUpdate }

/// 自動塗りの本処理（AutofillEngine.execute）をcompute()経由のバックグラウンド
/// isolateで実行するためのトップレベル関数。キャンバス全体を走査する
/// フラッドフィルは自動塗りの中で最も重い処理でありながら、従来はメイン
/// スレッド（UIスレッド）で同期実行していたため、実行中は画面が固まって
/// 見える不具合があった。lasso_fill_engine.dart等、他の重い処理と同じ設計。
Uint8List? runAutofillExecuteInIsolate(
    ({
      AutofillMode mode,
      Uint8List? lineartData,
      Uint8List? existingData,
      int width,
      int height,
      AutofillPart part,
      Uint8List? toneTexture,
      int toneWidth,
      int toneHeight,
    }) args) {
  return AutofillEngine().execute(
    mode: args.mode,
    lineartData: args.lineartData,
    existingData: args.existingData,
    width: args.width,
    height: args.height,
    part: args.part,
    toneTexture: args.toneTexture,
    toneWidth: args.toneWidth,
    toneHeight: args.toneHeight,
  );
}

/// AutofillEngine.recolorLineartをcompute()経由で実行するためのトップレベル
/// 関数（線画色設定の反映もキャンバス全体を走査するため、同様にisolate化する）。
Uint8List runRecolorLineartInIsolate(
    ({
      Uint8List lineartData,
      int width,
      int height,
      AutofillPart part,
    }) args) {
  return AutofillEngine().recolorLineart(
    lineartData: args.lineartData,
    width: args.width,
    height: args.height,
    part: args.part,
  );
}

/// AutofillEngine.colorUpdateをcompute()経由で実行するためのトップレベル関数。
Uint8List runAutofillColorUpdateInIsolate(
    ({
      Uint8List existingData,
      int width,
      int height,
      AutofillPart part,
      Uint8List? toneTexture,
      int toneWidth,
      int toneHeight,
    }) args) {
  return AutofillEngine().colorUpdate(
    existingData: args.existingData,
    width: args.width,
    height: args.height,
    part: args.part,
    toneTexture: args.toneTexture,
    toneWidth: args.toneWidth,
    toneHeight: args.toneHeight,
  );
}

class AutofillEngine {
  /// 塗りなおし：形状を破棄して領域再判定→塗りなおす
  /// [toneTexture]が指定され[part].useTone==trueの場合は、単色/グラデーションの
  /// 代わりにトーンパターンで塗る（バケツトーンエンジンと
  /// 同じループ配置方式）。
  Uint8List repaint({
    required Uint8List lineartData,
    required int width,
    required int height,
    required AutofillPart part,
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    final result = Uint8List(width * height * 4);
    final regionMask = _floodFillRegion(lineartData, result, width, height, part,
        toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight);
    if (part.outlineEnabled) {
      // 縁取りは塗り範囲そのもの（regionMask、線画で囲まれた領域全体）の
      // 外周のみを対象にする。トーンONの場合resultのアルファはトーン柄で
      // 穴だらけになるため、resultの透明部分をそのまま縁取り対象にすると
      // トーンの穴1つ1つにも縁取りが付いてしまう。regionMask（トーンの
      // 影響を受けない、線画で区切られた領域そのもの）を使うことで、
      // 塗り範囲の本当の外周（線画に接する部分）だけに縁取りを描く。
      _addOutlineRing(result, regionMask, width, height,
          color: part.outlineColor, widthPx: part.outlineWidth);
    }
    return result;
  }

  /// 色更新：形状維持・不透明度ロックして最新色で塗りつぶす
  Uint8List colorUpdate({
    required Uint8List existingData,
    required int width,
    required int height,
    required AutofillPart part,
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    final result = Uint8List.fromList(existingData);
    final gradient = part.gradient;
    final useTone = part.useTone && toneTexture != null;
    // 縁取りが有効な場合、既存の不透明範囲（塗り本体＋縁取りリング）の
    // うち「既存データの時点で境界（線画側の外周）に近いピクセル」を
    // 縁取り色として塗り直す。形状（不透明範囲）自体は色更新の定義どおり
    // 一切広げない（縁取りが太くなる変更は「塗りなおし」でのみ反映される）。
    // repaint()側（_addOutlineRing）と異なり、色更新は塗り直し前の
    // Uint8List（トーンの穴あき込みの見た目）しか持たないため、トーンと
    // 縁取りを併用しているパーツでは、トーンの穴の縁にも縁取り色が
    // わずかににじむ近似計算になる（正確な結果が欲しい場合は
    // 「塗りなおし」を使う。repaint()は線画で区切られた領域そのもの
    // ＝トーンの影響を受けないregionMaskを使うため常に正確）。
    final outlineRadius = part.outlineEnabled ? part.outlineWidth.round().clamp(1, 100) : 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (result[i + 3] == 0) continue;
        if (useTone) {
          final tx = x % toneWidth;
          final ty = y % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          if (toneTexture[toneIdx + 3] == 0) {
            result[i + 3] = 0;
            continue;
          }
        }
        final isOutlinePixel = outlineRadius > 0 &&
            _isNearEdge(existingData, width, height, x, y, outlineRadius);
        final argb = isOutlinePixel
            ? part.outlineColor
            : gradient != null
                ? _gradientColorAt(gradient, x, y, width, height)
                : part.color;
        result[i]     = (argb >> 16) & 0xFF;
        result[i + 1] = (argb >> 8) & 0xFF;
        result[i + 2] = argb & 0xFF;
      }
    }
    return result;
  }

  /// [regionMask]（線画で区切られた塗り範囲そのもの。トーンの穴あきの
  /// 影響を受けない）の外周から[widthPx]px以内の、塗り範囲の外側の
  /// ピクセルへ[color]を描画し、指定色・指定太さの縁取りリングを重ねる
  /// （[data]の元々の不透明ピクセルは変更しない）。[regionMask]を使う
  /// ことで、トーン柄の穴1つ1つに縁取りが付いてしまうのを防いでいる。
  void _addOutlineRing(Uint8List data, List<bool> regionMask, int width, int height, {
    required int color,
    required double widthPx,
  }) {
    final radius = widthPx.round().clamp(1, 100);
    final ca = (color >> 24) & 0xFF;
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    final r2 = radius * radius;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = y * width + x;
        if (regionMask[i]) continue; // 塗り範囲そのものは保持（トーンの穴を含む）
        bool hit = false;
        for (int dy = -radius; dy <= radius && !hit; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          final dxMax2 = r2 - dy * dy;
          if (dxMax2 < 0) continue;
          final dxMax = math.sqrt(dxMax2).floor();
          final rowBase = ny * width;
          for (int dx = -dxMax; dx <= dxMax; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            if (regionMask[rowBase + nx]) {
              hit = true;
              break;
            }
          }
        }
        if (hit) {
          final idx = i * 4;
          data[idx] = cr;
          data[idx + 1] = cg;
          data[idx + 2] = cb;
          data[idx + 3] = ca;
        }
      }
    }
  }

  /// (x, y)の不透明ピクセルが、[radius]px以内に透明ピクセル（または画面外）を
  /// 持つか＝塗り範囲の外周付近（縁取りリングとして塗るべき範囲）かどうかを
  /// 判定する（[_addOutlineRing]の外側への拡張＝膨張と対になる、内側からの
  /// 侵食判定）。
  bool _isNearEdge(Uint8List data, int width, int height, int x, int y, int radius) {
    final r2 = radius * radius;
    for (int dy = -radius; dy <= radius; dy++) {
      final ny = y + dy;
      if (ny < 0 || ny >= height) return true;
      final dxMax2 = r2 - dy * dy;
      if (dxMax2 < 0) continue;
      final dxMax = math.sqrt(dxMax2).floor();
      final rowBase = ny * width;
      for (int dx = -dxMax; dx <= dxMax; dx++) {
        final nx = x + dx;
        if (nx < 0 || nx >= width) return true;
        if (data[(rowBase + nx) * 4 + 3] == 0) return true;
      }
    }
    return false;
  }

  /// 4パターン処理の統合エントリポイント
  Uint8List? execute({
    required AutofillMode mode,
    required Uint8List? lineartData,
    required Uint8List? existingData,
    required int width,
    required int height,
    required AutofillPart part,
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    if (lineartData == null && existingData == null) return null;
    if (existingData == null) {
      return repaint(
          lineartData: lineartData!, width: width, height: height, part: part,
          toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight);
    }
    return switch (mode) {
      AutofillMode.repaint => lineartData != null
          ? repaint(lineartData: lineartData, width: width, height: height, part: part,
              toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight)
          : Uint8List(width * height * 4),
      AutofillMode.colorUpdate => colorUpdate(
          existingData: existingData, width: width, height: height, part: part,
          toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight),
    };
  }

  /// 線画色設定を適用した線画レイヤーのRGBAバッファを返す。
  /// アルファ値（線の形状）はそのまま維持し、不透明ピクセルのRGBのみ差し替える。
  /// 不透明度は「塗り色の不透明度は100%固定」と同じ理由でレイヤー不透明度側
  /// （AutofillPart.lineOpacityをLayer.opacityへ反映）で管理するため、ここでは
  /// アルファを変更しない。
  Uint8List recolorLineart({
    required Uint8List lineartData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    if (part.lineColorMode == AutofillLineColorMode.specified && part.lineColor == 0xFF000000) {
      // デフォルト設定（変更なし）の場合はそのまま返す
      return lineartData;
    }
    final result = Uint8List.fromList(lineartData);
    final gradient = part.gradient;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        if (result[idx + 3] == 0) continue;
        final int argb;
        switch (part.lineColorMode) {
          case AutofillLineColorMode.specified:
            argb = part.lineColor;
          case AutofillLineColorMode.sameAsFill:
            argb = gradient != null ? _gradientColorAt(gradient, x, y, width, height) : part.color;
          case AutofillLineColorMode.traceAdjust:
            final baseArgb =
                gradient != null ? _gradientColorAt(gradient, x, y, width, height) : part.color;
            argb = _traceAdjustColor(baseArgb, part.traceHue, part.traceSaturation, part.traceLightness);
        }
        result[idx]     = (argb >> 16) & 0xFF;
        result[idx + 1] = (argb >> 8) & 0xFF;
        result[idx + 2] = argb & 0xFF;
      }
    }
    return result;
  }

  /// 線画で区切られた塗り範囲（トーンの穴あきの影響を受けない、領域全体の
  /// 形状マスク）を返す。縁取りリングの外周判定（[_addOutlineRing]）に使う。
  List<bool> _floodFillRegion(
    Uint8List lineartData,
    Uint8List outputData,
    int width,
    int height,
    AutofillPart part, {
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    final gradient = part.gradient;
    final fr = (part.color >> 16) & 0xFF;
    final fg = (part.color >> 8) & 0xFF;
    final fb = part.color & 0xFF;
    final useTone = part.useTone && toneTexture != null;

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
        bool paint = true;
        if (useTone) {
          final tx = cx % toneWidth;
          final ty = cy % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          paint = toneTexture[toneIdx + 3] > 0;
        }
        if (paint) {
          if (gradient != null) {
            // グラデーションは色ごとに不透明度を持てるため、そのままアルファも
            // 書き込む（塗り色の不透明度は100%固定だが、グラデーション
            // の各色は個別に不透明度を設定できる）。
            final argb = _gradientColorAt(gradient, cx, cy, width, height);
            outputData[idx]     = (argb >> 16) & 0xFF;
            outputData[idx + 1] = (argb >> 8) & 0xFF;
            outputData[idx + 2] = argb & 0xFF;
            outputData[idx + 3] = (argb >> 24) & 0xFF;
          } else {
            outputData[idx]     = fr;
            outputData[idx + 1] = fg;
            outputData[idx + 2] = fb;
            outputData[idx + 3] = 255;
          }
        }
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
    return visited;
  }

  bool isUpToDate({
    required int lineartHash,
    required int presetHash,
    required int lastUpdateHash,
  }) =>
      (lineartHash ^ presetHash) == lastUpdateHash;

  // ─── グラデーション（塗り色設定・グラデーション） ─────────────

  /// キャンバス座標(x, y)におけるグラデーション色をARGB intで返す。
  int _gradientColorAt(AutofillGradient g, int x, int y, int width, int height) {
    double t;
    switch (g.type) {
      case AutofillGradientType.linear:
        final rad = g.angle * math.pi / 180;
        final dx = math.cos(rad);
        final dy = math.sin(rad);
        // 中心を原点としたピクセル単位の実座標を方向ベクトルへ投影する。
        // 以前はx・yをそれぞれ幅・高さで個別に0〜1正規化してから射影して
        // いたが、この方式だと正方形でない塗り範囲では指定した角度と
        // 実際に画面上で見える傾きがズレてしまう（例：横長の範囲では
        // 45度がほぼ水平寄りに見える）。塗り範囲の縦横比が変わるたびに
        // 同じ角度でも見た目の傾きが変わって見える不具合の原因だった。
        // ピクセル単位のまま（幅・高さを個別に正規化せず）射影することで、
        // 縦横比によらず指定した角度どおりの向きになるようにする。
        final px = x - width / 2.0;
        final py = y - height / 2.0;
        final proj = px * dx + py * dy;
        final halfDiagonal = math.sqrt(width * width + height * height) / 2.0;
        t = halfDiagonal > 0 ? (proj + halfDiagonal) / (halfDiagonal * 2) : 0.5;
      case AutofillGradientType.radialCenterOut:
      case AutofillGradientType.radialOutCenter:
        final cx = g.centerX * width;
        final cy = g.centerY * height;
        final maxRadius = math.sqrt(width * width + height * height) / 2;
        final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        t = maxRadius > 0 ? dist / maxRadius : 0;
        if (g.type == AutofillGradientType.radialOutCenter) t = 1 - t;
    }
    return _sampleGradient(g.colors, g.stops, t.clamp(0.0, 1.0), g.feather);
  }

  /// [feather]（0.0〜1.0）：1.0なら隣接する2色の境界（stops[i]〜stops[i+1]）
  /// の全区間を使い、隣の色の端（stops[i+1]）まで完全に混ざり切る滑らかな
  /// ブレンドにする。値を下げるほど境界の中央付近だけで急に切り替わる帯状
  /// 表示に近づき、0では中間色を持たない完全な帯（ハードエッジ）になる。
  int _sampleGradient(List<int> colors, List<double> stops, double t, [double feather = 1.0]) {
    if (colors.isEmpty) return 0xFF000000;
    if (colors.length == 1) return colors.first;
    if (t <= stops.first) return colors.first;
    if (t >= stops.last) return colors.last;
    for (int i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i] && t <= stops[i + 1]) {
        final s0 = stops[i], s1 = stops[i + 1];
        final clampedFeather = feather.clamp(0.0, 1.0);
        // 100%（最大）は素直に区間全体を使った線形補間そのものにする
        // （帯計算の丸め等による誤差の余地をなくし、確実に端まで混ざり切る
        // ようにするため）。
        if (clampedFeather >= 0.999) {
          final range = s1 - s0;
          final localT = range > 0 ? (t - s0) / range : 0.0;
          return _lerpColor(colors[i], colors[i + 1], localT);
        }
        final mid = (s0 + s1) / 2;
        final halfBand = (s1 - s0) / 2 * clampedFeather;
        if (halfBand <= 1e-6) {
          return t < mid ? colors[i] : colors[i + 1];
        }
        final localT = ((t - mid) / (2 * halfBand) + 0.5).clamp(0.0, 1.0);
        return _lerpColor(colors[i], colors[i + 1], localT);
      }
    }
    return colors.last;
  }

  /// RGBだけでなくアルファ（色ごとの不透明度）も補間する。
  int _lerpColor(int a, int b, double t) {
    final aa = (a >> 24) & 0xFF, ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
    final ba = (b >> 24) & 0xFF, br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
    final alpha = (aa + (ba - aa) * t).round().clamp(0, 255);
    final r = (ar + (br - ar) * t).round().clamp(0, 255);
    final g = (ag + (bg - ag) * t).round().clamp(0, 255);
    final bl = (ab + (bb - ab) * t).round().clamp(0, 255);
    return (alpha << 24) | (r << 16) | (g << 8) | bl;
  }

  // ─── 色トレス・線画馴染ませ（線画色設定） ─────────────────────
  // 塗り色のHSLへ色相・彩度・明度のオフセットを適用し、線画を塗り色に
  // 馴染ませた色へ変換する（色相・彩度・明度いずれも塗り色からのオフセット
  // として加算する）。

  int _traceAdjustColor(int argb, double hueOffset, double saturationOffset, double lightnessOffset) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    final (h, s, l) = _rgbToHsl(r, g, b);
    final newH = (h + hueOffset) % 360;
    final newS = (s + saturationOffset / 100.0).clamp(0.0, 1.0);
    final newL = (l + lightnessOffset / 100.0).clamp(0.0, 1.0);
    final (nr, ng, nb) = _hslToRgb(newH < 0 ? newH + 360 : newH, newS, newL);
    return 0xFF000000 |
        ((nr * 255).round().clamp(0, 255) << 16) |
        ((ng * 255).round().clamp(0, 255) << 8) |
        (nb * 255).round().clamp(0, 255);
  }

  (double, double, double) _rgbToHsl(double r, double g, double b) {
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final l = (maxV + minV) / 2;
    if (maxV == minV) return (0, 0, l);
    final d = maxV - minV;
    final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
    double h;
    if (maxV == r) {
      h = ((g - b) / d) % 6;
    } else if (maxV == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
    if (h < 0) h += 360;
    return (h, s, l);
  }

  (double, double, double) _hslToRgb(double h, double s, double l) {
    if (s == 0) return (l, l, l);
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final hk = h / 360;
    double hue2rgb(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }
    return (hue2rgb(hk + 1 / 3), hue2rgb(hk), hue2rgb(hk - 1 / 3));
  }
}
