import 'dart:math' as math;
import 'dart:typed_data';

import '../models/pixel_color_mode.dart';
import 'pixel_art_lines.dart';

/// Shared NIARIM pixel-art conversion contract.
///
/// With [squareBlocks] (filters, stamps) every cell of the grid becomes one
/// pixel-art pixel: it is either left fully transparent or filled whole with
/// a single colour and a single alpha, so blocks keep their square shape
/// instead of being cut along the source's anti-aliased edge, and no
/// semi-transparent fringe is left around the shape. Alpha is never
/// averaged. Without it (the brush's pixel mode, which already rasterises
/// one canvas pixel at a time) only the colours change and the source alpha
/// is kept exactly.
///
/// [pixelSize] is the size of a dot in canvas pixels and may be fractional,
/// so a picture can be split into an exact number of dots (100 dots across
/// 1920 pixels makes dots 19 or 20 pixels wide).
///
/// Pixels are premultiplied RGBA, as layers store them: colours are judged
/// unpremultiplied and written back premultiplied by the new alpha.
///
/// Horizontal/vertical internal boundaries stay hard. Diagonal opaque-color
/// boundaries may use a middle color only when the active color policy allows
/// it; callers can use the same converter for filters, brushes, and stamps.
///
/// With [dither] and a limited set of colours, a dot whose colour no single
/// colour of the set comes close to is made of up to three of them that,
/// side by side, look nearest to it, in a fixed 4 x 4 pattern (ordered
/// dithering, which stays put from one animation frame to the next). A dot
/// a colour of the set already matches well stays that one colour.
///
/// 細い線（変換後に2.5ドット未満の太さ）は、[squareBlocks]で2画素以上の
/// ドットのとき[PixelArtLines]が中心線から描き直す（[redrawLines]が偽なら
/// 描き直さない）：線ごとに1つの色・1つの太さで、L字の角の無い
/// （ピクセルパーフェクトな）線にする。描き直した線のインクはほかのドットの
/// 色から外す。細い線の無い絵では何も変わらない。
class PixelArtEngine {
  const PixelArtEngine({this.halfResolutionLines = false});

  /// 4〜7画素のドットでも、細い線を縦横半分に縮めた絵で探す（速いが、線の
  /// 位置が元の細かさで探すときと少し変わることがある）。既定は切。
  final bool halfResolutionLines;

