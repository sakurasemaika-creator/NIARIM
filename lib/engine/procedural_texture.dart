import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/stamp.dart';
import '../models/tone.dart';
import '../utils/creative_image_source.dart';
import 'filter_engine.dart';
import 'texture_silhouette.dart';

/// 画像ファイルを読み込み、size×sizeのRGBAバイト列にデコードする。
/// 失敗した場合はnullを返す。
Future<Uint8List?> _loadImageRgba(
  String path,
  int size, {
  ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba,
}) async {
  try {
    final bytes = await readCreativeImageSource(path);
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final byteData = await frame.image.toByteData(format: format);
    frame.image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// トーン画像では暗さと元の透明度からインクのalphaを作る。
Uint8List _toToneAlphaMask(Uint8List rgba, {required bool pixelMode}) {
  final out = Uint8List(rgba.length);
  for (int i = 0; i < rgba.length; i += 4) {
    final luminance =
        rgba[i] * 0.299 + rgba[i + 1] * 0.587 + rgba[i + 2] * 0.114;
    final ink = ((255 - luminance) * rgba[i + 3] / 255).round();
    out[i + 3] = pixelMode ? (ink >= 128 ? 255 : 0) : ink.clamp(0, 255);
  }
  return out;
}

/// トーン画像のデコード結果キャッシュ（`texturePath#size#pixelMode`をキーにする）。
/// バケツ塗りのドラッグ中（_bucketFillAt）は同期処理のため、事前に
/// [ensureToneTextureLoaded] で読み込みを済ませておく必要がある。
final Map<String, Uint8List> _toneImageCache = {};

String _toneCacheKey(String path, int size, bool pixelMode) =>
    '$path#$size#$pixelMode';

/// トーンの1タイルの既定の大きさ（px）。
const int defaultToneTileSize = 64;

/// 組み込みのトーンの画像（`assets/tones/<id>.png`）のうち、模様の繰り返しの
/// 間隔が64pxで割り切れないため、間隔の倍数の大きさで作ってあるもの（紙・布の
/// 質感は、繰り返しが目立たないよう64pxより大きな間隔で作ってある）。
/// 64pxのタイルに間隔6pxの線を並べると、タイルの継ぎ目だけ間隔が4pxになり、
/// 並べたトーンに64pxごとの筋が出る。値は[toneTileSizeForPattern]と同じ。
const Map<String, int> builtInToneTileSizes = {
  'Tone0005': 66,
  'Tone0006': 66,
  'Tone0010': 66,
  'Tone0012': 65,
  'Tone0013': 66,
  'Tone0015': 70,
  'Tone0031': 66,
  'Tone0032': 66,
  'Tone0033': 66,
  'Tone0034': 66,
  'Tone0035': 70,
  'Tone0036': 70,
  'Tone0037': 70,
  'Tone0038': 70,
  'Tone0039': 70,
  'Tone0042': 66,
  'Tone0050': 66,
  'Tone0066': 128,
  'Tone0067': 128,
  'Tone0068': 96,
  'Tone0070': 112,
  'Tone0071': 72,
  'Tone0072': 112,
  'Tone0074': 72,
};

final RegExp _builtInTonePath = RegExp(r'^assets/tones/(Tone\d+)\.png$');

/// [tone]を貼るときの1タイルの大きさ（px）。トーンの模様はこの大きさで
/// 繰り返すので、継ぎ目で模様が途切れない。組み込みの画像と名前から作る模様は
/// 模様の間隔の倍数、利用者の画像は[defaultToneTileSize]。
int toneTileSize(Tone tone) {
  final path = tone.texturePath;
  if (path == null) {
    return toneTileSizeForPattern(tone.patternName ?? tone.name);
  }
  final builtIn = _builtInTonePath.firstMatch(path);
  if (builtIn != null) {
    return builtInToneTileSizes[builtIn.group(1)] ?? defaultToneTileSize;
  }
  return defaultToneTileSize;
}

/// 名前から作る模様の1タイルの大きさ：[defaultToneTileSize]以上で、模様の
/// 繰り返しの間隔で割り切れる最小の大きさ。
int toneTileSizeForPattern(String name) {
  final period = _tonePatternFor(name).period;
  return (defaultToneTileSize / period).ceil() * period;
}

/// [tone.texturePath] が指す画像を事前読み込みし、キャッシュへ格納する。
/// トーンを使った描画（投げ縄塗り・トーン自由描画・バケツ塗り等）の
/// 開始前に呼び出しておくことで、[generateBuiltInToneTexture] の同期呼び出し
/// でも自作画像を反映できるようにする。[size]を省くと[toneTileSize]。
Future<void> ensureToneTextureLoaded(Tone tone, {int? size}) async {
  final path = tone.texturePath;
  if (path == null) return;
  final tile = size ?? toneTileSize(tone);
  final key = _toneCacheKey(path, tile, tone.pixelMode);
  if (_toneImageCache.containsKey(key)) return;
  final rgba = await _loadImageRgba(
    path,
    tile,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (rgba != null) {
    _toneImageCache[key] = _toToneAlphaMask(rgba, pixelMode: tone.pixelMode);
  }
}

/// 事前読み込みした画像のパターンを返す。旧データに画像がない場合や
/// 画像が読めない場合は名前から代替パターンを生成する。[size]を省くと
/// [toneTileSize]（模様が継ぎ目でつながる大きさ）。
Uint8List generateBuiltInToneTexture(Tone tone, {int? size}) {
  final tile = size ?? toneTileSize(tone);
  final path = tone.texturePath;
  if (path != null) {
    final cached = _toneImageCache[_toneCacheKey(path, tile, tone.pixelMode)];
    if (cached != null) return cached;
  }
  final name = tone.patternName ?? tone.name;
  // Patterns with antialiased edges take a few milliseconds to compute and
  // the bucket asks again for every position it fills during a drag.
  return _tonePatternCache['$name#$tile'] ??= () {
    final data = Uint8List(tile * tile * 4);
    _tonePatternFor(name).fill(data, tile);
    return data;
  }();
}

/// 名前から作った模様（`名前#大きさ`をキーにする）。返した配列は書き換えない
/// こと（画像のキャッシュと同じ）。
final Map<String, Uint8List> _tonePatternCache = {};

/// 名前から作る模様：繰り返しの間隔（px、縦横とも）と塗り方。
typedef _TonePattern = ({int period, void Function(Uint8List, int) fill});

_TonePattern _tonePatternFor(String name) {
  // 名前で分岐する都合上、**判定の順序が仕様**になっている点に注意。
  // 「ピクセルディザ」は「ピクセル」を含み、「ピクセル格子」は「格子」を
  // 含む、といった包含関係があるため、より限定的な名前から先に判定する。
  // 新しいトーンを足すときは、既存の判定語（網点・ライン・市松・格子・
  // 散らし・砂目・レンガ・方眼・クロスハッチ等）を部分文字列として
  // 含まない名前にするか、この並びの適切な位置へ差し込むこと。
  // 紙・布の質感と和柄・布柄は先に判定する。
  final surface = _surfacePatternFor(name);
  if (surface != null) return surface;
  if (name.contains('ピクセルディザ')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '50') ??
        50;
    final coarse = name.contains('粗');
    final fine = name.contains('細');
    return (
      period: coarse ? 4 : (fine ? 8 : 4),
      fill: (data, size) => _fillPixelDitherPattern(
        data,
        size,
        percent / 100.0,
        coarse: coarse,
        fine: fine,
      ),
    );
  } else if (name.contains('ピクセル砂目')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '50') ??
        50;
    return (
      period: 1,
      fill: (data, size) =>
          _fillNoisePattern(data, size, percent / 100.0, cell: 1),
    );
  } else if (name.contains('ピクセルレンガ')) {
    return (
      period: 8,
      fill: (data, size) =>
          _fillBrickPattern(data, size, unit: 4, thickness: 1),
    );
  } else if (name.contains('ピクセル') &&
      (name.contains('縞') || name.contains('ストライプ') || name.contains('ボーダー'))) {
    final diagonal = name.contains('斜め');
    // 斜めだけ間隔3にする。間隔2の斜め1px線は「(x+y)が偶数」という
    // 条件そのもので、市松模様と1画素も違わなくなってしまうため。
    final spacing = diagonal ? 3 : 2;
    return (
      period: spacing,
      fill: (data, size) => _fillStripePattern(
        data,
        size,
        spacing: spacing,
        thickness: 1,
        direction: diagonal
            ? _StripeDirection.diagonal
            : name.contains('縦')
            ? _StripeDirection.vertical
            : _StripeDirection.horizontal,
      ),
    );
  } else if (name.contains('ピクセル斜め格子')) {
    // Genuine 1px diagonal crosshatch with diamond-shaped transparent holes.
    // A period of two degenerates into checkerboard, hence period four.
    return (period: 4, fill: _fillPixelDiagonalMeshPattern);
  } else if (name.contains('市松')) {
    // Reverse is the exact inverse mask, not a second generic 30% halftone.
    final inverted = name.contains('反転');
    return (
      period: 2,
      fill: (data, size) =>
          _fillPixelCheckerPattern(data, size, inverted: inverted),
    );
  } else if (name.contains('格子')) {
    final inverted = name.contains('反転');
    return (
      period: 2,
      fill: (data, size) =>
          _fillPixelGridPattern(data, size, inverted: inverted),
    );
  } else if (name.contains('散らし')) {
    // ピクセルモード用：1ピクセルの点を上下左右1pxずつ空けて独立配置。
    // 市松（斜めに隣接）・格子（縦横の線がつながる）とは異なり、
    // どの点も上下左右の隣接ピクセルとは接しない。
    return (period: 2, fill: _fillPixelScatteredDotPattern);
  } else if (name.contains('ストッキング') || name.contains('タイツ')) {
    final denier =
        int.tryParse(RegExp(r'(\d+)デニール').firstMatch(name)?.group(1) ?? '20') ??
        20;
    return (
      period: _stockingMeshSpacing(denier),
      fill: (data, size) => _fillStockingMeshPattern(data, size, denier),
    );
  } else if (name.contains('砂目')) {
    // アナログの砂目トーン相当。粒を数px単位のまとまりにすることで、
    // 1px単位の「ピクセル砂目」より粗くざらついた質感になる。
    final cell = name.contains('粗')
        ? 3
        : name.contains('細')
        ? 1
        : 2;
    return (
      period: cell,
      fill: (data, size) => _fillNoisePattern(data, size, 0.42, cell: cell),
    );
  } else if (name.contains('同心円')) {
    return (period: 2, fill: _fillConcentricCirclePattern);
  } else if (name.contains('波線')) {
    return (period: _wavePeriod, fill: _fillWavePattern);
  } else if (name.contains('レンガ')) {
    return (
      period: 32,
      fill: (data, size) =>
          _fillBrickPattern(data, size, unit: 16, thickness: 2),
    );
  } else if (name.contains('方眼')) {
    final thickness = name.contains('太') ? 2 : 1;
    return (
      period: 8,
      fill: (data, size) =>
          _fillGridPattern(data, size, spacing: 8, thickness: thickness),
    );
  } else if (name.contains('クロスハッチ')) {
    final thickness = name.contains('太')
        ? 3
        : name.contains('細')
        ? 1
        : 2;
    final diagonal = name.contains('斜め');
    return (
      period: _crossHatchSpacing,
      fill: (data, size) => _fillCrossHatchPattern(
        data,
        size,
        thickness: thickness,
        diagonal: diagonal,
      ),
    );
  } else if (name.contains('ライン')) {
    final thickness = name.contains('太') ? 3 : 1;
    final direction = name.contains('縦')
        ? _StripeDirection.vertical
        : name.contains('斜め')
        ? _StripeDirection.diagonal
        : _StripeDirection.horizontal;
    return (
      period: 6,
      fill: (data, size) => _fillStripePattern(
        data,
        size,
        spacing: 6,
        thickness: thickness,
        direction: direction,
      ),
    );
  } else if (name.contains('網点')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '30') ??
        30;
    return (
      period: _dotCell,
      fill: (data, size) => _fillDotPattern(data, size, percent / 100.0),
    );
  }
  return (
    period: _dotCell,
    fill: (data, size) => _fillDotPattern(data, size, 0.3),
  );
}