  Uint8List convert(
    Uint8List data,
    int width,
    int height, {
    num pixelSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
    bool squareBlocks = true,
    bool dither = false,
    bool redrawLines = true,
  }) {
    final size = pixelSize.toDouble().clamp(
      1.0,
      math.max(1, math.max(width, height)).toDouble(),
    );
    final result = Uint8List.fromList(data);
    final xs = cellEdges(width, size);
    final ys = cellEdges(height, size);
    final cellsX = xs.length - 1;
    final cellsY = ys.length - 1;
    final cellCount = cellsX * cellsY;
    // 細い線を描き直す（ブラシのピクセルモードのように色だけ変えるときと、
    // 1画素のドットでは描き直さない）。
    final lines = squareBlocks && redrawLines
        ? PixelArtLines.find(
            data,
            width,
            height,
            xs,
            ys,
            size,
            halfResolution: halfResolutionLines,
          )
        : null;
    final inked = lines?.inked;
    final rawColors = List<int?>.filled(cellCount, null);
    final alphaSum = Int32List(cellCount);
    final alphaMax = Uint8List(cellCount);
    final pixels = Int32List(cellCount);
    // How the paint inside each cell is laid out: 1 = along x (a flat
    // stroke), 2 = along y (an upright one), 0 = neither (a dot, a diagonal).
    final orientation = Uint8List(cellCount);
    final even = Uint8List(cellCount);
    // 線のインクも含めた、ドットの画素の不透明度の合計（線を描き直すとき）。
    final whole = inked == null ? null : Int32List(cellCount);

    final edgeX = Int32List.fromList(xs), edgeY = Int32List.fromList(ys);
    final words = _pixelWords(data, width * height);
    for (var cy = 0; cy < cellsY; cy++) {
      final y0 = edgeY[cy], h = edgeY[cy + 1] - y0;
      for (var cx = 0; cx < cellsX; cx++) {
        final x0 = edgeX[cx], w = edgeX[cx + 1] - x0;
        var wr = 0, wg = 0, wb = 0, aw = 0, top = 0, n = 0, all = 0;
        var sx = 0, sy = 0, sxx = 0, syy = 0, squares = 0;
        for (var dy = 0; dy < h; dy++) {
          final row = (y0 + dy) * width + x0;
          for (var dx = 0; dx < w; dx++) {
            final p = row + dx;
            final v = words[p];
            final a = v >> 24;
            // 描き直す線のインクは、そのドットの地の色に数えない。
            if (inked != null && inked[p] != 0) {
              all += a;
              continue;
            }
            n++;
            if (a == 0) continue;
            // Premultiplied channels are the colour already weighted by alpha.
            final d0 = v & 0xff, d1 = (v >> 8) & 0xff, d2 = (v >> 16) & 0xff;
            wr += d0;
            wg += d1;
            wb += d2;
            aw += a;
            squares += d0 * d0 + d1 * d1 + d2 * d2 + a * a;
            if (a > top) top = a;
            sx += dx * a;
            sy += dy * a;
            sxx += dx * dx * a;
            syy += dy * dy * a;
          }
        }
        final c = cy * cellsX + cx;
        pixels[c] = n;
        alphaSum[c] = aw;
        if (whole != null) whole[c] = all + aw;
        alphaMax[c] = top;
        if (aw == 0) continue;
        final mx = sx / aw, my = sy / aw;
        final varX = sxx / aw - mx * mx, varY = syy / aw - my * my;
        if (varX > 1.5 * varY + 0.01) {
          orientation[c] = 1;
        } else if (varY > 1.5 * varX + 0.01) {
          orientation[c] = 2;
        }
        rawColors[c] = _rgb(
          (wr * 255 / aw).round().clamp(0, 255),
          (wg * 255 / aw).round().clamp(0, 255),
          (wb * 255 / aw).round().clamp(0, 255),
        );
        // ほとんど1色のドット（乗算済みの値と不透明度のばらつきが小さい）：
        // その平均の色が、ドットにある色。
        final m0 = wr / n, m1 = wg / n, m2 = wb / n, m3 = aw / n;
        final spread = squares / n - (m0 * m0 + m1 * m1 + m2 * m2 + m3 * m3);
        if (spread <= _evenSpread) even[c] = 1;
      }
    }

    Uint8List? blockAlpha;
    // 色を決め直さないドット：描き直した線と、地の色を隣から借りたもの。
    Uint8List? settled, borrowedRing;
    if (squareBlocks) {
      if (lines != null) {
        // 線のドットの周りは、線の不透明度を基準に地を決める（線のインクを
        // 外した後の薄い縁だけで決めると、ほとんど透明なドットが残る）。
        for (var c = 0; c < cellCount; c++) {
          if (lines.line[c] != 0) alphaMax[c] = lines.alpha[c];
        }
      }
      final kept = _blockAlphas(
        cellsX,
        cellsY,
        alphaSum,
        alphaMax,
        pixels,
        orientation,
        lineCells: lines?.line,
      );
      if (lines != null) {
        settled = Uint8List(cellCount);
        borrowedRing = Uint8List(cellCount);
        _placeLines(
          lines,
          xs,
          ys,
          pixels,
          kept,
          rawColors,
          settled,
          borrowedRing,
        );
      }
      if (lines != null) {
        _fillBesideLines(
          cellsX,
          cellsY,
          edgeX,
          edgeY,
          lines.line,
          whole!,
          kept,
          rawColors,
          settled!,
        );
      }
      blockAlpha = _bridgeGaps(data, width, size, xs, ys, alphaMax, kept);
    }
    if (blockAlpha != null) {
      for (var c = 0; c < cellCount; c++) {
        if (blockAlpha[c] == 0) rawColors[c] = null;
      }
    }
    _keepDetails(
      data,
      width,
      xs,
      ys,
      cellsX,
      cellsY,
      rawColors,
      inked: inked,
      settled: settled,
      even: even,
    );
    if (lines != null && borrowedRing != null && blockAlpha != null) {
      _settleBorrowed(
        lines,
        cellsX,
        cellsY,
        pixels,
        blockAlpha,
        rawColors,
        borrowedRing,
      );
    }
    final lineCell = lines?.line;
    if (lines != null && blockAlpha != null) {
      _closeHolesBesideLines(cellsX, cellsY, lines.line, rawColors, blockAlpha);
    }

    final countPalette = colorMode == PixelColorMode.count
        ? _buildCountPalette(rawColors.whereType<int>().toList(), colorLevels)
        : const <int>[];
    final limited = switch (colorMode) {
      PixelColorMode.count => countPalette,
      PixelColorMode.explicit || PixelColorMode.palette => paletteColors,
      PixelColorMode.none => const <int>[],
    };
    // Dots whose colour is a mix of two (dithered): left out of the diagonal
    // smoothing below, whose pattern a dither is full of.
    final mixed = Uint8List(cellCount);
    final List<int?> colors;
    if (dither && limited.length >= 2) {
      final ditherer = _Ditherer(limited);
      colors = List<int?>.filled(cellCount, null);
      final labs = Float64List(cellCount * 3);
      for (var c = 0; c < cellCount; c++) {
        final color = rawColors[c];
        if (color == null) continue;
        _Ditherer.labInto(color, labs, c * 3);
      }
      final edge = Uint8List(cellCount);
      for (var c = 0; c < cellCount; c++) {
        if (rawColors[c] != null &&
            ((lineCell != null && lineCell[c] != 0) ||
                _onEdge(rawColors, labs, cellsX, cellsY, c))) {
          edge[c] = 1;
        }
      }
      for (var c = 0; c < cellCount; c++) {
        var color = rawColors[c];
        if (color == null) continue;
        // 描き直した線は、その色に最も近い1色（混ぜない）。
        if (lineCell != null && lineCell[c] != 0) {
          colors[c] = ditherer.nearest(color);
          continue;
        }
        // A dot on a hard edge between two colours (often a blend of both)
        // takes the colour of its most alike neighbour off the edge, so the
        // pattern runs right up to the edge and no dots of some third colour
        // are scattered along it. A thin line, with no such neighbour, is
        // one colour.
        if (edge[c] != 0) {
          final like = _mostAlikeInside(
            rawColors,
            labs,
            edge,
            cellsX,
            cellsY,
            c,
          );
          if (like == null) {
            colors[c] = ditherer.nearest(color);
            continue;
          }
          color = like;
        }
        final plan = ditherer.planFor(color);
        if (plan.first == plan.last) {
          colors[c] = plan.first;
          continue;
        }
        mixed[c] = 1;
        final cx = c % cellsX, cy = c ~/ cellsX;
        colors[c] = plan[_bayer[(cy & 3) * 4 + (cx & 3)]];
      }
    } else {
      colors = rawColors
          .map(
            (color) => color == null
                ? null
                : _constrainColor(
                    color,
                    colorMode,
                    paletteColors,
                    countPalette,
                  ),
          )
          .toList();
    }

    // Only a true diagonal A/B crossing is eligible for a middle color.
    // Transparency blocks smoothing. Horizontal/vertical A/B boundaries never
    // match this pattern, so they stay crisp.
    for (var cy = 0; cy + 1 < cellsY; cy++) {
      for (var cx = 0; cx + 1 < cellsX; cx++) {
        final tl = colors[cy * cellsX + cx];
        final tr = colors[cy * cellsX + cx + 1];
        final bl = colors[(cy + 1) * cellsX + cx];
        final br = colors[(cy + 1) * cellsX + cx + 1];
        if (tl == null || tr == null || bl == null || br == null) continue;
        // 描き直した線の段の横に中間の色を足すと、線がL字に太って見える。
        if (lineCell != null &&
            (lineCell[cy * cellsX + cx] != 0 ||
                lineCell[cy * cellsX + cx + 1] != 0 ||
                lineCell[(cy + 1) * cellsX + cx] != 0 ||
                lineCell[(cy + 1) * cellsX + cx + 1] != 0)) {
          continue;
        }
        if (mixed[cy * cellsX + cx] != 0 ||
            mixed[cy * cellsX + cx + 1] != 0 ||
            mixed[(cy + 1) * cellsX + cx] != 0 ||
            mixed[(cy + 1) * cellsX + cx + 1] != 0) {
          continue;
        }
        if (tl == br && tr == bl && tl != tr) {
          final middle = _middleColor(
            tl,
            tr,
            colorMode,
            paletteColors,
            countPalette,
          );
          if (middle != null) colors[cy * cellsX + cx + 1] = middle;
        }
      }
    }

    if (blockAlpha != null && Endian.host == Endian.little) {
      // ドットごとに同じ4バイトなので、行ごとにまとめて書く。
      final words = result.buffer.asUint32List(
        result.offsetInBytes,
        result.length >> 2,
      );
      for (var cy = 0; cy < cellsY; cy++) {
        final y0 = edgeY[cy], y1 = edgeY[cy + 1];
        for (var cx = 0; cx < cellsX; cx++) {
          final c = cy * cellsX + cx;
          final color = colors[c];
          final a = blockAlpha[c];
          final r = color == null ? 0 : (color >> 16) & 0xff;
          final g = color == null ? 0 : (color >> 8) & 0xff;
          final b = color == null ? 0 : color & 0xff;
          final word =
              (r * a + 127) ~/ 255 |
              ((g * a + 127) ~/ 255) << 8 |
              ((b * a + 127) ~/ 255) << 16 |
              a << 24;
          final x0 = edgeX[cx], x1 = edgeX[cx + 1];
          for (var y = y0; y < y1; y++) {
            words.fillRange(y * width + x0, y * width + x1, word);
          }
        }
      }
      return result;
    }
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        final color = colors[c];
        if (color == null && blockAlpha == null) continue;
        final r = color == null ? 0 : (color >> 16) & 0xff;
        final g = color == null ? 0 : (color >> 8) & 0xff;
        final b = color == null ? 0 : color & 0xff;
        for (var y = ys[cy]; y < ys[cy + 1]; y++) {
          for (var x = xs[cx]; x < xs[cx + 1]; x++) {
            final i = (y * width + x) * 4;
            // Colours only (no blocks): the source alpha is kept exactly.
            final a = blockAlpha == null ? data[i + 3] : blockAlpha[c];
            if (blockAlpha == null && a == 0) continue;
            result[i] = (r * a + 127) ~/ 255;
            result[i + 1] = (g * a + 127) ~/ 255;
            result[i + 2] = (b * a + 127) ~/ 255;
            result[i + 3] = a;
          }
        }
      }
    }
    return result;
  }

  /// Makes each dot's colour keep the small details inside it: an eye or a
  /// mouth is a few dark pixels in a block of skin, and the plain average
  /// of the block is barely darker than the skin, so the face came out
  /// blank. Each pixel instead counts by how far its colour is from the
  /// colours around the dot (the mean of the dot and its eight neighbours;
  /// Weber et al. 2016, "Rapid, Detail-Preserving Image Downscaling", with
  /// an exponent of 1: at 0.5 the mouth still vanished): the colour of a
  /// large area, which is also the surroundings', counts little next to a
  /// feature that stands out from them, while a dot on the edge between two
  /// large areas keeps about their average. A dot of one even colour is
  /// left as it is.
  void _keepDetails(
    Uint8List data,
    int width,
    List<int> xs,
    List<int> ys,
    int cellsX,
    int cellsY,
    List<int?> colors, {
    Uint8List? inked,
    Uint8List? settled,
    Uint8List? even,
  }) {
    final around = Float64List(cellsX * cellsY * 3);
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        var r = 0.0, g = 0.0, b = 0.0, n = 0;
        for (
          var ny = math.max(0, cy - 1);
          ny <= math.min(cellsY - 1, cy + 1);
          ny++
        ) {
          for (
            var nx = math.max(0, cx - 1);
            nx <= math.min(cellsX - 1, cx + 1);
            nx++
          ) {
            final color = colors[ny * cellsX + nx];
            if (color == null) continue;
            r += (color >> 16) & 0xff;
            g += (color >> 8) & 0xff;
            b += color & 0xff;
            n++;
          }
        }
        final c = cy * cellsX + cx;
        if (n == 0) continue;
        around[c * 3] = r / n;
        around[c * 3 + 1] = g / n;
        around[c * 3 + 2] = b / n;
      }
    }
    const span = 255 * 1.7320508075688772;
    final edgeX = Int32List.fromList(xs), edgeY = Int32List.fromList(ys);
    var cellW = 0, cellH = 0;
    for (var cx = 0; cx < cellsX; cx++) {
      cellW = math.max(cellW, edgeX[cx + 1] - edgeX[cx]);
    }
    for (var cy = 0; cy < cellsY; cy++) {
      cellH = math.max(cellH, edgeY[cy + 1] - edgeY[cy]);
    }
    final cell = _CellPaint(cellW * cellH);
    final words = _pixelWords(data, data.length ~/ 4);
    final pr = cell.r, pg = cell.g, pb = cell.b, pw = cell.w, pa = cell.a;
    final keys = cell._key;
    // 隣のドットの、色を決め直す前の色。
    final raw = List<int?>.of(colors);
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        if (colors[c] == null) continue;
        if (settled != null && settled[c] != 0) continue;
        if (even != null && even[c] != 0) continue;
        final ar = around[c * 3],
            ag = around[c * 3 + 1],
            ab = around[c * 3 + 2];
        var wr = 0.0, wg = 0.0, wb = 0.0, total = 0.0;
        // ドットの画素（[cell]へ）と、隣の画素と同じ色（各色4段・不透明度
        // 16段ごと）だった数。
        var n = 0, same = 0, lastKey = -1;
        final x0 = edgeX[cx], x1 = edgeX[cx + 1];
        for (var y = edgeY[cy]; y < edgeY[cy + 1]; y++) {
          for (var x = x0, p = y * width + x0; x < x1; x++, p++) {
            if (inked != null && inked[p] != 0) continue;
            final v = words[p];
            final a = v >> 24;
            if (a == 0) continue;
            final d0 = v & 0xff, d1 = (v >> 8) & 0xff, d2 = (v >> 16) & 0xff;
            final r = d0 * 255 / a;
            final g = d1 * 255 / a;
            final b = d2 * 255 / a;
            final dr = r - ar, dg = g - ag, db = b - ab;
            final far = math.sqrt(dr * dr + dg * dg + db * db) / span;
            final w = far * a;
            wr += r * w;
            wg += g * w;
            wb += b * w;
            total += w;
            pr[n] = r;
            pg[n] = g;
            pb[n] = b;
            pw[n] = w;
            pa[n] = a;
            final key =
                d0 >> 2 | (d1 >> 2) << 6 | (d2 >> 2) << 12 | (a >> 4) << 18;
            keys[n] = key;
            if (key == lastKey) same++;
            lastKey = key;
            n++;
          }
        }
        cell
          ..count = n
          .._same = same;
        // An even area (every pixel the colour around it) keeps its mean.
        if (total < 1e-3) continue;
        colors[c] = cell.colour(
          wr / total,
          wg / total,
          wb / total,
          raw,
          cellsX,
          cellsY,
          c,
        );
      }
    }
  }

  /// 乗算済みRGBAの画素を1つずつ32ビットで読む（RGBAは下の桁から：
  /// R＝`v & 0xff`、G＝`(v >> 8) & 0xff`、B＝`(v >> 16) & 0xff`、A＝`v >> 24`）。
  /// 4バイト境界にない・ビッグエンディアンの端末では、並べ直した写し。
  static Uint32List _pixelWords(Uint8List data, int count) {
    if (Endian.host == Endian.little && data.offsetInBytes % 4 == 0) {
      return data.buffer.asUint32List(data.offsetInBytes, count);
    }
    final out = Uint32List(count);
    for (var p = 0, i = 0; p < count; p++, i += 4) {
      out[p] =
          data[i] | data[i + 1] << 8 | data[i + 2] << 16 | data[i + 3] << 24;
    }
    return out;
  }

  /// 描き直した線と塗りの間で、線のインクを外した残りが少なく消えたドット
  /// （線が斜めにかかるドットの、塗りの側の残り）は、塗りの側の隣と同じ
  /// 不透明度と色で残す（消すと、線と塗りの間に透明な穴が開いた）。線のインクも
  /// 含めて半分以上が不透明なドットで、上下か左右の一方が線、もう一方が
  /// 残したドットのときだけ。
  static void _fillBesideLines(
    int cellsX,
    int cellsY,
    Int32List edgeX,
    Int32List edgeY,
    Uint8List line,
    Int32List whole,
    Uint8List kept,
    List<int?> rawColors,
    Uint8List settled,
  ) {
    final count = cellsX * cellsY;
    final fill = <(int, int)>[];
    final seen = Uint8List(count);
    for (var k = 0; k < count; k++) {
      if (line[k] == 0) continue;
      final kx = k % cellsX, ky = k ~/ cellsX;
      for (final (sx, sy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final cx = kx + sx, cy = ky + sy;
        if (cx < 0 || cy < 0 || cx >= cellsX || cy >= cellsY) continue;
        final c = cy * cellsX + cx;
        if (line[c] != 0 || kept[c] != 0 || seen[c] != 0) continue;
        seen[c] = 1;
        final area = (edgeX[cx + 1] - edgeX[cx]) * (edgeY[cy + 1] - edgeY[cy]);
        if (whole[c] * 2 < area * 255) continue;
        for (final (dx, dy) in const [(1, 0), (0, 1)]) {
          final ax = cx - dx, ay = cy - dy, bx = cx + dx, by = cy + dy;
          if (ax < 0 || ay < 0 || bx >= cellsX || by >= cellsY) continue;
          final a = ay * cellsX + ax, b = by * cellsX + bx;
          final int other;
          if (line[a] != 0 && line[b] == 0) {
            other = b;
          } else if (line[b] != 0 && line[a] == 0) {
            other = a;
          } else {
            continue;
          }
          if (kept[other] >= 192 && rawColors[other] != null) {
            fill.add((c, other));
            break;
          }
        }
      }
    }
    // 色も塗りの側の隣から（残りは線の縁の色なので）。
    for (final (c, other) in fill) {
      kept[c] = kept[other];
      rawColors[c] = rawColors[other];
      settled[c] = 1;
    }
  }

  /// 描き直した線の内側のドットに、線の外側の色（紙・透明）が残ったもの
  /// （階段に描いた線の内側の角のドットに、元の線の外側の縁が入っていた）
  /// は、内側の隣の色にする：上下か左右で、一方の隣が線、その線の先の
  /// ドットと同じ色で、反対の隣（線でない）とは違う色のドット。線と塗りの
  /// 間に本当にある細い塗り（前髪の下の肌の影）は、線の先の色と違うので
  /// そのまま。
  static void _closeHolesBesideLines(
    int cellsX,
    int cellsY,
    Uint8List line,
    List<int?> colors,
    Uint8List alpha,
  ) {
    bool alike(int? a, int? b) {
      if (a == null || b == null) return a == b;
      final dr = ((a >> 16) & 0xff) - ((b >> 16) & 0xff);
      final dg = ((a >> 8) & 0xff) - ((b >> 8) & 0xff);
      final db = (a & 0xff) - (b & 0xff);
      return dr * dr + dg * dg + db * db < 24 * 24;
    }

    final changes = <(int, int)>[];
    final count = cellsX * cellsY;
    final seen = Uint8List(count);
    for (var k = 0; k < count; k++) {
      if (line[k] == 0) continue;
      final kx = k % cellsX, ky = k ~/ cellsX;
      // 線のドットの上下左右の、線でないドット。
      for (final (sx, sy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final cx = kx + sx, cy = ky + sy;
        if (cx < 0 || cy < 0 || cx >= cellsX || cy >= cellsY) continue;
        final c = cy * cellsX + cx;
        if (line[c] != 0 || seen[c] != 0) continue;
        seen[c] = 1;
        // 線の先のドットと同じ色か（線の外側の色が残った）。
        var leaked = false, best = -1;
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final lx = cx + dx, ly = cy + dy;
          final bx = cx + 2 * dx, by = cy + 2 * dy;
          if (bx < 0 || by < 0 || bx >= cellsX || by >= cellsY) continue;
          final l = ly * cellsX + lx, b = by * cellsX + bx;
          if (line[l] == 0 || line[b] != 0) continue;
          if (!alike(colors[c], colors[b])) continue;
          leaked = true;
          // その線の反対側の隣（線でない）を優先する。
          final ox = cx - dx, oy = cy - dy;
          if (ox >= 0 && oy >= 0 && ox < cellsX && oy < cellsY) {
            final o = oy * cellsX + ox;
            if (line[o] == 0 &&
                colors[o] != null &&
                alpha[o] != 0 &&
                !alike(colors[c], colors[o])) {
              best = o;
            }
          }
          if (best >= 0) break;
        }
        if (!leaked) continue;
        if (best < 0) {
          // 反対側も線なら（線に囲まれたドット）、線でない隣のどれか。
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final ox = cx + dx, oy = cy + dy;
            if (ox < 0 || oy < 0 || ox >= cellsX || oy >= cellsY) continue;
            final o = oy * cellsX + ox;
            if (line[o] != 0 || colors[o] == null || alpha[o] == 0) continue;
            if (alike(colors[c], colors[o])) {
              // 線の外側の色と同じ隣がある：外側につながったドット。
              best = -1;
              break;
            }
            if (best < 0) best = o;
          }
        }
        if (best >= 0) changes.add((c, best));
      }
    }
    for (final (c, o) in changes) {
      colors[c] = colors[o];
      alpha[c] = alpha[o];
    }
  }

  /// 描き直した線を置く：線のドットは線の色と不透明度にする。描いた線から
  /// 外れたのに線のインクで9割以上覆われたドットは、線の幅の中なので隣の
  /// 線の色にし、それ以外で地の画素が1つも無いドット（線のインクの印は
  /// 線の縁のぼけまで含む）は、近くの地のドットの色と不透明度を借りる。
  /// どれも[settled]に印を付ける。
  static void _placeLines(
    PixelArtLines lines,
    List<int> xs,
    List<int> ys,
    Int32List pixels,
    Uint8List kept,
    List<int?> rawColors,
    Uint8List settled,
    Uint8List borrowedRing,
  ) {
    final cellsX = xs.length - 1, cellsY = ys.length - 1;
    final count = cellsX * cellsY;
    for (var c = 0; c < count; c++) {
      if (lines.line[c] == 0) continue;
      kept[c] = lines.alpha[c];
      rawColors[c] = lines.color[c];
      settled[c] = 1;
    }
    for (var c = 0; c < count; c++) {
      final cx = c % cellsX, cy = c ~/ cellsX;
      if (lines.line[c] != 0) continue;
      final covered = lines.cover[c] >= 0.9;
      if (!covered && pixels[c] != 0) continue;
      int? borrowed, borrowedAlpha, lineColor, lineAlpha;
      var ring = 0;
      // ほとんど線のインクで覆われたドット（線の幅の中）は線の色。
      for (final (ox, oy) in covered ? _ring : const <(int, int)>[]) {
        final nx = cx + ox, ny = cy + oy;
        if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
        final o = ny * cellsX + nx;
        if (lines.line[o] == 0) continue;
        lineColor = lines.color[o];
        lineAlpha = lines.alpha[o];
        break;
      }
      if (lineColor == null && pixels[c] > 0) continue;
      for (var r = 1; r <= 2 && borrowed == null && lineColor == null; r++) {
        var red = 0, green = 0, blue = 0, coloured = 0, top = 0, ground = 0;
        for (var ny = cy - r; ny <= cy + r; ny++) {
          for (var nx = cx - r; nx <= cx + r; nx++) {
            if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
            final o = ny * cellsX + nx;
            if (o == c) continue;
            if (lines.line[o] != 0) continue;
            if (pixels[o] == 0) continue;
            ground++;
            top = math.max(top, kept[o]);
            final color = rawColors[o];
            if (kept[o] == 0 || color == null) continue;
            red += (color >> 16) & 0xff;
            green += (color >> 8) & 0xff;
            blue += color & 0xff;
            coloured++;
          }
        }
        if (ground == 0) continue;
        ring = r;
        borrowedAlpha = top;
        borrowed = coloured == 0
            ? 0xff000000
            : _opaque(
                ((red / coloured).round() << 16) |
                    ((green / coloured).round() << 8) |
                    (blue / coloured).round(),
              );
      }
      if (lineColor != null) {
        kept[c] = lineAlpha!;
        rawColors[c] = lineColor;
        lines.line[c] = 1;
      } else if (borrowed != null) {
        kept[c] = borrowedAlpha!;
        rawColors[c] = kept[c] == 0 ? null : borrowed;
        borrowedRing[c] = ring;
      } else {
        continue;
      }
      settled[c] = 1;
    }
  }

  /// 地の画素が無いので近くの地のドットから色を借りたドット（[_placeLines]）
  /// は、近くのドットの色を混ぜずに、近くでいちばん多い色（同じ数なら
  /// 上の行から先に見つかった色）にする。混ぜると、肌とシャツの間の灰色の
  /// ような、絵に無い色になった。
  static void _settleBorrowed(
    PixelArtLines lines,
    int cellsX,
    int cellsY,
    Int32List pixels,
    Uint8List kept,
    List<int?> colors,
    Uint8List borrowedRing,
  ) {
    final counts = <int, int>{};
    for (var c = 0; c < cellsX * cellsY; c++) {
      final r = borrowedRing[c];
      if (r == 0 || colors[c] == null) continue;
      final cx = c % cellsX, cy = c ~/ cellsX;
      counts.clear();
      int? pick;
      var most = 0;
      for (var ny = cy - r; ny <= cy + r; ny++) {
        for (var nx = cx - r; nx <= cx + r; nx++) {
          if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
          final o = ny * cellsX + nx;
          if (o == c || lines.line[o] != 0 || pixels[o] == 0) continue;
          final color = colors[o];
          if (kept[o] == 0 || color == null || borrowedRing[o] != 0) continue;
          final n = counts[color] = (counts[color] ?? 0) + 1;
          if (n > most) {
            most = n;
            pick = color;
          }
        }
      }
      if (pick != null) colors[c] = pick;
    }
  }

  /// Where the cells of a [length]-pixel side start, plus [length] itself:
  /// cells [size] pixels long (rounded down where [size] is fractional).
  static List<int> cellEdges(int length, double size) {
    // The small margin keeps an exact division (1920 / 100 dots) from
    // gaining a sliver of an extra cell to rounding.
    final count = math.max(1, (length / size - 1e-9).ceil());
    return [for (var i = 0; i < count; i++) (i * size).floor(), length];
  }

  /// Decides, for every cell, whether it becomes a pixel-art pixel and with
  /// which alpha (0 = left transparent).
  ///
  /// A cell's alpha is measured against the strongest alpha around it (its
  /// own and its eight neighbours'), so the anti-aliased fringe of a shape is
  /// told apart from the shape itself whatever opacity it was painted with:
  /// - a cell at least half filled at that strength is kept;
  /// - a thinner stroke is kept where it peaks across the stroke (a ridge,
  ///   looked for across the way the paint in the cell runs, so a line's end
  ///   doesn't count as a peak along it), so lines narrower than a block
  ///   don't vanish, but a sliver of fringe along the edge of a filled shape
  ///   doesn't add bumps to it;
  /// - a cell much fainter than its neighbours is kept only when it is an
  ///   even area of its own (lighter paint next to darker paint), never when
  ///   it is just the fade-out of an edge.
  /// A kept cell takes the strength around it, unless it is such an even
  /// area of clearly lighter paint, which keeps its own: so edges come out
  /// solid, lighter paint stays lighter, and alpha is never averaged.
  Uint8List _blockAlphas(
    int cellsX,
    int cellsY,
    Int32List alphaSum,
    Uint8List alphaMax,
    Int32List pixels,
    Uint8List orientation, {
    Uint8List? lineCells,
  }) {
    final count = cellsX * cellsY;
    final level = Uint8List(count);
    final coverage = Float64List(count);
    final even = List<bool>.filled(count, false);
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        var top = 0;
        for (var ny = cy - 1; ny <= cy + 1; ny++) {
          if (ny < 0 || ny >= cellsY) continue;
          for (var nx = cx - 1; nx <= cx + 1; nx++) {
            if (nx < 0 || nx >= cellsX) continue;
            final a = alphaMax[ny * cellsX + nx];
            if (a > top) top = a;
          }
        }
        level[c] = top;
        if (top > 0 && pixels[c] > 0) {
          coverage[c] = alphaSum[c] / (pixels[c] * top);
        }
      }
    }
    // An even area: the cell is filled at its own strength, and so are most
    // of its neighbours (all but one, at most three, of those on the canvas).
    // The fade-out along an edge has at most the two cells along the edge.
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        final own = alphaMax[c];
        if (own == 0 || alphaSum[c] < 0.9 * pixels[c] * own) continue;
        var neighbours = 0, similar = 0;
        if (cx > 0) {
          neighbours++;
          if (_similar(alphaMax[c - 1], own)) similar++;
        }
        if (cx + 1 < cellsX) {
          neighbours++;
          if (_similar(alphaMax[c + 1], own)) similar++;
        }
        if (cy > 0) {
          neighbours++;
          if (_similar(alphaMax[c - cellsX], own)) similar++;
        }
        if (cy + 1 < cellsY) {
          neighbours++;
          if (_similar(alphaMax[c + cellsX], own)) similar++;
        }
        even[c] = neighbours >= 2 && similar >= math.min(3, neighbours - 1);
      }
    }

    // 描き直す線のドットは、その線で埋まったドット（線のインクを外した
    // 残りで測ると空に近く、線の横に残った縁のわずかなインクが線の頂として
    // 残り、線から1ドット飛び出した）。
    if (lineCells != null) {
      for (var c = 0; c < count; c++) {
        if (lineCells[c] != 0) coverage[c] = 1;
      }
    }
    double cov(int x, int y) => x < 0 || y < 0 || x >= cellsX || y >= cellsY
        ? 0
        : coverage[y * cellsX + x];
    bool solid(int x, int y) => cov(x, y) >= 0.5;
    // Peaks across the axis. Ties go to the later cell, so a stroke split
    // evenly between two rows of blocks stays one block thick.
    bool ridge(double before, double here, double after) =>
        here >= before && here > after;
    // The fringe along a filled shape (solid on one side, emptier outside),
    // or the gap between two shapes (solid on both sides). A line that does
    // cross such a gap is joined up again by [_bridgeGaps].
    bool fringe(
      bool solidBefore,
      double before,
      bool solidAfter,
      double after,
      double here,
    ) =>
        (solidBefore && solidAfter) ||
        (solidBefore && after < here) ||
        (solidAfter && before < here);

    final out = Uint8List(count);
    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final c = cy * cellsX + cx;
        final own = alphaMax[c];
        if (own == 0) continue;
        if (own * 2 < level[c]) {
          if (even[c]) out[c] = own;
          continue;
        }
        final here = coverage[c];
        var keep = here >= 0.5;
        if (!keep) {
          final l = cov(cx - 1, cy), r = cov(cx + 1, cy);
          final u = cov(cx, cy - 1), d = cov(cx, cy + 1);
          final edgeX = fringe(
            solid(cx - 1, cy),
            l,
            solid(cx + 1, cy),
            r,
            here,
          );
          final edgeY = fringe(
            solid(cx, cy - 1),
            u,
            solid(cx, cy + 1),
            d,
            here,
          );
          final across = orientation[c];
          keep =
              (across != 2 && ridge(u, here, d) && !edgeX) ||
              (across != 1 && ridge(l, here, r) && !edgeY);
        }
        if (!keep) continue;
        out[c] = !_similar(own, level[c]) && even[c] ? own : level[c];
      }
    }
    return out;
  }

  static const _ring = [
    (0, -1),
    (1, -1),
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
  ];

  /// Keeps a skipped cell when the paint inside it joins kept cells that
  /// would otherwise not touch: a thin line running into a filled shape
  /// passes through the shape's soft rim, which on its own isn't kept, and
  /// the line would stop one block short of the shape. A gap that is really
  /// there (two shapes whose rims don't meet inside the cell) stays open.
  Uint8List _bridgeGaps(
    Uint8List data,
    int width,
    double size,
    List<int> xs,
    List<int> ys,
    Uint8List alphaMax,
    Uint8List kept,
  ) {
    if (size < 2) return kept;
    final cellsX = xs.length - 1, cellsY = ys.length - 1;
    for (var pass = 0; pass < 2; pass++) {
      final bridges = <int, int>{};
      for (var cy = 0; cy < cellsY; cy++) {
        for (var cx = 0; cx < cellsX; cx++) {
          final c = cy * cellsX + cx;
          if (kept[c] != 0 || alphaMax[c] == 0) continue;
          // Kept neighbours, grouped by whether they touch each other.
          final group = List<int>.filled(8, -1);
          var groups = 0;
          for (var k = 0; k < 8; k++) {
            final (ox, oy) = _ring[k];
            final nx = cx + ox, ny = cy + oy;
            if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
            if (kept[ny * cellsX + nx] == 0) continue;
            group[k] = groups++;
          }
          if (groups < 2) continue;
          for (var changed = true; changed;) {
            changed = false;
            for (var a = 0; a < 8; a++) {
              for (var b = 0; b < 8; b++) {
                if (group[a] < 0 || group[b] < 0 || group[a] == group[b]) {
                  continue;
                }
                final (ax, ay) = _ring[a];
                final (bx, by) = _ring[b];
                if ((ax - bx).abs() > 1 || (ay - by).abs() > 1) continue;
                final from = math.max(group[a], group[b]);
                final to = math.min(group[a], group[b]);
                for (var k = 0; k < 8; k++) {
                  if (group[k] == from) group[k] = to;
                }
                changed = true;
              }
            }
          }
          if (group.where((g) => g >= 0).toSet().length < 2) continue;
          final level = _strongestAround(kept, cellsX, cellsY, cx, cy);
          if (alphaMax[c] * 2 < level) continue;
          if (_paintJoins(data, width, xs, ys, cx, cy, level, group)) {
            bridges[c] = level;
          }
        }
      }
      if (bridges.isEmpty) break;
      bridges.forEach((c, a) => kept[c] = a);
    }
    return kept;
  }

  static int _strongestAround(
    Uint8List kept,
    int cellsX,
    int cellsY,
    int cx,
    int cy,
  ) {
    var top = 0;
    for (final (ox, oy) in _ring) {
      final nx = cx + ox, ny = cy + oy;
      if (nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) continue;
      top = math.max(top, kept[ny * cellsX + nx]);
    }
    return top;
  }

  /// Whether one connected patch of solid paint inside the cell reaches the
  /// sides (or, for a diagonal neighbour, the corner) facing two different
  /// groups of kept neighbours.
  static bool _paintJoins(
    Uint8List data,
    int width,
    List<int> xs,
    List<int> ys,
    int cx,
    int cy,
    int level,
    List<int> group,
  ) {
    final x0 = xs[cx], y0 = ys[cy];
    final w = xs[cx + 1] - x0, h = ys[cy + 1] - y0;
    final seen = Uint8List(w * h);
    final stack = <int>[];
    for (var start = 0; start < w * h; start++) {
      if (seen[start] != 0) continue;
      final sx = start % w, sy = start ~/ w;
      if (data[((y0 + sy) * width + x0 + sx) * 4 + 3] * 2 < level) continue;
      final reached = <int>{};
      seen[start] = 1;
      stack.add(start);
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final px = p % w, py = p ~/ w;
        for (var k = 0; k < 8; k++) {
          if (group[k] < 0) continue;
          final (ox, oy) = _ring[k];
          final onX = ox < 0 ? px == 0 : (ox > 0 ? px == w - 1 : true);
          final onY = oy < 0 ? py == 0 : (oy > 0 ? py == h - 1 : true);
          final touches = ox != 0 && oy != 0
              ? (onX && _near(py, oy, h)) || (onY && _near(px, ox, w))
              : onX && onY;
          if (touches) reached.add(group[k]);
        }
        if (reached.length >= 2) return true;
        for (var ny = py - 1; ny <= py + 1; ny++) {
          for (var nx = px - 1; nx <= px + 1; nx++) {
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            final q = ny * w + nx;
            if (seen[q] != 0) continue;
            if (data[((y0 + ny) * width + x0 + nx) * 4 + 3] * 2 < level) {
              continue;
            }
            seen[q] = 1;
            stack.add(q);
          }
        }
      }
    }
    return false;
  }

  /// Whether [v] lies in the half of a side of length [n] nearer the end it
  /// faces ([o] -1: the start, 1: the end): a diagonal neighbour is reached
  /// through that half of each side.
  static bool _near(int v, int o, int n) {
    final half = math.max(1, (n + 1) ~/ 2);
    return o < 0 ? v < half : v >= n - half;
  }

  /// How different dots [a] and [b] look: the squared CIELAB distance, from
  /// [labs] (three per dot).
  static double _apart(Float64List labs, int a, int b) {
    final dl = labs[a * 3] - labs[b * 3],
        da = labs[a * 3 + 1] - labs[b * 3 + 1],
        db = labs[a * 3 + 2] - labs[b * 3 + 2];
    return dl * dl + da * da + db * db;
  }

  /// Whether dot [c] differs sharply in colour from a side neighbour (more
  /// than [_edge] apart in CIELAB); transparent neighbours do not count.
  static bool _onEdge(
    List<int?> colors,
    Float64List labs,
    int cellsX,
    int cellsY,
    int c,
  ) {
    final cx = c % cellsX, cy = c ~/ cellsX;
    bool edgeTo(int n) =>
        colors[n] != null && _apart(labs, c, n) > _edge * _edge;
    return (cx > 0 && edgeTo(c - 1)) ||
        (cx + 1 < cellsX && edgeTo(c + 1)) ||
        (cy > 0 && edgeTo(c - cellsX)) ||
        (cy + 1 < cellsY && edgeTo(c + cellsX));
  }

  /// The colour of the side neighbour of dot [c] that is not itself on an
  /// edge and looks most like it, if there is one.
  static int? _mostAlikeInside(
    List<int?> colors,
    Float64List labs,
    Uint8List edge,
    int cellsX,
    int cellsY,
    int c,
  ) {
    final cx = c % cellsX, cy = c ~/ cellsX;
    int? best;
    var bestDistance = double.infinity;
    for (var k = 0; k < 4; k++) {
      final int n;
      switch (k) {
        case 0:
          if (cx == 0) continue;
          n = c - 1;
        case 1:
          if (cx + 1 >= cellsX) continue;
          n = c + 1;
        case 2:
          if (cy == 0) continue;
          n = c - cellsX;
        default:
          if (cy + 1 >= cellsY) continue;
          n = c + cellsX;
      }
      final other = colors[n];
      if (other == null || edge[n] != 0) continue;
      final d = _apart(labs, c, n);
      if (d < bestDistance) {
        bestDistance = d;
        best = other;
      }
    }
    return best;
  }

  /// How different neighbouring dots must look to make an edge.
  static const double _edge = 20;

  /// Alphas within a fifth of each other count as the same strength.
  static bool _similar(int a, int b) => a * 5 >= b * 4 && a * 4 <= b * 5;

  int _constrainColor(
    int color,
    PixelColorMode mode,
    List<int> explicitPalette,
    List<int> countPalette,
  ) {
    if (mode == PixelColorMode.count && countPalette.isNotEmpty) {
      return _nearestColor(color, countPalette);
    }
    if ((mode == PixelColorMode.explicit || mode == PixelColorMode.palette) &&
        explicitPalette.isNotEmpty) {
      return _nearestColor(color, explicitPalette);
    }
    return color;
  }

  int? _middleColor(
    int a,
    int b,
    PixelColorMode mode,
    List<int> explicitPalette,
    List<int> countPalette,
  ) {
    // 色を指定しない（元の色のまま）ときは、絵に無い中間の色を作らない。
    if (mode == PixelColorMode.none) return null;
    final middle = _rgb(
      ((((a >> 16) & 0xff) + ((b >> 16) & 0xff)) / 2).round(),
      ((((a >> 8) & 0xff) + ((b >> 8) & 0xff)) / 2).round(),
      (((a & 0xff) + (b & 0xff)) / 2).round(),
    );
    if (mode == PixelColorMode.count) {
      if (countPalette.isEmpty) return null;
      final candidate = _nearestColor(middle, countPalette);
      return candidate == a || candidate == b ? null : candidate;
    }
    if (mode == PixelColorMode.explicit || mode == PixelColorMode.palette) {
      if (explicitPalette.isEmpty) return null;
      final candidate = _nearestColor(middle, explicitPalette);
      return candidate == a || candidate == b ? null : candidate;
    }
    return null;
  }

  /// The [requestedCount] colours that best stand for [colors] (one entry
  /// per dot): spread out first (each next one the colour furthest from
  /// those chosen, starting from the commonest), then each moved to the
  /// middle of the dots nearest it, weighted by how many there are (k-means,
  /// by how different the colours look), and finally to the real colour of
  /// those dots nearest that middle. Picking the most different colours alone
  /// left a large area of a middle colour (a face) to the nearest extreme.
  List<int> _buildCountPalette(List<int> colors, int requestedCount) {
    if (colors.isEmpty) return const [];
    final weights = <int, int>{};
    for (final color in colors) {
      final rgb = color & 0xffffff;
      weights[rgb] = (weights[rgb] ?? 0) + 1;
    }
    final unique = weights.keys.toList()..sort();
    final count = requestedCount.clamp(1, 256);
    if (unique.length <= count) return [for (final c in unique) _opaque(c)];

    final labs = [for (final c in unique) _lab(c)];
    final weight = [for (final c in unique) weights[c]!];
    double distance(Float64List a, Float64List b) {
      final dl = a[0] - b[0], da = a[1] - b[1], db = a[2] - b[2];
      return dl * dl + da * da + db * db;
    }

    // Spread out, from the commonest colour.
    var first = 0;
    for (var i = 1; i < unique.length; i++) {
      if (weight[i] > weight[first]) first = i;
    }
    final chosen = <int>[first];
    final nearest = Float64List(unique.length)
      ..fillRange(0, unique.length, double.infinity);
    while (chosen.length < count) {
      final last = labs[chosen.last];
      var best = -1;
      var bestDistance = 0.0;
      for (var i = 0; i < unique.length; i++) {
        final d = distance(labs[i], last);
        if (d < nearest[i]) nearest[i] = d;
        if (nearest[i] > bestDistance) {
          bestDistance = nearest[i];
          best = i;
        }
      }
      if (best < 0) break;
      chosen.add(best);
    }

    // k-means on how the colours look, weighted by the number of dots.
    final centres = [for (final i in chosen) Float64List.fromList(labs[i])];
    final owner = Int32List(unique.length);
    final rounds = count > 64 ? 4 : 8;
    for (var round = 0; round <= rounds; round++) {
      for (var i = 0; i < unique.length; i++) {
        var best = 0;
        var bestDistance = double.infinity;
        for (var k = 0; k < centres.length; k++) {
          final d = distance(labs[i], centres[k]);
          if (d < bestDistance) {
            bestDistance = d;
            best = k;
          }
        }
        owner[i] = best;
      }
      if (round == rounds) break;
      final sums = List.generate(centres.length, (_) => Float64List(4));
      for (var i = 0; i < unique.length; i++) {
        final sum = sums[owner[i]], w = weight[i].toDouble();
        sum[0] += labs[i][0] * w;
        sum[1] += labs[i][1] * w;
        sum[2] += labs[i][2] * w;
        sum[3] += w;
      }
      for (var k = 0; k < centres.length; k++) {
        final sum = sums[k];
        if (sum[3] == 0) continue;
        centres[k]
          ..[0] = sum[0] / sum[3]
          ..[1] = sum[1] / sum[3]
          ..[2] = sum[2] / sum[3];
      }
    }
    // Each centre becomes the real colour of its dots nearest it.
    final palette = <int>[];
    for (var k = 0; k < centres.length; k++) {
      var best = -1;
      var bestDistance = double.infinity;
      for (var i = 0; i < unique.length; i++) {
        if (owner[i] != k) continue;
        final d = distance(labs[i], centres[k]);
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      if (best >= 0) palette.add(_opaque(unique[best]));
    }
    return palette.toSet().toList();
  }

  int _nearestColor(int color, List<int> palette) {
    var best = palette.first;
    var bestDistance = 1 << 30;
    for (final candidate in palette) {
      final d = _distance(color, candidate);
      if (d < bestDistance) {
        bestDistance = d;
        best = candidate;
      }
    }
    return _rgb((best >> 16) & 0xff, (best >> 8) & 0xff, best & 0xff);
  }

  /// How different two colours look: the squared CIELAB distance (x100).
  /// Plain RGB distance puts a mid grey as near yellow as white or black, so
  /// the grey edge between a white shape and its dark outline came out as
  /// yellow dots.
  int _distance(int a, int b) {
    final x = _lab(a), y = _lab(b);
    final dl = x[0] - y[0], da = x[1] - y[1], db = x[2] - y[2];
    return (100 * (dl * dl + da * da + db * db)).round();
  }

  static final Map<int, Float64List> _labCache = {};

  static Float64List _lab(int color) {
    final rgb = color & 0xffffff;
    final cached = _labCache[rgb];
    if (cached != null) return cached;
    if (_labCache.length >= 1 << 16) _labCache.clear();
    double linear(int c) {
      final v = c / 255;
      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linear((rgb >> 16) & 0xff);
    final g = linear((rgb >> 8) & 0xff);
    final b = linear(rgb & 0xff);
    // sRGB (D65) to XYZ, relative to the white point.
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    double f(double t) => t > 216 / 24389
        ? math.pow(t, 1 / 3).toDouble()
        : (24389 / 27 * t + 16) / 116;
    final fx = f(x), fy = f(y), fz = f(z);
    return _labCache[rgb] = Float64List.fromList([
      116 * fy - 16,
      500 * (fx - fy),
      200 * (fy - fz),
    ]);
  }

  int _rgb(int r, int g, int b) =>
      0xff000000 | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);

  static int _opaque(int rgb) => 0xff000000 | (rgb & 0xffffff);

  /// ドットの画素の乗算済みの値と不透明度のばらつき（4つの値の分散の和）が
  /// これ以下なら、ほとんど1色のドット（各値の差がおよそ2以下）。
  static const double _evenSpread = 16;

  /// The 4 x 4 ordered-dithering pattern (Bayer): which of the 16 colours of
  /// a mix (darkest first) each dot of a 4 x 4 square shows, so every share
  /// of the mix is spread evenly over the square.
  static const _bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
}