/// 紙・布の質感（大きなタイルで繰り返す、濃淡のある模様）と、和柄・布柄。
/// どれも縦横とも[period]pxで繰り返すように作ってある。
_TonePattern? _surfacePatternFor(String name) {
  if (name.contains('水彩紙')) {
    return (period: _paperPeriod, fill: _fillWatercolourPaper);
  } else if (name.contains('画用紙')) {
    return (period: _paperPeriod, fill: _fillDrawingPaper);
  } else if (name.contains('キャンバス地')) {
    return (period: _canvasPeriod, fill: _fillCanvasWeave);
  } else if (name.contains('青海波')) {
    return (period: _seigaihaPeriod, fill: _fillSeigaiha);
  } else if (name.contains('麻の葉')) {
    return (period: _asanohaPeriod, fill: _fillAsanoha);
  } else if (name.contains('輪つなぎ')) {
    return (period: _shippoPeriod, fill: _fillShippo);
  } else if (name.contains('うろこ')) {
    return (period: _urokoPeriod, fill: _fillUroko);
  } else if (name.contains('チェック柄')) {
    return (period: _ginghamPeriod, fill: _fillGingham);
  } else if (name.contains('ハウンドトゥース')) {
    return (period: _houndstoothPeriod, fill: _fillHoundstooth);
  }
  return null;
}

// ─── 紙・布の質感 ───────────────────────────────────────────────

/// 紙の質感の繰り返しの間隔（px）。64pxでは同じ凹凸の並びが目立つ。
const int _paperPeriod = 128;

/// キャンバス地の繰り返しの間隔（px）。織り目（12px）の倍数。
const int _canvasPeriod = 96;

/// 32bitの整数ハッシュ（座標と種から、いつも同じ値を返す）。
int _hash32(int x, int y, int seed) {
  var h = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xffffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff;
  return (h ^ (h >> 16)) & 0xffffffff;
}

/// [period]pxで繰り返すグラディエントノイズ（おおよそ-1〜1）。格子の間隔は
/// [cell]px（[period]は[cell]の倍数）。格子点の番号を[period]÷[cell]で回す
/// ので、タイルの右端と左端・下端と上端の値がつながる。
double _tileNoise(double x, double y, int cell, int period, int seed) {
  final n = period ~/ cell;
  final fx = x / cell, fy = y / cell;
  final ix = fx.floor(), iy = fy.floor();
  final tx = fx - ix, ty = fy - iy;
  double corner(int gx, int gy, double dx, double dy) {
    final h = _hash32(gx % n, gy % n, seed);
    final angle = h / 4294967296 * 2 * math.pi;
    return math.cos(angle) * dx + math.sin(angle) * dy;
  }

  double fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);
  final u = fade(tx), v = fade(ty);
  final a = corner(ix, iy, tx, ty);
  final b = corner(ix + 1, iy, tx - 1, ty);
  final c = corner(ix, iy + 1, tx, ty - 1);
  final d = corner(ix + 1, iy + 1, tx - 1, ty - 1);
  final top = a + (b - a) * u;
  final bottom = c + (d - c) * u;
  return (top + (bottom - top) * v) * 1.41;
}

/// 0〜1の値を[from]〜[to]でなめらかに0〜1へ移す。
double _smoothstep(double from, double to, double v) {
  final t = ((v - from) / (to - from)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// 凹凸の高さ[height]を左上から照らしたときの影の強さ（右下を向いた斜面ほど
/// 大きい）。紙の質感の写真を斜めの光で撮ったときと同じ見え方になり、
/// 塗った色に紙の凹凸の陰影が付く。
double _relief(double Function(double x, double y) height, double x, double y) {
  const d = 0.75;
  return height(x + d, y + d) - height(x - d, y - d);
}

/// 水彩紙（中目）：丸みのある大小の凸がうねるコットンの水彩紙の目。凸の
/// 影の側に色が乗る。
void _fillWatercolourPaper(Uint8List data, int size) {
  const p = _paperPeriod;
  double height(double x, double y) =>
      0.45 * (1 - _tileNoise(x, y, 16, p, 11).abs()) +
      0.35 * (1 - _tileNoise(x, y, 8, p, 12).abs()) +
      0.20 * (1 - _tileNoise(x, y, 4, p, 13).abs());
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      final shade = _relief(height, x + 0.5, y + 0.5);
      tile[y * p + x] = (_smoothstep(0.02, 0.26, shade) * 215).round();
    }
  }
  _repeat(data, size, tile, p, p);
}

/// 画用紙：水彩紙より細かくそろった浅い紙の目。
void _fillDrawingPaper(Uint8List data, int size) {
  const p = _paperPeriod;
  double height(double x, double y) =>
      0.55 * (1 - _tileNoise(x, y, 4, p, 21).abs()) +
      0.30 * _tileNoise(x, y, 2, p, 22) +
      0.15 * _tileNoise(x, y, 8, p, 23);
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      final shade = _relief(height, x + 0.5, y + 0.5);
      tile[y * p + x] = (_smoothstep(0.04, 0.4, shade) * 170).round();
    }
  }
  _repeat(data, size, tile, p, p);
}

/// キャンバス地（平織り）：縦糸と横糸が1本ずつ交互に上下になる。上に出た
/// 糸の丸い盛り上がりの影の側と、糸の間のくぼみに色が乗る。糸の太さと
/// 盛り上がりは少しずつ揃わない（織りむら）。
void _fillCanvasWeave(Uint8List data, int size) {
  const p = _canvasPeriod, pitch = 6;
  double height(double x, double y) {
    final i = (x / pitch).floor(), j = (y / pitch).floor();
    final warpUp = (i + j).isEven;
    // -1…1 across the thread on top, and along it.
    final across = ((warpUp ? x : y) % pitch) / pitch * 2 - 1;
    final along = ((warpUp ? y : x) % pitch) / pitch * 2 - 1;
    final slub =
        0.6 * _tileNoise(x, y, 12, p, 31) + 0.4 * _tileNoise(x, y, 6, p, 32);
    // A rounded crown that dips where the thread passes under the next.
    return math.cos(across * math.pi / 2) *
        (1 - 0.5 * along * along) *
        (0.85 + 0.2 * slub);
  }

  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      final px = x + 0.5, py = y + 0.5;
      final shade =
          0.7 * _smoothstep(0.0, 0.5, _relief(height, px, py)) +
          0.5 * _smoothstep(0.55, 0.05, height(px, py));
      tile[y * p + x] = (shade.clamp(0.0, 1.0) * 190).round();
    }
  }
  _repeat(data, size, tile, p, p);
}