/// 1つのドットの地の画素（乗算前の色・細部の重み・不透明度）と、そこから
/// ドットの色を決めるもの。
///
/// 色を混ぜた平均は、2つの面にまたがるドットで絵に無い中間の色になる
/// （髪と紙の境目が灰色、髪と線の境目がくすんだ茶色）。そこで、ドットの
/// 画素を色の近いまとまり（最大3つ）に分け、細部の重みの合計がいちばん
/// 大きいまとまりの色（中央値に最も近い、実際にある画素の色）にする。
/// 2つの面の間のアンチエイリアスの画素（2つのまとまりの色を結ぶ線の上の
/// 色）は、自分のまとまりにせず近い方の面へ入れる。面の色がはっきり
/// まとまっていない所（グラデーション・質感）は、今までどおり重み付きの
/// 平均（に最も近い、実際にある画素の色）。色は、なるべく不透明な画素
/// （不透明度が半分以上）から取る。
class _CellPaint {
  _CellPaint(int capacity)
    : r = Float64List(capacity),
      g = Float64List(capacity),
      b = Float64List(capacity),
      w = Float64List(capacity),
      a = Uint8List(capacity),
      _key = Int32List(capacity),
      _runFirst = Int32List(capacity),
      _runSlot = Int32List(capacity),
      _runArea = Float64List(capacity),
      _runShare = Float64List(capacity),
      _runGroup = Uint8List(capacity),
      _mask = _slotsFor(capacity) - 1 {
    _slotKey = Int32List(_mask + 1)..fillRange(0, _mask + 1, -1);
    _slotRun = Int32List(_mask + 1);
  }

  static int _slotsFor(int capacity) {
    var n = 16;
    while (n < capacity * 2) {
      n <<= 1;
    }
    return n;
  }

  final Float64List r, g, b, w;
  final Uint8List a;

  /// 画素ごとの色（乗算済みの値と不透明度を各4段・16段ごとにまとめた）。
  final Int32List _key;

  /// 同じ色の画素のまとまり：最初の画素・表の場所・不透明度の合計・細部の
  /// 重み・どの面のまとまりか。
  final Int32List _runFirst, _runSlot;
  final Float64List _runArea, _runShare;
  final Uint8List _runGroup;

  int _runs = 0;
  final int _mask;
  late final Int32List _slotKey, _slotRun;

  int count = 0;

  /// 前の画素と同じ色（[_key]）だった画素の数。
  int _same = 0;

  /// まとまりに分けない色の幅と、別の面とみなすまとまりどうしの色の差、
  /// 隣のドットへ続く面とみなす色の差（RGBの距離）。
  static const double _spread = 12, _apartAreas = 32, _sameArea = 20;

  /// 面の色とみなす、まとまりの色からの距離（まとまりどうしの距離に
  /// 対する割合）と、面の色でドットの半分以上が占められていること。
  static const double _pureShare = 0.12, _pureEnough = 0.5;