// ─── 和柄・布柄 ────────────────────────────────────────────────

/// 線の太さ（px）。和柄の線は細い線で、なめらかな縁で描く。
const double _patternLine = 1.3;

const int _seigaihaRadius = 16;
const int _seigaihaPeriod = 64;

/// 青海波：半径の同じ扇（同心円の上半分）を、半径の2倍の間隔で並べ、
/// 行ごとに半径だけ横へずらして半径の半分ずつ重ねる。下の行の扇が前に来る。
void _fillSeigaiha(Uint8List data, int size) {
  const p = _seigaihaPeriod;
  const r = _seigaihaRadius * 1.0;
  const rows = r / 2; // vertical step between rows
  const rings = 4;
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      tile[y * p + x] = _coverage(x, y, (px, py) {
        // The front-most fan holding the point: rows nearer the bottom are
        // in front, so test the lowest candidate rows first.
        final row = (py / rows).floor();
        for (var j = row + 2; j >= row - 1; j--) {
          final cy = j * rows;
          final shift = j.isOdd ? r : 0.0;
          final i = ((px - shift) / (2 * r)).round();
          final cx = i * 2 * r + shift;
          final d = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
          if (d > r || py > cy) continue;
          // Concentric arcs, the outer one at the fan's edge.
          final ring = (r - d) / (r / rings);
          final nearest = ring.roundToDouble();
          return (ring - nearest).abs() * (r / rings) < _patternLine / 2 &&
              nearest < rings;
        }
        return false;
      });
    }
  }
  _repeat(data, size, tile, p, p);
}

/// 麻の葉の三角形の一辺（px）と、繰り返しの間隔。正三角形の高さ
/// 16×√3÷2＝13.9pxは14pxに丸める（縦へ1%伸びる。整数の間隔にしないと
/// タイルの継ぎ目で線がずれる）。
const int _asanohaSide = 16;
const int _asanohaHeight = 14;
const int _asanohaPeriod = 112;

/// 麻の葉：正三角形の格子の辺と、各三角形の重心から3つの頂点へ引いた線。
/// 6枚の菱形の葉が集まった星が並ぶ。
void _fillAsanoha(Uint8List data, int size) {
  const s = _asanohaSide * 1.0, h = _asanohaHeight * 1.0;
  // Segments around one lattice period (s × 2h): rows j = -1…2 and lattice
  // points i = -1…2, so a point of the period sees every line near it.
  final segments = <List<double>>[];
  for (var j = -1; j <= 2; j++) {
    final y0 = j * h, y1 = y0 + h;
    final top = j.isEven ? 0.0 : s / 2;
    for (var i = -1; i <= 2; i++) {
      final a = top + i * s;
      segments
        ..add([a, y0, a + s, y0])
        ..add([a, y0, a + s / 2, y1])
        ..add([a, y0, a - s / 2, y1]);
      // The triangle pointing down from this edge and the one pointing up
      // beside it: lines from the centroid to the three corners.
      for (final tri in [
        [a, y0, a + s, y0, a + s / 2, y1],
        [a + s / 2, y1, a + 1.5 * s, y1, a + s, y0],
      ]) {
        final cx = (tri[0] + tri[2] + tri[4]) / 3;
        final cy = (tri[1] + tri[3] + tri[5]) / 3;
        for (var k = 0; k < 6; k += 2) {
          segments.add([cx, cy, tri[k], tri[k + 1]]);
        }
      }
    }
  }
  const w = _asanohaSide, hh = 2 * _asanohaHeight;
  final tile = Uint8List(w * hh);
  for (var y = 0; y < hh; y++) {
    for (var x = 0; x < w; x++) {
      tile[y * w + x] = _coverage(x, y, (px, py) {
        for (final g in segments) {
          if (_segmentDistance(px, py, g) < _patternLine / 2) return true;
        }
        return false;
      });
    }
  }
  _repeat(data, size, tile, w, hh);
}

/// 点(px, py)から線分[g]（x0, y0, x1, y1）までの距離。
double _segmentDistance(double px, double py, List<double> g) {
  final dx = g[2] - g[0], dy = g[3] - g[1];
  final length = dx * dx + dy * dy;
  var t = length == 0 ? 0.0 : ((px - g[0]) * dx + (py - g[1]) * dy) / length;
  t = t.clamp(0.0, 1.0);
  final ex = g[0] + t * dx - px, ey = g[1] + t * dy - py;
  return math.sqrt(ex * ex + ey * ey);
}

const int _shippoRadius = 12;
const int _shippoPeriod = 2 * _shippoRadius;

/// 輪つなぎ（七宝つなぎ）：同じ大きさの円を、上下左右に接し斜めに重なるように並べる。重なった
/// 所が花びらの形になる。
void _fillShippo(Uint8List data, int size) {
  const p = _shippoPeriod;
  const r = _shippoRadius * 1.0;
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      tile[y * p + x] = _coverage(x, y, (px, py) {
        // Circles at the tile corners and at its centre.
        for (final (cx, cy) in [
          (0.0, 0.0),
          (2 * r, 0.0),
          (0.0, 2 * r),
          (2 * r, 2 * r),
          (r, r),
        ]) {
          final d = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
          if ((d - r).abs() < _patternLine / 2) return true;
        }
        return false;
      });
    }
  }
  _repeat(data, size, tile, p, p);
}

/// うろこの三角形の底辺と高さ（px、正三角形に近い14px）。
const int _urokoBase = 16;
const int _urokoHeight = 14;
const int _urokoPeriod = 112;

/// うろこ（鱗文様）：上向きの三角形を塗り、行ごとに半分ずらして敷き詰める（下向きの
/// 三角形は紙のまま）。
void _fillUroko(Uint8List data, int size) {
  const p = _urokoPeriod;
  const b = _urokoBase * 1.0, hgt = _urokoHeight * 1.0;
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      tile[y * p + x] = _coverage(x, y, (px, py) {
        final row = (py / hgt).floor();
        final shift = row.isOdd ? b / 2 : 0.0;
        // 0 at the base (bottom of the row), 1 at the apex.
        final up = 1 - (py - row * hgt) / hgt;
        final across = ((px - shift) % b) / b - 0.5;
        return across.abs() < (1 - up) / 2;
      });
    }
  }
  _repeat(data, size, tile, p, p);
}

const int _ginghamStripe = 8;
const int _ginghamPeriod = 2 * _ginghamStripe;

/// チェック柄（ギンガムチェック）：同じ幅の縦縞と横縞を重ねる。縞だけの所は半分の濃さ、
/// 縦縞と横縞が重なる所は全部の濃さ、どちらも無い所は紙。
void _fillGingham(Uint8List data, int size) {
  const p = _ginghamPeriod;
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      final vertical = x < _ginghamStripe ? 1 : 0;
      final horizontal = y < _ginghamStripe ? 1 : 0;
      tile[y * p + x] = const [0, 128, 255][vertical + horizontal];
    }
  }
  _repeat(data, size, tile, p, p);
}

const int _houndstoothCheck = 12;
const int _houndstoothPeriod = 2 * _houndstoothCheck;

/// ハウンドトゥース（千鳥格子）：市松の濃い升と淡い升の間の2つの升に、斜めの縞を入れる。縞が
/// 濃い升の角から伸びる歯になり、鳥の形がつながって並ぶ。
void _fillHoundstooth(Uint8List data, int size) {
  const p = _houndstoothPeriod;
  const c = _houndstoothCheck * 1.0;
  const stripe = c / 2;
  final tile = Uint8List(p * p);
  for (var y = 0; y < p; y++) {
    for (var x = 0; x < p; x++) {
      tile[y * p + x] = _coverage(x, y, (px, py) {
        final right = px >= c, lower = py >= c;
        if (!right && !lower) return true; // the dark check
        if (right && lower) return false; // the light check
        // The two mixed checks: stripes running down to the left.
        return ((px + py) % (2 * stripe)) < stripe;
      });
    }
  }
  _repeat(data, size, tile, p, p);
}

/// 1ピクセルごとの市松模様（チェッカー柄）：(x+y)が偶数の画素のみインクあり。
void _fillPixelCheckerPattern(
  Uint8List data,
  int size, {
  bool inverted = false,
}) {
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if ((x + y).isEven != inverted) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 1ピクセルごとの格子柄：1ピクセルおきの縦線・横線が交差して網目状になる。
void _fillPixelGridPattern(Uint8List data, int size, {bool inverted = false}) {
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if ((x.isEven || y.isEven) != inverted) {
        data[(y * size + x) * 4 + 3] = 255;
      }
    }
  }
}