  /// 塗った面のドット：前の画素と同じ色の画素がこの割合以上。
  static const double _flat = 0.2;

  double _d2(int i, double x, double y, double z) {
    final dr = r[i] - x, dg = g[i] - y, db = b[i] - z;
    return dr * dr + dg * dg + db * db;
  }

  /// 細部の重みで平均した色が([mr], [mg], [mb])のドット[c]の色。[raw]は
  /// ドットの（決め直す前の）色（[cellsX]×[cellsY]）。
  int colour(
    double mr,
    double mg,
    double mb,
    List<int?> raw,
    int cellsX,
    int cellsY,
    int c,
  ) {
    // 隣の画素どうしの色がほとんど違えば、面ではなく質感・ざらつき・
    // グラデーション：平均に最も近い画素の色。
    if (_same < _flat * count) return _nearest(mr, mg, mb);
    // 平均からいちばん離れた画素から、どの画素も色の差が小さければ1つの面：
    // 平均に最も近い画素の色（離れた画素が1つ見つかれば、そこで止める）。
    var far = 0, best = -1.0;
    for (var i = 0; i < count; i++) {
      final d = _d2(i, mr, mg, mb);
      if (d > best) {
        best = d;
        far = i;
      }
    }
    final fr = r[far], fg = g[far], fb = b[far];
    var oneArea = true;
    for (var i = 0; i < count; i++) {
      if (_d2(i, fr, fg, fb) > _spread * _spread) {
        oneArea = false;
        break;
      }
    }
    if (oneArea) return _nearest(mr, mg, mb);
    // 同じ色の画素をまとめる。広い3色でドットの半分に満たなければ、面では
    // ない：平均。
    final total = _distinct();
    final runs = _runs;
    var top1 = 0.0, top2 = 0.0, top3 = 0.0;
    for (var k = 0; k < runs; k++) {
      final v = _runArea[k];
      if (v > top1) {
        top3 = top2;
        top2 = top1;
        top1 = v;
      } else if (v > top2) {
        top3 = top2;
        top2 = v;
      } else if (v > top3) {
        top3 = v;
      }
    }
    if (top1 + top2 + top3 < _pureEnough * total) {
      return _nearest(mr, mg, mb);
    }
    // まとまりの種は広い面の色：いちばん広い色、それから「広さ×ほかの種
    // からの距離」が最も大きい色（アンチエイリアスの画素は1つずつ色が
    // 違って狭いので、種にならない）。
    var s1 = 0;
    for (var k = 1; k < runs; k++) {
      if (_runArea[k] > _runArea[s1]) s1 = k;
    }
    final s2 = _seed(s1, -1);
    if (s2 < 0) return _nearest(mr, mg, mb);
    final s3 = _seed(s1, s2);
    final k = s3 < 0 ? 2 : 3;
    final cr = _cr, cg = _cg, cb = _cb, ca = _ca;
    for (var j = 0; j < k; j++) {
      final i = _runFirst[j == 0 ? s1 : (j == 1 ? s2 : s3)];
      cr[j] = r[i];
      cg[j] = g[i];
      cb[j] = b[i];
    }
    // 色ごとのまとまりを、近い種の面へ（不透明度で重み付けした色の平均で
    // 1回だけ直す：種が広い面の色なので、ほぼ決まっている）。
    _assign(k);
    _centres(k);
    _assign(k);
    _centres(k);
    final alive = _alive
      ..[0] = ca[0] > 0
      ..[1] = ca[1] > 0
      ..[2] = k == 3 && ca[2] > 0;
    // 2つの面の色を結ぶ線の上にあるまとまりは、その間のアンチエイリアス：
    // 近い方の面へ入れる。
    if (k == 3 && alive[0] && alive[1] && alive[2]) {
      for (var j = 0; j < 3; j++) {
        final aj = (j + 1) % 3, bj = (j + 2) % 3;
        final ex = cr[bj] - cr[aj], ey = cg[bj] - cg[aj], ez = cb[bj] - cb[aj];
        final length2 = ex * ex + ey * ey + ez * ez;
        if (length2 < 1e-9) continue;
        final t =
            ((cr[j] - cr[aj]) * ex +
                (cg[j] - cg[aj]) * ey +
                (cb[j] - cb[aj]) * ez) /
            length2;
        if (t < 0.1 || t > 0.9) continue;
        final ox = cr[aj] + ex * t - cr[j],
            oy = cg[aj] + ey * t - cg[j],
            oz = cb[aj] + ez * t - cb[j];
        final off = math.sqrt(ox * ox + oy * oy + oz * oz);
        if (off > math.max(8, 0.1 * math.sqrt(length2))) continue;
        for (var q = 0; q < runs; q++) {
          if (_runGroup[q] != j) continue;
          final i = _runFirst[q];
          _runGroup[q] =
              _d2(i, cr[aj], cg[aj], cb[aj]) <= _d2(i, cr[bj], cg[bj], cb[bj])
              ? aj
              : bj;
        }
        alive[j] = false;
        _centres(k);
        break;
      }
    }
    // まとまりの色が近い（同じ面の質感・グラデーション）なら平均。
    var spanAll = 0.0;
    for (var j = 0; j < k; j++) {
      for (var l = j + 1; l < k; l++) {
        if (!alive[j] || !alive[l]) continue;
        final dx = cr[j] - cr[l], dy = cg[j] - cg[l], dz = cb[j] - cb[l];
        spanAll = math.max(spanAll, math.sqrt(dx * dx + dy * dy + dz * dz));
      }
    }
    if (spanAll < _apartAreas) return _nearest(mr, mg, mb);
    // 面の色（まとまりの色の近く）がドットの半分以上を占めるときだけ、
    // 面の色にする。
    final near = math.max(_spread, _pureShare * spanAll);
    var pure = 0.0;
    final share = _share..fillRange(0, 3, 0);
    for (var q = 0; q < runs; q++) {
      final j = _runGroup[q], i = _runFirst[q];
      share[j] += _runShare[q];
      if (_d2(i, cr[j], cg[j], cb[j]) <= near * near) pure += _runArea[q];
    }
    if (pure < _pureEnough * total) return _nearest(mr, mg, mb);
    // どのまとまりの色も隣のドットへ続く（隣のドットがほぼその色1色）なら、
    // 大きな面どうしの境目や角：広い方の面（細部の重みで選ぶと、面の角が
    // 1ドット外へ出た）。隣に無い色（目・口・ドットを通る線）があれば、
    // 細部の重み（の2乗）の大きい方。
    var continuing = true;
    final cx = c % cellsX, cy = c ~/ cellsX;
    for (var j = 0; j < k && continuing; j++) {
      if (!alive[j]) continue;
      var found = false;
      for (var o = 0; o < 9 && !found; o++) {
        final nx = cx + o % 3 - 1, ny = cy + o ~/ 3 - 1;
        if (o == 4 || nx < 0 || ny < 0 || nx >= cellsX || ny >= cellsY) {
          continue;
        }
        final colour = raw[ny * cellsX + nx];
        if (colour == null) continue;
        final dr = ((colour >> 16) & 0xff) - cr[j],
            dg = ((colour >> 8) & 0xff) - cg[j],
            db = (colour & 0xff) - cb[j];
        if (dr * dr + dg * dg + db * db <= _sameArea * _sameArea) {
          found = true;
        }
      }
      continuing = found;
    }
    final score = continuing ? ca : share;
    var pick = -1;
    for (var j = 0; j < k; j++) {
      if (!alive[j]) continue;
      if (pick < 0 || score[j] > score[pick]) pick = j;
    }
    // その面の色：その面でいちばん広い色（なるべく不透明な画素の）。
    var mode = -1, modeOpaque = false;
    for (var q = 0; q < runs; q++) {
      if (_runGroup[q] != pick) continue;
      final opaque = a[_runFirst[q]] >= 128;
      if (mode < 0 ||
          (opaque && !modeOpaque) ||
          (opaque == modeOpaque && _runArea[q] > _runArea[mode])) {
        mode = q;
        modeOpaque = opaque;
      }
    }
    return _colourOf(_runFirst[mode]);
  }