/// Two crossed 1px diagonal line families; transparent diamonds remain.
void _fillPixelDiagonalMeshPattern(Uint8List data, int size) {
  const step = 4;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if ((x + y) % step == 0 || (x - y) % step == 0) {
        data[(y * size + x) * 4 + 3] = 255;
      }
    }
  }
}

/// 1ピクセルの点を、上下左右に1pxずつの空白を挟んで独立配置する
/// （2pxおきの格子点のみインクあり。斜め隣接はそのまま残るため、市松
/// （50%密度で隙間なし）とは見た目が異なる、より疎らな模様になる）。
void _fillPixelScatteredDotPattern(Uint8List data, int size) {
  for (int y = 0; y < size; y += 2) {
    for (int x = 0; x < size; x += 2) {
      data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 4×4 Bayerオーダードディザ行列（値0〜15の16段階）。標準的なオーダード
/// ディザリングで使われる配置で、市松・格子のような固定密度の模様とは
/// 異なり、閾値を変えるだけで疎〜密の様々な段階を規則的なパターンで
/// 表現できる（網点のように円が段々大きくなる連続的な階調ではなく、
/// ピクセル単位で塗る/塗らないが決まるドット絵・レトロゲーム風の見た目
/// になる）。
const List<List<int>> _bayerMatrix4x4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

/// 2×2 Bayerオーダードディザ行列（値0〜3の4段階）。4×4より繰り返し単位が
/// 大きく粗いため、よりピクセル感・レトロ感の強い見た目になる。
const List<List<int>> _bayerMatrix2x2 = [
  [0, 2],
  [3, 1],
];

/// 8×8 Bayerオーダードディザ行列（値0〜63の64段階）。4×4より繰り返し単位が
/// 細かく、階調の刻みも4倍細かいため、なだらかなグラデーションを
/// ドット絵として表現するのに向く。値は再帰的な生成規則
/// `M(2n) = 4*M(n) + [[0,2],[3,1]]` から機械的に求まるもの。
const List<List<int>> _bayerMatrix8x8 = [
  [0, 32, 8, 40, 2, 34, 10, 42],
  [48, 16, 56, 24, 50, 18, 58, 26],
  [12, 44, 4, 36, 14, 46, 6, 38],
  [60, 28, 52, 20, 62, 30, 54, 22],
  [3, 35, 11, 43, 1, 33, 9, 41],
  [51, 19, 59, 27, 49, 17, 57, 25],
  [15, 47, 7, 39, 13, 45, 5, 37],
  [63, 31, 55, 23, 61, 29, 53, 21],
];

/// オーダードディザ（Bayer行列）によるトーンパターン。使う行列は
/// [coarse]なら2×2（4段階）、[fine]なら8×8（64段階）、どちらでもなければ
/// 4×4（16段階）。[density]（0.0〜1.0）に応じた閾値で塗る画素を決める。
void _fillPixelDitherPattern(
  Uint8List data,
  int size,
  double density, {
  bool coarse = false,
  bool fine = false,
}) {
  final matrix = coarse
      ? _bayerMatrix2x2
      : fine
      ? _bayerMatrix8x8
      : _bayerMatrix4x4;
  final n = matrix.length;
  // 【不具合修正】2×2行列は4×4行列の「種」であり、25%・50%・75%の閾値では
  // 4×4版とまったく同じ画素配置になる。1画素単位のまま使うと「(粗)」と
  // 名乗りながら4×4版と1画素も違わないものが3件並んでしまっていた。
  // 「粗い」＝繰り返し単位が大きい、という名前どおりの意味になるよう、
  // 行列1マスを2×2画素へ拡大して描く。
  final scale = coarse ? 2 : 1;
  final threshold = (density.clamp(0.0, 1.0) * (n * n)).round();
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (matrix[(y ~/ scale) % n][(x ~/ scale) % n] < threshold) {
        data[(y * size + x) * 4 + 3] = 255;
      }
    }
  }
}

/// ストッキング・タイツの網目パターン（斜め45度の格子＝クロスハッチ）。
/// [denier]が低いほど（生地が薄いほど）格子間隔を詰めて密度を上げ、
/// 意図的に細かすぎるパターンにする（画面表示・書き出し解像度によっては
/// モアレが生じる密度になる）。[denier]が高いほど格子間隔・線の太さを
/// 増やし、厚手の生地らしい粗く不透明な見た目にする。タイルの大きさが
/// 間隔で割り切れれば（[toneTileSizeForPattern]）、継ぎ目でも網目がつながる。
void _fillStockingMeshPattern(Uint8List data, int size, int denier) {
  final spacing = _stockingMeshSpacing(denier);
  final thickness = (1 + (denier.clamp(10, 100) / 40).floor()).clamp(1, 3);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // Dartの`%`は割る数が正なら負の数でも0以上を返すので、x == yの
      // 両側で2つ目の斜線の位置がそろう（絶対値を取ると対角線で線が
      // 折り返され、太い線が1画素ずれた）。
      final diagA = (x + y) % spacing;
      final diagB = (x - y) % spacing;
      if (diagA < thickness || diagB < thickness) {
        data[(y * size + x) * 4 + 3] = 255;
      }
    }
  }
}

/// ストッキング・タイツの網目の間隔（px）。
///
/// 【不具合修正】以前は `2 + (denier - 10) / 90 * 6` で間隔を決めており、
/// 6種類のデニールが4種類の見た目にしかならなかった：
///   - 20と30デニールがどちらも間隔3・太さ1で完全に同一
///   - 10デニールは間隔2・太さ1になるが、(x+y)と(x-y)は必ず同じ偶奇に
///     なるため2つの斜線条件が一致してしまい、網目ではなく単なる市松模様
///     （「ピクセル市松（1px）」と1画素も違わないもの）になっていた
/// デニール10ごとに間隔を1ずつ増やす形へ変え、6種類とも別の網目になる
/// ようにした（test/builtin_presets_test.dartが全トーンの模様の重複を
/// 検出する）。
int _stockingMeshSpacing(int denier) =>
    (3 + (denier.clamp(10, 100) - 10) / 10).round().clamp(3, 12);

/// 縞模様の向き。
enum _StripeDirection { horizontal, vertical, diagonal }

/// 等間隔の縞模様。[spacing]px周期で[thickness]px分だけインクを置く。
///
/// 横・縦・斜め45度を1つの関数で扱う。斜めは`(x + y)`の剰余で判定する
/// （x+yが一定の画素は右上がり45度の直線上に並ぶため、追加の三角関数を
/// 使わずに正確な45度線が引ける）。
void _fillStripePattern(
  Uint8List data,
  int size, {
  required int spacing,
  required int thickness,
  required _StripeDirection direction,
}) {
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final v = switch (direction) {
        _StripeDirection.horizontal => y,
        _StripeDirection.vertical => x,
        _StripeDirection.diagonal => x + y,
      };
      if (v % spacing < thickness) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 方眼（縦線と横線の格子）。[spacing]px周期の線を[thickness]px幅で引く。
void _fillGridPattern(
  Uint8List data,
  int size, {
  required int spacing,
  required int thickness,
}) {
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (x % spacing < thickness || y % spacing < thickness) {
        data[(y * size + x) * 4 + 3] = 255;
      }
    }
  }
}

const int _crossHatchSpacing = 7;

/// クロスハッチ（交差する斜線、または縦横線）による陰影表現。
/// [diagonal]がtrueなら45度と135度の2方向、falseなら縦横2方向で交差させる。
void _fillCrossHatchPattern(
  Uint8List data,
  int size, {
  required int thickness,
  required bool diagonal,
}) {
  const spacing = _crossHatchSpacing;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final a = diagonal ? (x + y) % spacing : x % spacing;
      // 斜め135度側は (x - y) が一定の直線。Dartの`%`は割る数が正なら
      // 負の数でも0以上を返す。
      final b = diagonal ? (x - y) % spacing : y % spacing;
      if (a < thickness || b < thickness) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// レンガ（互い違いに半個ずれた矩形）の目地を描く。
/// [unit]がレンガ1個の高さ（幅はその2倍）、[thickness]が目地の太さ。
void _fillBrickPattern(
  Uint8List data,
  int size, {
  required int unit,
  required int thickness,
}) {
  final brickW = unit * 2;
  for (int y = 0; y < size; y++) {
    final row = y ~/ unit;
    // 1段ごとに横へ半個ずらす（互い違いの積み方）。
    final offset = row.isEven ? 0 : brickW ~/ 2;
    for (int x = 0; x < size; x++) {
      final horizontal = y % unit < thickness;
      final vertical = (x + offset) % brickW < thickness;
      if (horizontal || vertical) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 同心円（等間隔のリング）。中心はタイルの中央。
///
/// 画素の中心（x + 0.5）で中心からの距離を測るので、タイルの縁の左右・上下の
/// 画素は中心から同じ距離になる。並べると隣のタイルのリングと縁を挟んで
/// 鏡に映したように出会い、継ぎ目で1画素ずれない。リングは画素の中の
/// 覆う割合で描く（縁がなめらか。左右・上下で対称な点で数えるので、鏡に
/// 映した画素は同じ値になる）。
void _fillConcentricCirclePattern(Uint8List data, int size) {
  final c = size / 2;
  const spacing = 6.0, thickness = 2.0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      data[(y * size + x) * 4 + 3] = _coverage(x, y, (px, py) {
        final dx = px - c, dy = py - c;
        return math.sqrt(dx * dx + dy * dy) % spacing < thickness;
      });
    }
  }
}

const int _wavePeriod = 16;

/// 波線（横方向へ進むサインカーブを等間隔で重ねたもの）。縦の間隔
/// （[_waveSpacing]）で回すので、並べても線が途切れない（[size]は
/// [_wavePeriod]の倍数）。線は曲線からの距離で、傾いた所も同じ太さ
/// （2px）になるように描き、画素の中の覆う割合で縁をなめらかにする。
void _fillWavePattern(Uint8List data, int size) {
  const amplitude = 3.0, halfWidth = 1.0;
  const k = 2 * math.pi / _wavePeriod;
  final tile = Uint8List(_wavePeriod * _waveSpacing);
  for (var y = 0; y < _waveSpacing; y++) {
    for (var x = 0; x < _wavePeriod; x++) {
      tile[y * _wavePeriod + x] = _coverage(x, y, (px, py) {
        final slope = amplitude * k * math.cos(k * px);
        // Vertical offset from the nearest line, measured across the curve.
        final m = (py - 1 - amplitude * math.sin(k * px)) % _waveSpacing;
        final vertical = math.min(m, _waveSpacing - m);
        return vertical / math.sqrt(1 + slope * slope) < halfWidth;
      });
    }
  }
  _repeat(data, size, tile, _wavePeriod, _waveSpacing);
}

const int _waveSpacing = 8;

/// 砂目（ランダムな粒）。[density]の割合の画素へインクを置く。
///
/// 乱数は使わず座標から決定的に求める。`Random()`だと生成のたびに模様が
/// 変わり、同じトーンを2回貼ると見た目が食い違ってしまうため
/// （テクスチャはキャッシュされずその都度生成される）。
///
/// [cell]を2以上にすると粒が数px角のまとまりになり、アナログの砂目トーン
/// のような粗いざらつきになる。1なら1px単位のドット絵向けノイズ。
void _fillNoisePattern(
  Uint8List data,
  int size,
  double density, {
  required int cell,
}) {
  final threshold = (density.clamp(0.0, 1.0) * 1024).round();
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final gx = x ~/ cell, gy = y ~/ cell;
      // 大きめの奇数を掛けてビットを撹拌する整数ハッシュ。同じ座標なら
      // 常に同じ値を返すので、模様は毎回まったく同じになる。
      var h = gx * 374761393 + gy * 668265263;
      h = (h ^ (h >> 13)) * 1274126177;
      h = h ^ (h >> 16);
      if ((h & 1023) < threshold) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 網点（ハーフトーン）。[density]（0.0〜1.0）が濃いほど点が大きい。
///
/// 点はセルの真ん中に置いた円で、縁は画素の中の覆う割合で描く（以前は
/// 画素の角で円の内外を決めた2値で、点が半画素ずれて左右非対称なうえ、
/// 縁が段になっていた）。インクの量は以前の2値の点と同じにする（すでに
/// 描いた網点の隣に描き足しても濃さが変わらない）：[_dotRadiusFor]。
///
/// セルは16px。1セル256画素あり、10%刻みの9段階すべてが異なる濃さになる
/// （test/builtin_presets_test.dartが単調増加を検証）。
const int _dotCell = 16;

void _fillDotPattern(Uint8List data, int size, double density) {
  const cell = _dotCell;
  final radius = _dotRadiusFor(density.clamp(0.0, 1.0));
  final r2 = radius * radius;
  const centre = cell / 2;
  final tile = Uint8List(cell * cell);
  for (var y = 0; y < cell; y++) {
    for (var x = 0; x < cell; x++) {
      tile[y * cell + x] = _coverage(x, y, (px, py) {
        final dx = px - centre, dy = py - centre;
        return dx * dx + dy * dy <= r2;
      });
    }
  }
  _repeat(data, size, tile, cell, cell);
}

/// 網点の点の半径：以前の2値の点（半径＝セル÷2.2×√割合、画素の角が円の
/// 内側なら塗る）が塗った画素の数と、同じ面積の円の半径。以前の式の半径を
/// そのまま使うと、縁をなめらかにしたぶんインクが1.5〜2.3ポイント減る
/// （角で数えた2値は円の面積より多く塗っていた）。点はセルの内側に収まり
/// （90%でも半径約6.8px）、隣の点とはつながらない。
double _dotRadiusFor(double density) {
  const cell = _dotCell;
  final old = cell / 2.2 * math.sqrt(density);
  var inked = 0;
  for (var y = 0; y < cell; y++) {
    for (var x = 0; x < cell; x++) {
      final dx = x - cell / 2, dy = y - cell / 2;
      if (dx * dx + dy * dy <= old * old) inked++;
    }
  }
  return math.sqrt(inked / math.pi);
}

/// 画素(x, y)のうち[inside]が真になる割合（0〜255）。画素の中を
/// [samples]×[samples]の点で数える。
int _coverage(
  int x,
  int y,
  bool Function(double px, double py) inside, {
  int samples = 8,
}) {
  final n = samples;
  var hits = 0;
  for (var j = 0; j < n; j++) {
    final py = y + (j + 0.5) / n;
    for (var i = 0; i < n; i++) {
      if (inside(x + (i + 0.5) / n, py)) hits++;
    }
  }
  return (hits * 255 / (n * n)).round();
}

/// [tile]（[w]×[h]のインクの濃さ）を[size]四方へ並べ、[data]のalphaへ書く。
void _repeat(Uint8List data, int size, Uint8List tile, int w, int h) {
  for (var y = 0; y < size; y++) {
    final row = (y % h) * w;
    for (var x = 0; x < size; x++) {
      data[(y * size + x) * 4 + 3] = tile[row + x % w];
    }
  }
}

/// スタンプを描くテクスチャの基準の大きさ（px）。組み込みの画像の大きさ。
const int baseStampTextureSize = 128;

/// スタンプを描くテクスチャの最大の大きさ（px）。
const int maxStampTextureSize = 512;

/// [stamp]を描いた大きさ[renderedSize]（キャンバスのpx）に合うテクスチャの
/// 大きさ。描く大きさが基準より大きければその大きさ（最大
/// [maxStampTextureSize]）で作り、拡大でぼやけたり角が段になったりしない
/// ようにする。ドット絵にするスタンプは基準の大きさで粗くするので変えない。
int stampTextureSizeFor(Stamp stamp, double renderedSize) {
  if (stamp.pixelMode) return baseStampTextureSize;
  return renderedSize.ceil().clamp(baseStampTextureSize, maxStampTextureSize);
}

final RegExp _builtInStampPath = RegExp(r'^assets/stamps/(Stamp\d+)\.png$');

const String _leafClusterShape = '\u{0}leaf cluster';
const String _grassClusterShape = '\u{0}grass cluster';
const String _petalClusterShape = '\u{0}petal cluster';

/// 組み込みのスタンプの画像（`assets/stamps/<id>.png`）と、その画像を描いた
/// 形。画像はこのファイルの形を[baseStampTextureSize]で描いたもので、
/// 大きく描くときは形から描き直す。
const Map<String, String> builtInStampShapes = {
  'Stamp0001': '三角形',
  'Stamp0002': '五角形',
  'Stamp0003': '六角形',
  'Stamp0004': '星',
  'Stamp0005': 'ハート',
  'Stamp0006': '吹き出し',
  'Stamp0007': '矢印',
  'Stamp0008': '円',
  'Stamp0009': '四角形',
  'Stamp0010': '丸角四角',
  'Stamp0011': '菱形',
  'Stamp0012': '八角形',
  'Stamp0013': 'ドーナツ',
  'Stamp0015': '四芒星',
  'Stamp0018': 'キラキラ',
  'Stamp0020': '雲',
  'Stamp0021': '稲妻',
  'Stamp0022': '花',
  'Stamp0023': 'チェックマーク',
  'Stamp0024': '両矢印',
  'Stamp0025': _leafClusterShape,
  'Stamp0026': _grassClusterShape,
  'Stamp0029': 'しずく',
  'Stamp0030': '青筋マーク',
  'Stamp0031': '音符',
  'Stamp0032': 'スノーフレーク',
  'Stamp0033': _petalClusterShape,
};

/// [shape]（[builtInStampShapes]の値、または名前）を[s]px四方に描く。
void _drawStampShape(ui.Canvas canvas, String shape, double s) {
  if (shape == _leafClusterShape) {
    _drawLeafCluster(canvas, s);
  } else if (shape == _grassClusterShape) {
    _drawGrassCluster(canvas, s);
  } else if (shape == _petalClusterShape) {
    _drawPetalCluster(canvas, s);
  } else {
    final paint = ui.Paint()..color = const ui.Color(0xFF222222);
    canvas.drawPath(_shapePathForName(shape, s), paint);
  }
}

/// スタンプのテクスチャ（[size]px四方、乗算済みのRGBA）を取得する。自作
/// スタンプ（[Stamp.imagePath]が設定済み）の場合はその画像をそのまま
/// （自身の色情報を保持したまま）[size]pxで読み、組み込みの画像
/// （[builtInStampShapes]）と画像の無い古いスタンプは、形（図形は固定色の
/// 濃い灰色、葉っぱ・草・花びらは自身の色）を[size]pxで描く
/// （スタンプは現在色を使わず自身の色情報を保持する）。
/// [Stamp.pixelMode]がONの場合は、最後にFilterEngine.applyPixelate()で
/// モザイク低解像度化＋色数削減を行い、ドット絵風に加工する（ユーザー
/// 指示により新規追加。多色のスタンプ画像はペン/テキストのようなアルファ
/// 二値化だけでは真のドット絵にならないため、低解像度化と色数削減の
/// 両方が必要）。ストローク確定のたびに毎回呼ばれる関数のため、事前に
/// 加工済み画像をキャッシュするような仕組みは持たず、その都度計算する
/// （テクスチャサイズが小さく負荷は軽微なため）。
Future<Uint8List> generateBuiltInStampTexture(
  Stamp stamp, {
  int size = baseStampTextureSize,
  double? renderedSize,
  ui.Color color = const ui.Color(0xff000000),
}) async {
  final path = stamp.imagePath;
  final bundled = path == null
      ? null
      : _builtInStampPath.firstMatch(path)?.group(1);
  // The bundled images are this file's shapes drawn at 128px, so a bundled
  // shape is drawn again at the size it is needed instead of enlarging the
  // 128px image (which softened and stair-stepped large stamps).
  final bundledShape = bundled == null ? null : builtInStampShapes[bundled];
  Uint8List? texture;
  if (path != null && bundledShape == null) {
    texture = await _loadImageRgba(path, size);
  }
  if (texture == null) {
    final shape =
        bundledShape ??
        (stamp.id == 'Stamp0025' || stamp.name.contains('葉っぱ（背景）')
            ? _leafClusterShape
            : stamp.id == 'Stamp0026' || stamp.name.contains('草（背景）')
            ? _grassClusterShape
            : stamp.name);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    _drawStampShape(canvas, shape, size.toDouble());
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    texture = byteData!.buffer.asUint8List();
  }
  if (stamp.flatFill) {
    texture = _flatStampTexture(
      texture,
      size,
      renderedSize ?? size.toDouble(),
      color,
    );
  }
  if (stamp.pixelMode) {
    // スタンプは塗った形の絵：とがった先や細い部分を同じ太さの線として
    // 描き直すと形の輪郭が変わるので、線は描き直さない。
    texture = FilterEngine().applyPixelate(
      texture,
      size,
      size,
      dither: false,
      redrawLines: false,
    );
  }
  final opacityScale = stamp.opacity.clamp(1, 100) / 100.0;
  if (opacityScale < 1.0) {
    final adjusted = Uint8List.fromList(texture);
    for (int i = 0; i < adjusted.length; i++) {
      adjusted[i] = (adjusted[i] * opacityScale).round().clamp(0, 255);
    }
    texture = adjusted;
  }
  return texture;
}

Uint8List _flatStampTexture(
  Uint8List source,
  int size,
  double renderedSize,
  ui.Color color,
) {
  final result = Uint8List(source.length);
  for (var i = 3; i < source.length; i += 4) {
    result[i] = silhouetteAlpha(source[i]);
  }
  final distance = silhouetteDistance(result, size);
  const ink = ui.Color(0xff23302a);
  // One document pixel expressed in the texture's resampled coordinates.
  final texelsPerPixel = size / math.max(.5, renderedSize);
  for (var p = 0; p < distance.length; p++) {
    final i = p * 4;
    if (distance[p] == silhouetteDistanceLimit) continue;
    final fill = result[i + 3] / 255 * color.a;
    final outline =
        (1.5 - distance[p] / silhouetteDistanceUnits / texelsPerPixel).clamp(
          0.0,
          1.0,
        ) *
        (1 - result[i + 3] / 255);
    result[i] = ((fill * color.r + outline * ink.r) * 255).round();
    result[i + 1] = ((fill * color.g + outline * ink.g) * 255).round();
    result[i + 2] = ((fill * color.b + outline * ink.b) * 255).round();
    result[i + 3] = ((fill + outline) * 255).round();
  }
  return result;
}

void _drawLeafCluster(ui.Canvas canvas, double s) {
  final rng = math.Random(25025);
  const colors = <ui.Color>[
    ui.Color(0xFF1F6B38),
    ui.Color(0xFF2F8745),
    ui.Color(0xFF4B9A43),
    ui.Color(0xFF6EAE42),
    ui.Color(0xFF91BD45),
    ui.Color(0xFFB2C94B),
  ];
  for (var i = 0; i < 13; i++) {
    final cx = s * (0.18 + rng.nextDouble() * 0.64);
    final cy = s * (0.18 + rng.nextDouble() * 0.64);
    final length = s * (0.18 + rng.nextDouble() * 0.16);
    final width = length * (0.34 + rng.nextDouble() * 0.18);
    final angle = rng.nextDouble() * math.pi * 2;
    final paint = ui.Paint()..color = colors[i % colors.length];
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    final leaf = ui.Path()
      ..moveTo(-length * 0.52, 0)
      ..cubicTo(
        -length * 0.18,
        -width,
        length * 0.30,
        -width * 0.82,
        length * 0.52,
        0,
      )
      ..cubicTo(
        length * 0.28,
        width * 0.82,
        -length * 0.20,
        width,
        -length * 0.52,
        0,
      )
      ..close();
    canvas.drawPath(leaf, paint);
    // 葉脈を僅かに暗くして、縮小しても単色の楕円に潰れないようにする。
    final vein = ui.Paint()
      ..color = const ui.Color(0x55204E2B)
      ..strokeWidth = math.max(0.7, s * 0.008)
      ..style = ui.PaintingStyle.stroke;
    canvas.drawLine(
      ui.Offset(-length * 0.38, 0),
      ui.Offset(length * 0.40, 0),
      vein,
    );
    canvas.restore();
  }
}

void _drawGrassCluster(ui.Canvas canvas, double s) {
  final rng = math.Random(26026);
  const colors = <ui.Color>[
    ui.Color(0xFF285F31),
    ui.Color(0xFF34783B),
    ui.Color(0xFF4A8F3E),
    ui.Color(0xFF65A542),
    ui.Color(0xFF7DB544),
    ui.Color(0xFFA0C74D),
  ];
  final baseY = s * 0.82;
  for (var i = 0; i < 31; i++) {
    final x = s * (0.08 + rng.nextDouble() * 0.84);
    final height = s * (0.24 + rng.nextDouble() * 0.52);
    final bend = (rng.nextDouble() * 2 - 1) * s * 0.16;
    final width = s * (0.008 + rng.nextDouble() * 0.012);
    final paint = ui.Paint()..color = colors[i % colors.length];
    final blade = ui.Path()
      ..moveTo(x - width, baseY)
      ..quadraticBezierTo(
        x + bend * 0.35 - width,
        baseY - height * 0.55,
        x + bend,
        baseY - height,
      )
      ..quadraticBezierTo(
        x + bend * 0.35 + width,
        baseY - height * 0.55,
        x + width,
        baseY,
      )
      ..close();
    canvas.drawPath(blade, paint);
  }
}

/// 花びら（桜）：先に切れ込みのある花びらを、大きさ・向き・色を変えて散らす。
void _drawPetalCluster(ui.Canvas canvas, double s) {
  final rng = math.Random(33033);
  const colors = <ui.Color>[
    ui.Color(0xFFF9D9E1),
    ui.Color(0xFFF5C1CE),
    ui.Color(0xFFF0A9BB),
    ui.Color(0xFFEA93A9),
    ui.Color(0xFFFBE6EB),
  ];
  for (var i = 0; i < 7; i++) {
    final cx = s * (0.2 + rng.nextDouble() * 0.6);
    final cy = s * (0.2 + rng.nextDouble() * 0.6);
    final length = s * (0.2 + rng.nextDouble() * 0.12);
    final width = length * (0.58 + rng.nextDouble() * 0.14);
    final angle = rng.nextDouble() * math.pi * 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    canvas.translate(-length / 2, 0);
    final petal = ui.Path()
      ..moveTo(0, 0)
      ..cubicTo(
        length * 0.28,
        -width * 0.62,
        length * 0.86,
        -width * 0.66,
        length,
        -width * 0.2,
      )
      ..lineTo(length * 0.86, 0)
      ..lineTo(length, width * 0.2)
      ..cubicTo(length * 0.86, width * 0.66, length * 0.28, width * 0.62, 0, 0)
      ..close();
    canvas.drawPath(petal, ui.Paint()..color = colors[i % colors.length]);
    // A deeper pink at the base, where the petal joined the flower.
    canvas.drawPath(
      petal,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(length * 0.55, 0),
          const [ui.Color(0x66D9667F), ui.Color(0x00D9667F)],
        ),
    );
    canvas.restore();
  }
}

ui.Path _shapePathForName(String name, double s) {
  final c = ui.Offset(s / 2, s / 2);
  final r = s * 0.42;
  // トーンと同様、**判定の順序が仕様**になっている。「両矢印」は「矢印」を、
  // 「四芒星」「六芒星」「八芒星」は「星」を含むため、限定的な名前から先に
  // 判定する。新しい図形を足すときはこの並びの適切な位置へ差し込むこと。
  if (name.contains('しずく')) return _sweatDrop(c, r);
  if (name.contains('青筋マーク')) return _angerMark(c, r);
  if (name.contains('音符')) return _musicNote(c, r);
  if (name.contains('スノーフレーク')) return _snowflake(c, r);
  if (name.contains('三角')) {
    return _regularPolygon(c, r, 3, rotation: -math.pi / 2);
  }
  if (name.contains('四角')) {
    // 「丸角四角」も含む。角の丸めは名前で切り替える。
    final rect = ui.Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.7);
    return name.contains('丸角')
        ? (ui.Path()..addRRect(
            ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(r * 0.3)),
          ))
        : (ui.Path()..addRect(rect));
  }
  if (name.contains('五角')) {
    return _regularPolygon(c, r, 5, rotation: -math.pi / 2);
  }
  if (name.contains('六角')) return _regularPolygon(c, r, 6);
  if (name.contains('八角')) {
    return _regularPolygon(c, r, 8, rotation: math.pi / 8);
  }
  if (name.contains('菱形')) {
    return _regularPolygon(c, r, 4, rotation: -math.pi / 2);
  }
  if (name.contains('四芒星')) return _star(c, r, r * 0.22, 4);
  if (name.contains('六芒星')) return _star(c, r, r * 0.55, 6);
  if (name.contains('八芒星')) return _star(c, r, r * 0.5, 8);
  if (name.contains('キラキラ')) {
    // 星よりくびれを深くした、光の煌めき表現向けの4芒星。
    return _star(c, r, r * 0.1, 4);
  }
  if (name.contains('星')) return _star(c, r, r * 0.42, 5);
  if (name.contains('ハート')) return _heart(c, r);
  if (name.contains('ドーナツ')) {
    return ui.Path.combine(
      ui.PathOperation.difference,
      ui.Path()..addOval(ui.Rect.fromCircle(center: c, radius: r)),
      ui.Path()..addOval(ui.Rect.fromCircle(center: c, radius: r * 0.5)),
    );
  }
  if (name.contains('三日月')) {
    // 円から、右上へずらした円を引いて欠けさせる。
    return ui.Path.combine(
      ui.PathOperation.difference,
      ui.Path()..addOval(ui.Rect.fromCircle(center: c, radius: r)),
      ui.Path()..addOval(
        ui.Rect.fromCircle(
          center: ui.Offset(c.dx + r * 0.45, c.dy - r * 0.2),
          radius: r * 0.92,
        ),
      ),
    );
  }
  if (name.contains('十字')) {
    final arm = r * 0.32;
    return ui.Path.combine(
      ui.PathOperation.union,
      ui.Path()
        ..addRect(ui.Rect.fromCenter(center: c, width: arm * 2, height: r * 2)),
      ui.Path()
        ..addRect(ui.Rect.fromCenter(center: c, width: r * 2, height: arm * 2)),
    );
  }
  if (name.contains('チェック')) return _checkMark(c, r);
  if (name.contains('雲')) return _cloud(c, r);
  if (name.contains('稲妻')) return _lightning(c, r);
  if (name.contains('花')) return _flower(c, r, 5);
  if (name.contains('吹き出し')) return _speechBubble(c, r);
  if (name.contains('両矢印')) return _doubleArrow(c, r);
  if (name.contains('矢印')) return _arrow(c, r);
  return ui.Path()..addOval(ui.Rect.fromCircle(center: c, radius: r));
}