  /// 種のまとまり[a1]（と[a2]）から色が離れたまとまりのうち、「広さ×種から
  /// の距離」が最も大きいもの（無ければ-1）。
  int _seed(int a1, int a2) {
    var top = 0.0, at = -1;
    final f1 = _runFirst[a1], f2 = a2 < 0 ? -1 : _runFirst[a2];
    for (var k = 0; k < _runs; k++) {
      final i = _runFirst[k];
      var near = _d2(i, r[f1], g[f1], b[f1]);
      if (f2 >= 0) near = math.min(near, _d2(i, r[f2], g[f2], b[f2]));
      if (near <= _spread * _spread) continue;
      final score = _runArea[k] * math.sqrt(near);
      if (score > top) {
        top = score;
        at = k;
      }
    }
    return at;
  }

  /// 同じ色の画素をまとめ（[_runs]個）、画素の不透明度の合計を返す。
  double _distinct() {
    final n = count, mask = _mask;
    final keys = _slotKey, slotRun = _slotRun;
    var runs = 0;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      final key = _key[i];
      var slot = (key * 0x9E3779B1) >> 7 & mask;
      int run;
      while (true) {
        final k = keys[slot];
        if (k == key) {
          run = slotRun[slot];
          break;
        }
        if (k < 0) {
          keys[slot] = key;
          run = slotRun[slot] = runs++;
          _runSlot[run] = slot;
          _runFirst[run] = i;
          _runArea[run] = 0;
          _runShare[run] = 0;
          break;
        }
        slot = (slot + 1) & mask;
      }
      final t = a[i].toDouble();
      _runArea[run] += t;
      _runShare[run] += w[i] * w[i] / (t < 1 ? 1 : t);
      total += t;
    }
    for (var k = 0; k < runs; k++) {
      keys[_runSlot[k]] = -1;
    }
    _runs = runs;
    return total;
  }

  /// 色ごとのまとまりを、近い面の色のまとまりへ。
  void _assign(int k) {
    final cr = _cr, cg = _cg, cb = _cb;
    for (var q = 0; q < _runs; q++) {
      final i = _runFirst[q];
      var bestJ = 0, best = _d2(i, cr[0], cg[0], cb[0]);
      for (var j = 1; j < k; j++) {
        final d = _d2(i, cr[j], cg[j], cb[j]);
        if (d < best) {
          best = d;
          bestJ = j;
        }
      }
      _runGroup[q] = bestJ;
    }
  }

  /// 面のまとまりごとの不透明度で重み付けした色の平均（[_cr]・[_cg]・
  /// [_cb]）と不透明度の合計（[_ca]）。
  void _centres(int k) {
    final cr = _cr, cg = _cg, cb = _cb, ca = _ca;
    final sr = _sr..fillRange(0, 3, 0),
        sg = _sg..fillRange(0, 3, 0),
        sb = _sb..fillRange(0, 3, 0);
    ca.fillRange(0, 3, 0);
    for (var q = 0; q < _runs; q++) {
      final j = _runGroup[q], i = _runFirst[q], t = _runArea[q];
      sr[j] += r[i] * t;
      sg[j] += g[i] * t;
      sb[j] += b[i] * t;
      ca[j] += t;
    }
    for (var j = 0; j < k; j++) {
      if (ca[j] == 0) continue;
      cr[j] = sr[j] / ca[j];
      cg[j] = sg[j] / ca[j];
      cb[j] = sb[j] / ca[j];
    }
  }

  final _cr = Float64List(3), _cg = Float64List(3), _cb = Float64List(3);
  final _ca = Float64List(3), _share = Float64List(3);
  final _sr = Float64List(3), _sg = Float64List(3), _sb = Float64List(3);
  final _alive = List<bool>.filled(3, false);

  int _colourOf(int i) =>
      0xff000000 |
      r[i].round().clamp(0, 255) << 16 |
      g[i].round().clamp(0, 255) << 8 |
      b[i].round().clamp(0, 255);

  /// ([x], [y], [z])に最も近い、実際にある画素の色（なるべく不透明な
  /// 画素から）。
  int _nearest(double x, double y, double z) {
    var pick = -1, best = double.infinity;
    var faint = -1, faintBest = double.infinity;
    for (var i = 0; i < count; i++) {
      final d = _d2(i, x, y, z);
      if (a[i] >= 128) {
        if (d < best) {
          best = d;
          pick = i;
        }
      } else if (d < faintBest) {
        faintBest = d;
        faint = i;
      }
    }
    return _colourOf(pick < 0 ? faint : pick);
  }
}

/// For each colour, how 16 dots of a limited set of colours (up to three of
/// them) look nearest to it side by side (ordered dithering, after
/// Yliluoma), or the one colour when no mix looks clearly nearer. Mixing is
/// in linear light (as the eye averages neighbouring dots); nearness is how
/// different the colours look (CIELAB). Three colours are allowed because
/// two cannot make many colours at all (a light skin from white, yellow and
/// red); each mix also costs by how much its dots stand out from each other
/// (their spread in lightness counting most, as the eye sees a pattern of
/// light and dark far more than one of hues), so a light sky is not turned
/// into a black-and-white checker for a slightly nearer grey.
class _Ditherer {
  _Ditherer(List<int> palette)
    : _colors = [for (final c in palette.toSet()) 0xff000000 | c] {
    for (final c in _colors) {
      _linear.add(
        Float64List.fromList([
          _toLinear((c >> 16) & 0xff),
          _toLinear((c >> 8) & 0xff),
          _toLinear(c & 0xff),
        ]),
      );
      _labs.add(PixelArtEngine._lab(c));
    }
  }

  /// How many of the nearest colours a mix is made from.
  static const _candidates = 6;

  /// What a mix costs per unit of its dots' spread (variance) in lightness
  /// and in hue and colourfulness (CIELAB a and b).
  static const _lightSpread = 0.15, _hueSpread = 0.08;

  /// A mix is used only when it looks at most this share as different from
  /// the colour wanted as the nearest single colour does: a small gain is not
  /// worth dots of another colour, which show up as specks. The further off
  /// the nearest colour is (in CIELAB), the readier a mix is taken: from
  /// [_closeRatio] where it is [_close] away to [_farRatio] from [_far].
  static const _closeRatio = 0.5, _farRatio = 0.8;
  static const double _close = 15, _far = 30;

  /// A colour this near (CIELAB) to one of the set is that colour: dots of
  /// another colour would only freckle it.
  static const double _enough = 10;

  /// The largest squared share of [single] (squared) a mix may keep.
  static double _gain(double single) {
    final t = ((math.sqrt(single) - _close) / (_far - _close)).clamp(0.0, 1.0);
    final ratio = _closeRatio + (_farRatio - _closeRatio) * t;
    return ratio * ratio;
  }

  final List<int> _colors;
  final _linear = <Float64List>[];
  final _labs = <Float64List>[];
  final _cache = <int, Int32List>{};

  /// CIELAB of an sRGB colour.
  static Float64List labOf(int color) => _labOfLinear(
    _toLinear((color >> 16) & 0xff),
    _toLinear((color >> 8) & 0xff),
    _toLinear(color & 0xff),
  );