/// しずく（汗の漫符）：上がとがった水滴。左上に光の抜きを入れる。
ui.Path _sweatDrop(ui.Offset c, double r) {
  final centre = ui.Offset(c.dx, c.dy + r * 0.3);
  final radius = r * 0.6;
  final tip = ui.Offset(c.dx, c.dy - r);
  // Where the lines from the tip touch the round bottom.
  final toTip = (tip - centre).distance;
  final spread = math.acos(radius / toTip);
  const up = -math.pi / 2;
  ui.Offset onCircle(double a) => ui.Offset(
    centre.dx + radius * math.cos(a),
    centre.dy + radius * math.sin(a),
  );
  final left = onCircle(up - spread);
  final right = onCircle(up + spread);
  final drop = ui.Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(
      (tip.dx + left.dx) / 2 - r * 0.06,
      (tip.dy + left.dy) / 2,
      left.dx,
      left.dy,
    )
    ..arcTo(
      ui.Rect.fromCircle(center: centre, radius: radius),
      up - spread,
      -(2 * math.pi - 2 * spread),
      false,
    )
    ..lineTo(right.dx, right.dy)
    ..quadraticBezierTo(
      (tip.dx + right.dx) / 2 + r * 0.06,
      (tip.dy + right.dy) / 2,
      tip.dx,
      tip.dy,
    )
    ..close();
  final shine = ui.Path()
    ..addOval(
      ui.Rect.fromCenter(
        center: ui.Offset(centre.dx - radius * 0.42, centre.dy - radius * 0.1),
        width: radius * 0.28,
        height: radius * 0.62,
      ),
    );
  return ui.Path.combine(ui.PathOperation.difference, drop, shine);
}

/// 青筋マーク（怒りの漫符）：4つの弧を十字に置く。どの弧も中心へ向かってふくらみ、
/// 両端がとがる。
ui.Path _angerMark(ui.Offset c, double r) {
  var mark = ui.Path();
  for (final (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
    ui.Offset at(double x, double y) =>
        ui.Offset(c.dx + sx * x * r, c.dy + sy * y * r);
    final a = at(0.22, 0.95);
    final b = at(0.95, 0.22);
    final inner = at(0.2, 0.2);
    final outer = at(0.52, 0.52);
    final arc = ui.Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(inner.dx, inner.dy, b.dx, b.dy)
      ..quadraticBezierTo(outer.dx, outer.dy, a.dx, a.dy)
      ..close();
    mark = ui.Path.combine(ui.PathOperation.union, mark, arc);
  }
  return mark;
}

/// 音符（八分音符）：傾いた楕円の玉、右側の棒、棒の上から下りる旗。
ui.Path _musicNote(ui.Offset c, double r) {
  final head = ui.Path()
    ..addOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: r * 0.78,
        height: r * 0.56,
      ),
    );
  final headCentre = ui.Offset(c.dx - r * 0.25, c.dy + r * 0.62);
  final placed = head.transform(_rotationAbout(-0.42, 0, 0)).shift(headCentre);
  final stemX = headCentre.dx + r * 0.3;
  final stemW = r * 0.12;
  final top = c.dy - r * 0.95;
  final stem = ui.Path()
    ..addRect(
      ui.Rect.fromLTRB(stemX, top, stemX + stemW, headCentre.dy - r * 0.05),
    );
  final flag = ui.Path()
    ..moveTo(stemX + stemW, top)
    ..cubicTo(
      stemX + stemW + r * 0.05,
      top + r * 0.35,
      stemX + r * 0.75,
      top + r * 0.42,
      stemX + r * 0.58,
      top + r * 1.02,
    )
    ..cubicTo(
      stemX + r * 0.6,
      top + r * 0.62,
      stemX + stemW + r * 0.05,
      top + r * 0.55,
      stemX + stemW,
      top + r * 0.48,
    )
    ..close();
  return ui.Path.combine(
    ui.PathOperation.union,
    ui.Path.combine(ui.PathOperation.union, placed, stem),
    flag,
  );
}

/// スノーフレーク（雪の結晶）：中心から6本の腕を出し、腕ごとに外向きの枝を2組付ける。
ui.Path _snowflake(ui.Offset c, double r) {
  final arm = r * 0.11;
  var flake = ui.Path()
    ..addPolygon([
      for (var k = 0; k < 6; k++)
        ui.Offset(
          c.dx + r * 0.2 * math.cos(k * math.pi / 3),
          c.dy + r * 0.2 * math.sin(k * math.pi / 3),
        ),
    ], true);
  // One arm pointing up from the origin with its branches, then turned
  // into place around the centre.
  final pieces = <ui.Path>[
    ui.Path()..addRect(ui.Rect.fromLTRB(-arm / 2, -r, arm / 2, 0)),
    for (final (along, length) in const [(0.5, 0.36), (0.76, 0.24)])
      for (final side in const [-1.0, 1.0])
        (ui.Path()..addRect(
              ui.Rect.fromLTRB(
                -arm / 2,
                -r * along - r * length,
                arm / 2,
                -r * along,
              ),
            ))
            .transform(_rotationAbout(side * math.pi / 3, 0, -r * along)),
  ];
  for (var k = 0; k < 6; k++) {
    final turn = _rotationAbout(k * math.pi / 3, 0, 0);
    for (final piece in pieces) {
      flake = ui.Path.combine(
        ui.PathOperation.union,
        flake,
        piece.transform(turn).shift(c),
      );
    }
  }
  return flake;
}