  /// [labOf]を[out]の[at]〜[at] + 2へ（同じ計算、配列を作らない）。
  static void labInto(int color, Float64List out, int at) {
    final r = _toLinear((color >> 16) & 0xff),
        g = _toLinear((color >> 8) & 0xff),
        b = _toLinear(color & 0xff);
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    final fx = x > 216 / 24389 ? _cubeRoot(x) : (24389 / 27 * x + 16) / 116;
    final fy = y > 216 / 24389 ? _cubeRoot(y) : (24389 / 27 * y + 16) / 116;
    final fz = z > 216 / 24389 ? _cubeRoot(z) : (24389 / 27 * z + 16) / 116;
    out[at] = 116 * fy - 16;
    out[at + 1] = 500 * (fx - fy);
    out[at + 2] = 200 * (fy - fz);
  }

  /// The colour of the set that looks nearest to [color].
  int nearest(int color) {
    final lab = labOf(color);
    var best = 0;
    var bestDistance = double.infinity;
    for (var k = 0; k < _labs.length; k++) {
      final l = _labs[k];
      final dl = l[0] - lab[0], da = l[1] - lab[1], db = l[2] - lab[2];
      final d = dl * dl + da * da + db * db;
      if (d < bestDistance) {
        bestDistance = d;
        best = k;
      }
    }
    return _colors[best];
  }

  /// The 16 colours of the mix for [color], darkest first (all the same
  /// when it is not mixed). Colours a step of 4 apart share a mix: no mix
  /// can tell them apart.
  Int32List planFor(int color) {
    final key = (color >> 2) & 0x3f3f3f;
    final cached = _cache[key];
    if (cached != null) return cached;
    final rgb = color & 0xffffff;
    final lr = _toLinear((rgb >> 16) & 0xff),
        lg = _toLinear((rgb >> 8) & 0xff),
        lb = _toLinear(rgb & 0xff);
    final lab = _labOfLinear(lr, lg, lb);
    double distance(Float64List x) {
      final dl = x[0] - lab[0], da = x[1] - lab[1], db = x[2] - lab[2];
      return dl * dl + da * da + db * db;
    }

    // The nearest few colours, nearest first.
    final near = <int>[];
    final nearDistance = <double>[];
    for (var k = 0; k < _colors.length; k++) {
      final d = distance(_labs[k]);
      if (near.length == _candidates && d >= nearDistance.last) continue;
      var at = near.length;
      while (at > 0 && nearDistance[at - 1] > d) {
        at--;
      }
      near.insert(at, k);
      nearDistance.insert(at, d);
      if (near.length > _candidates) {
        near.removeLast();
        nearDistance.removeLast();
      }
    }
    final single = nearDistance.first;
    final gain = _gain(single);
    var best = <int, int>{near.first: 16};
    var bestCost = single;
    if (single <= _enough * _enough) near.length = 1;

    // How far the mix of [counts] dots of [colours] (16 in all) looks from
    // the colour wanted.
    double off(List<int> colours, List<int> counts) {
      var r = 0.0, g = 0.0, b = 0.0;
      for (var k = 0; k < colours.length; k++) {
        final c = _linear[colours[k]], n = counts[k];
        r += c[0] * n;
        g += c[1] * n;
        b += c[2] * n;
      }
      return _distanceOfLinear(r / 16, g / 16, b / 16, lab);
    }

    // From [start] (counts for one set of colours), move one dot at a time
    // from one colour to another while that brings the mix nearer; then the
    // mix is weighed against the best so far, with what its pattern costs
    // (left out of choosing the counts, where it would pull every mix
    // towards fewer dots of the odd colour).
    void consider(List<int> colours, List<int> start) {
      final counts = List<int>.of(start);
      for (var k = 0; k < counts.length; k++) {
        if (counts[k] < 1) counts[k] = 1;
      }
      var total = counts.fold(0, (a, b) => a + b);
      // Back to 16 dots, from or to the largest share.
      while (total != 16) {
        var k = 0;
        for (var i = 1; i < counts.length; i++) {
          if (counts[i] > counts[k]) k = i;
        }
        if (total > 16 && counts[k] <= 1) return;
        counts[k] += total > 16 ? -1 : 1;
        total += total > 16 ? -1 : 1;
      }
      var nearestOff = off(colours, counts);
      for (var step = 0; step < 16; step++) {
        var moved = false;
        var bestFrom = -1, bestTo = -1;
        var bestOff = nearestOff;
        for (var from = 0; from < counts.length; from++) {
          if (counts[from] <= 1) continue;
          for (var to = 0; to < counts.length; to++) {
            if (to == from) continue;
            counts[from]--;
            counts[to]++;
            final o = off(colours, counts);
            counts[from]++;
            counts[to]--;
            if (o < bestOff) {
              bestOff = o;
              bestFrom = from;
              bestTo = to;
              moved = true;
            }
          }
        }
        if (!moved) break;
        counts[bestFrom]--;
        counts[bestTo]++;
        nearestOff = bestOff;
      }
      if (nearestOff > single * gain) return;
      var l = 0.0, a = 0.0, bb = 0.0;
      for (var k = 0; k < colours.length; k++) {
        final x = _labs[colours[k]], n = counts[k];
        l += x[0] * n;
        a += x[1] * n;
        bb += x[2] * n;
      }
      l /= 16;
      a /= 16;
      bb /= 16;
      var light = 0.0, hue = 0.0;
      for (var k = 0; k < colours.length; k++) {
        final x = _labs[colours[k]], n = counts[k];
        light += n * (x[0] - l) * (x[0] - l);
        hue += n * ((x[1] - a) * (x[1] - a) + (x[2] - bb) * (x[2] - bb));
      }
      final cost = nearestOff + (_lightSpread * light + _hueSpread * hue) / 16;
      if (cost < bestCost) {
        bestCost = cost;
        best = {for (var k = 0; k < colours.length; k++) colours[k]: counts[k]};
      }
    }

    for (var i = 0; i < near.length; i++) {
      for (var j = i + 1; j < near.length; j++) {
        final p = near[i], q = near[j];
        final a = _linear[p], b = _linear[q];
        final dr = b[0] - a[0], dg = b[1] - a[1], db = b[2] - a[2];
        final length = dr * dr + dg * dg + db * db;
        if (length == 0) continue;
        final t =
            ((lr - a[0]) * dr + (lg - a[1]) * dg + (lb - a[2]) * db) / length;
        final n = (t * 16).round();
        consider([p, q], [16 - n, n]);
        for (var k = j + 1; k < near.length; k++) {
          // Least squares in linear light for the shares of the three (they
          // add up to one), as a start.
          final c = _linear[near[k]];
          final ux = a[0] - c[0], uy = a[1] - c[1], uz = a[2] - c[2];
          final vx = b[0] - c[0], vy = b[1] - c[1], vz = b[2] - c[2];
          final wx = lr - c[0], wy = lg - c[1], wz = lb - c[2];
          final uu = ux * ux + uy * uy + uz * uz;
          final uv = ux * vx + uy * vy + uz * vz;
          final vv = vx * vx + vy * vy + vz * vz;
          final uw = ux * wx + uy * wy + uz * wz;
          final vw = vx * wx + vy * wy + vz * wz;
          final det = uu * vv - uv * uv;
          if (det.abs() < 1e-12) continue;
          final sa = (uw * vv - vw * uv) / det, sb = (vw * uu - uw * uv) / det;
          final na = (sa * 16).round().clamp(1, 14);
          final nb = (sb * 16).round().clamp(1, 14);
          consider([p, q, near[k]], [na, nb, 16 - na - nb]);
        }
      }
    }

    final plan = Int32List(16);
    final order = best.keys.toList()
      ..sort((p, q) => _labs[p][0].compareTo(_labs[q][0]));
    var at = 0;
    for (final k in order) {
      for (var n = 0; n < best[k]!; n++) {
        plan[at++] = _colors[k];
      }
    }
    if (_cache.length >= 1 << 16) _cache.clear();
    return _cache[key] = plan;
  }

  /// sRGB channel values in linear light.
  static final Float64List _linearOf = Float64List.fromList([
    for (var c = 0; c < 256; c++)
      c / 255 <= 0.04045
          ? c / 255 / 12.92
          : math.pow((c / 255 + 0.055) / 1.055, 2.4).toDouble(),
  ]);

  static double _toLinear(int c) => _linearOf[c];

  /// Cube roots over 0..1, for the CIELAB conversion of every mix tried:
  /// read between entries, they are good to a millionth.
  static const _rootSteps = 4096;
  static final Float64List _roots = Float64List.fromList([
    for (var k = 0; k <= _rootSteps; k++)
      math.pow(k / _rootSteps, 1 / 3).toDouble(),
  ]);

  static double _cubeRoot(double t) {
    if (t >= 1) return math.pow(t, 1 / 3).toDouble();
    final x = t * _rootSteps;
    final k = x.floor();
    final f = x - k;
    return _roots[k] * (1 - f) + _roots[k + 1] * f;
  }

  /// How different linear-light colour ([r], [g], [b]) looks from [lab]:
  /// the squared CIELAB distance, worked out without building the colour.
  static double _distanceOfLinear(
    double r,
    double g,
    double b,
    Float64List lab,
  ) {
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    const e = 216 / 24389, k = 24389 / 27;
    final fx = x > e ? _cubeRoot(x) : (k * x + 16) / 116;
    final fy = y > e ? _cubeRoot(y) : (k * y + 16) / 116;
    final fz = z > e ? _cubeRoot(z) : (k * z + 16) / 116;
    final dl = 116 * fy - 16 - lab[0],
        da = 500 * (fx - fy) - lab[1],
        db = 200 * (fy - fz) - lab[2];
    return dl * dl + da * da + db * db;
  }

  static Float64List _labOfLinear(double r, double g, double b) {
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    double f(double t) =>
        t > 216 / 24389 ? _cubeRoot(t) : (24389 / 27 * t + 16) / 116;
    final fx = f(x), fy = f(y), fz = f(z);
    return Float64List.fromList([
      116 * fy - 16,
      500 * (fx - fy),
      200 * (fy - fz),
    ]);
  }
}