/// ([px], [py])を中心に[angle]だけ回す変換（`Path.transform`の行列）。
Float64List _rotationAbout(double angle, double px, double py) {
  final cosA = math.cos(angle), sinA = math.sin(angle);
  return Float64List.fromList([
    cosA, sinA, 0, 0, //
    -sinA, cosA, 0, 0, //
    0, 0, 1, 0, //
    px - cosA * px + sinA * py, py - sinA * px - cosA * py, 0, 1, //
  ]);
}

/// チェックマーク（レ点）。折れ線を太らせた多角形として作る。
ui.Path _checkMark(ui.Offset c, double r) {
  final w = r * 0.28;
  return ui.Path()
    ..moveTo(c.dx - r * 0.75, c.dy)
    ..lineTo(c.dx - r * 0.3, c.dy + r * 0.5)
    ..lineTo(c.dx + r * 0.8, c.dy - r * 0.62)
    ..lineTo(c.dx + r * 0.8, c.dy - r * 0.62 + w)
    ..lineTo(c.dx - r * 0.3, c.dy + r * 0.5 + w)
    ..lineTo(c.dx - r * 0.75, c.dy + w)
    ..close();
}

/// 雲（大きさの違う円を重ねた輪郭）。
ui.Path _cloud(ui.Offset c, double r) {
  var path = ui.Path()
    ..addOval(
      ui.Rect.fromCircle(
        center: ui.Offset(c.dx, c.dy + r * 0.1),
        radius: r * 0.5,
      ),
    );
  for (final blob in [
    (dx: -0.55, dy: 0.25, rr: 0.38),
    (dx: 0.55, dy: 0.25, rr: 0.38),
    (dx: -0.25, dy: -0.2, rr: 0.42),
    (dx: 0.3, dy: -0.18, rr: 0.4),
  ]) {
    path = ui.Path.combine(
      ui.PathOperation.union,
      path,
      ui.Path()..addOval(
        ui.Rect.fromCircle(
          center: ui.Offset(c.dx + r * blob.dx, c.dy + r * blob.dy),
          radius: r * blob.rr,
        ),
      ),
    );
  }
  // 底面を平らに切り落として雲らしいシルエットにする。
  return ui.Path.combine(
    ui.PathOperation.intersect,
    path,
    ui.Path()..addRect(
      ui.Rect.fromLTRB(c.dx - r, c.dy - r, c.dx + r, c.dy + r * 0.55),
    ),
  );
}

/// 稲妻（ジグザグの帯）。
ui.Path _lightning(ui.Offset c, double r) => ui.Path()
  ..moveTo(c.dx + r * 0.25, c.dy - r)
  ..lineTo(c.dx - r * 0.6, c.dy + r * 0.12)
  ..lineTo(c.dx - r * 0.05, c.dy + r * 0.12)
  ..lineTo(c.dx - r * 0.3, c.dy + r)
  ..lineTo(c.dx + r * 0.6, c.dy - r * 0.18)
  ..lineTo(c.dx + r * 0.02, c.dy - r * 0.18)
  ..close();

/// 両矢印（左右両端に矢尻を持つ帯）。
ui.Path _doubleArrow(ui.Offset c, double r) {
  final shaftW = r * 0.3;
  final headX = r * 0.45; // 矢尻の付け根のx距離
  final headY = r * 0.6; // 矢尻の高さ
  return ui.Path()
    ..moveTo(c.dx - r, c.dy) // 左の先端
    ..lineTo(c.dx - headX, c.dy - headY)
    ..lineTo(c.dx - headX, c.dy - shaftW / 2)
    ..lineTo(c.dx + headX, c.dy - shaftW / 2)
    ..lineTo(c.dx + headX, c.dy - headY)
    ..lineTo(c.dx + r, c.dy) // 右の先端
    ..lineTo(c.dx + headX, c.dy + headY)
    ..lineTo(c.dx + headX, c.dy + shaftW / 2)
    ..lineTo(c.dx - headX, c.dy + shaftW / 2)
    ..lineTo(c.dx - headX, c.dy + headY)
    ..close();
}

/// 花（中心の円のまわりへ花びらを[petals]枚放射状に並べる）。
///
/// 花びらは「中心から外向きに伸びる細長い形」なので、行列で回転させる
/// のではなく、極座標（中心からの角度と距離）で輪郭点を直接求めている。
/// 角度aの方向へ伸びる花びらの輪郭を、その方向を基準にした
/// ローカル座標(u=外向き, v=横向き)で作り、最後にワールド座標へ写す。
ui.Path _flower(ui.Offset c, double r, int petals) {
  var path = ui.Path()
    ..addOval(ui.Rect.fromCircle(center: c, radius: r * 0.28));
  for (int i = 0; i < petals; i++) {
    final a = -math.pi / 2 + 2 * math.pi * i / petals;
    final cosA = math.cos(a), sinA = math.sin(a);
    // ローカル座標の点をワールド座標へ写す（u:外向き, v:横向き）。
    ui.Offset at(double u, double v) =>
        ui.Offset(c.dx + u * cosA - v * sinA, c.dy + u * sinA + v * cosA);
    final petal = ui.Path()..moveTo(at(r * 0.2, 0).dx, at(r * 0.2, 0).dy);
    // 付け根から先端へ、左右へ膨らむ涙型を2本の3次ベジェで描く。
    final tip = at(r, 0);
    final leftCtrl1 = at(r * 0.35, -r * 0.34);
    final leftCtrl2 = at(r * 0.8, -r * 0.28);
    final rightCtrl1 = at(r * 0.8, r * 0.28);
    final rightCtrl2 = at(r * 0.35, r * 0.34);
    petal
      ..cubicTo(
        leftCtrl1.dx,
        leftCtrl1.dy,
        leftCtrl2.dx,
        leftCtrl2.dy,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        rightCtrl1.dx,
        rightCtrl1.dy,
        rightCtrl2.dx,
        rightCtrl2.dy,
        at(r * 0.2, 0).dx,
        at(r * 0.2, 0).dy,
      )
      ..close();
    path = ui.Path.combine(ui.PathOperation.union, path, petal);
  }
  return path;
}

ui.Path _regularPolygon(
  ui.Offset c,
  double r,
  int sides, {
  double rotation = 0,
}) {
  final path = ui.Path();
  for (int i = 0; i < sides; i++) {
    final a = rotation + (2 * math.pi * i / sides);
    final p = ui.Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

ui.Path _star(ui.Offset c, double outerR, double innerR, int points) {
  final path = ui.Path();
  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? outerR : innerR;
    final a = -math.pi / 2 + math.pi * i / points;
    final p = ui.Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

ui.Path _heart(ui.Offset c, double r) {
  final path = ui.Path();
  path.moveTo(c.dx, c.dy + r * 0.8);
  path.cubicTo(
    c.dx - r * 1.4,
    c.dy - r * 0.3,
    c.dx - r * 0.5,
    c.dy - r * 1.3,
    c.dx,
    c.dy - r * 0.5,
  );
  path.cubicTo(
    c.dx + r * 0.5,
    c.dy - r * 1.3,
    c.dx + r * 1.4,
    c.dy - r * 0.3,
    c.dx,
    c.dy + r * 0.8,
  );
  path.close();
  return path;
}

ui.Path _speechBubble(ui.Offset c, double r) {
  final rect = ui.Rect.fromCenter(
    center: ui.Offset(c.dx, c.dy - r * 0.15),
    width: r * 1.8,
    height: r * 1.3,
  );
  final body = ui.Path()
    ..addRRect(ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(r * 0.25)));
  final tail = ui.Path()
    ..moveTo(c.dx - r * 0.2, rect.bottom - 2)
    ..lineTo(c.dx - r * 0.5, rect.bottom + r * 0.4)
    ..lineTo(c.dx + r * 0.1, rect.bottom - 2)
    ..close();
  return ui.Path.combine(ui.PathOperation.union, body, tail);
}

ui.Path _arrow(ui.Offset c, double r) {
  final shaftW = r * 0.35;
  return ui.Path()
    ..moveTo(c.dx - r, c.dy - shaftW / 2)
    ..lineTo(c.dx + r * 0.2, c.dy - shaftW / 2)
    ..lineTo(c.dx + r * 0.2, c.dy - r * 0.55)
    ..lineTo(c.dx + r, c.dy)
    ..lineTo(c.dx + r * 0.2, c.dy + r * 0.55)
    ..lineTo(c.dx + r * 0.2, c.dy + shaftW / 2)
    ..lineTo(c.dx - r, c.dy + shaftW / 2)
    ..close();
}
