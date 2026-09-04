import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/stamp.dart';
import '../models/tone.dart';
import 'filter_engine.dart';

/// [Tone.texturePath] / [Stamp.imagePath] が未設定（アプリ組み込みの初期
/// トーン・スタンプにはテクスチャ画像が同梱されていない）の場合に、名前から
/// 簡易的な代替テクスチャを生成するユーティリティ。
/// ユーザーが画像を登録した場合（自作トーン・自作スタンプ）は、そちらの
/// 画像を読み込んで使用し、このパターン生成はフォールバックとして使う。

/// 画像ファイルを読み込み、size×sizeのRGBAバイト列にデコードする。
/// 失敗した場合はnullを返す。
Future<Uint8List?> _loadImageRgba(String path, int size) async {
  final file = File(path);
  if (!await file.exists()) return null;
  try {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// トーンは自身の色を持たず、現在色×パターンの2値マスクとして扱われる
/// （autofill_engine.dart等はalphaチャンネルの有無のみを見る）。読み込んだ
/// 画像は輝度が低い（暗い）ほど「インクあり」とみなし、alphaへ変換する。
Uint8List _toToneAlphaMask(Uint8List rgba) {
  final out = Uint8List(rgba.length);
  for (int i = 0; i < rgba.length; i += 4) {
    final luminance =
        rgba[i] * 0.299 + rgba[i + 1] * 0.587 + rgba[i + 2] * 0.114;
    final ink = ((255 - luminance) * rgba[i + 3] / 255).round();
    out[i + 3] = ink.clamp(0, 255);
  }
  return out;
}

/// トーン画像のデコード結果キャッシュ（`texturePath#size`をキーにする）。
/// バケツ塗りのドラッグ中（_bucketFillAt）は同期処理のため、事前に
/// [ensureToneTextureLoaded] で読み込みを済ませておく必要がある。
final Map<String, Uint8List> _toneImageCache = {};

String _toneCacheKey(String path, int size) => '$path#$size';

/// [tone.texturePath] が指す画像を事前読み込みし、キャッシュへ格納する。
/// トーンを使った描画（投げ縄塗り・トーン自由描画・バケツ塗り等）の
/// 開始前に呼び出しておくことで、[generateBuiltInToneTexture] の同期呼び出し
/// でも自作画像を反映できるようにする。
Future<void> ensureToneTextureLoaded(Tone tone, {int size = 64}) async {
  final path = tone.texturePath;
  if (path == null) return;
  final key = _toneCacheKey(path, size);
  if (_toneImageCache.containsKey(key)) return;
  final rgba = await _loadImageRgba(path, size);
  if (rgba != null) _toneImageCache[key] = _toToneAlphaMask(rgba);
}

/// トーンのテクスチャを取得する。自作トーン（[Tone.texturePath]が設定済み）
/// で[ensureToneTextureLoaded]済みの場合はその画像由来のパターンを、
/// それ以外は組み込みトーン向けの簡易パターン（網点／ライン）を返す。
Uint8List generateBuiltInToneTexture(Tone tone, {int size = 64}) {
  final path = tone.texturePath;
  if (path != null) {
    final cached = _toneImageCache[_toneCacheKey(path, size)];
    if (cached != null) return cached;
  }
  final data = Uint8List(size * size * 4);
  final name = tone.name;
  // 名前で分岐する都合上、**判定の順序が仕様**になっている点に注意。
  // 「ピクセルディザ」は「ピクセル」を含み、「ピクセル格子」は「格子」を
  // 含む、といった包含関係があるため、より限定的な名前から先に判定する。
  // 新しいトーンを足すときは、既存の判定語（網点・ライン・市松・格子・
  // 散らし・砂目・レンガ・方眼・クロスハッチ等）を部分文字列として
  // 含まない名前にするか、この並びの適切な位置へ差し込むこと。
  if (name.contains('ピクセルディザ')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '50') ??
        50;
    _fillPixelDitherPattern(
      data,
      size,
      percent / 100.0,
      coarse: name.contains('粗'),
      fine: name.contains('細'),
    );
  } else if (name.contains('ピクセル砂目')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '50') ??
        50;
    _fillNoisePattern(data, size, percent / 100.0, cell: 1);
  } else if (name.contains('ピクセルレンガ')) {
    _fillBrickPattern(data, size, unit: 4, thickness: 1);
  } else if (name.contains('ピクセル') && name.contains('縞')) {
    final diagonal = name.contains('斜め');
    _fillStripePattern(
      data,
      size,
      // 斜めだけ間隔3にする。間隔2の斜め1px線は「(x+y)が偶数」という
      // 条件そのもので、市松模様と1画素も違わなくなってしまうため。
      spacing: diagonal ? 3 : 2,
      thickness: 1,
      direction: diagonal
          ? _StripeDirection.diagonal
          : name.contains('縦')
          ? _StripeDirection.vertical
          : _StripeDirection.horizontal,
    );
  } else if (name.contains('市松')) {
    // ピクセルモード用：1ピクセルごとに市松模様。
    _fillPixelCheckerPattern(data, size);
  } else if (name.contains('格子')) {
    // ピクセルモード用：1ピクセルごとに格子柄。
    _fillPixelGridPattern(data, size);
  } else if (name.contains('散らし')) {
    // ピクセルモード用：1ピクセルの点を上下左右1pxずつ空けて独立配置。
    // 市松（斜めに隣接）・格子（縦横の線がつながる）とは異なり、
    // どの点も上下左右の隣接ピクセルとは接しない。
    _fillPixelScatteredDotPattern(data, size);
  } else if (name.contains('ストッキング') || name.contains('タイツ')) {
    final denier =
        int.tryParse(RegExp(r'(\d+)デニール').firstMatch(name)?.group(1) ?? '20') ??
        20;
    _fillStockingMeshPattern(data, size, denier);
  } else if (name.contains('砂目')) {
    // アナログの砂目トーン相当。粒を数px単位のまとまりにすることで、
    // 1px単位の「ピクセル砂目」より粗くざらついた質感になる。
    final cell = name.contains('粗')
        ? 3
        : name.contains('細')
        ? 1
        : 2;
    _fillNoisePattern(data, size, 0.42, cell: cell);
  } else if (name.contains('同心円')) {
    _fillConcentricCirclePattern(data, size);
  } else if (name.contains('波線')) {
    _fillWavePattern(data, size);
  } else if (name.contains('レンガ')) {
    _fillBrickPattern(data, size, unit: 16, thickness: 2);
  } else if (name.contains('方眼')) {
    _fillGridPattern(
      data,
      size,
      spacing: 8,
      thickness: name.contains('太') ? 2 : 1,
    );
  } else if (name.contains('クロスハッチ')) {
    final thickness = name.contains('太')
        ? 3
        : name.contains('細')
        ? 1
        : 2;
    _fillCrossHatchPattern(
      data,
      size,
      thickness: thickness,
      diagonal: name.contains('斜め'),
    );
  } else if (name.contains('ライン')) {
    _fillStripePattern(
      data,
      size,
      spacing: 6,
      thickness: name.contains('太') ? 3 : 1,
      direction: name.contains('縦')
          ? _StripeDirection.vertical
          : name.contains('斜め')
          ? _StripeDirection.diagonal
          : _StripeDirection.horizontal,
    );
  } else if (name.contains('網点')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '30') ??
        30;
    _fillDotPattern(data, size, percent / 100.0);
  } else {
    _fillDotPattern(data, size, 0.3);
  }
  return data;
}

/// 1ピクセルごとの市松模様（チェッカー柄）：(x+y)が偶数の画素のみインクあり。
void _fillPixelCheckerPattern(Uint8List data, int size) {
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if ((x + y).isEven) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 1ピクセルごとの格子柄：1ピクセルおきの縦線・横線が交差して網目状になる。
void _fillPixelGridPattern(Uint8List data, int size) {
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (x.isEven || y.isEven) data[(y * size + x) * 4 + 3] = 255;
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
/// 増やし、厚手の生地らしい粗く不透明な見た目にする。
void _fillStockingMeshPattern(Uint8List data, int size, int denier) {
  final clampedDenier = denier.clamp(10, 100);
  // 【不具合修正】以前は `2 + (denier - 10) / 90 * 6` で間隔を決めており、
  // 6種類のデニールが4種類の見た目にしかならなかった：
  //   - 20と30デニールがどちらも間隔3・太さ1で完全に同一
  //   - 10デニールは間隔2・太さ1になるが、(x+y)と(x-y)は必ず同じ偶奇に
  //     なるため2つの斜線条件が一致してしまい、網目ではなく単なる市松模様
  //     （「ピクセル市松（1px）」と1画素も違わないもの）になっていた
  // デニール10ごとに間隔を1ずつ増やす形へ変え、6種類とも別の網目になる
  // ようにした（test/builtin_presets_test.dartが全トーンの模様の重複を
  // 検出する）。
  final spacing = (3 + (clampedDenier - 10) / 10).round().clamp(3, 12);
  final thickness = (1 + (clampedDenier / 40).floor()).clamp(1, 3);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final diagA = (x + y) % spacing;
      final diagB = (x - y).abs() % spacing;
      if (diagA < thickness || diagB < thickness) {
        data[(y * size + x) * 4 + 3] = 255;
      }
    }
  }
}

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

/// クロスハッチ（交差する斜線、または縦横線）による陰影表現。
/// [diagonal]がtrueなら45度と135度の2方向、falseなら縦横2方向で交差させる。
void _fillCrossHatchPattern(
  Uint8List data,
  int size, {
  required int thickness,
  required bool diagonal,
}) {
  const spacing = 7;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final a = diagonal ? (x + y) % spacing : x % spacing;
      // 斜め135度側は (x - y) が一定の直線。負値を避けるためsizeを足してから剰余を取る。
      final b = diagonal ? (x - y + size) % spacing : y % spacing;
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
/// タイルは繰り返し並べられるため縁で模様が途切れるが、リング状の背景・
/// 集中演出の下地として使うぶんには問題にならない。
void _fillConcentricCirclePattern(Uint8List data, int size) {
  final cx = size / 2, cy = size / 2;
  const spacing = 6, thickness = 2;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - cx, dy = y - cy;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r % spacing < thickness) data[(y * size + x) * 4 + 3] = 255;
    }
  }
}

/// 波線（横方向へ進むサインカーブを等間隔で重ねたもの）。
void _fillWavePattern(Uint8List data, int size) {
  const spacing = 8, amplitude = 3.0, period = 16.0;
  for (int x = 0; x < size; x++) {
    final shift = amplitude * math.sin(2 * math.pi * x / period);
    for (int baseY = 0; baseY < size + spacing; baseY += spacing) {
      final y = (baseY + shift).round();
      if (y < 0 || y >= size) continue;
      data[(y * size + x) * 4 + 3] = 255;
      // 1pxだと拡大時に途切れて見えるため2px幅にする。
      if (y + 1 < size) data[((y + 1) * size + x) * 4 + 3] = 255;
    }
  }
}

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

/// 網点（ハーフトーン）。[density]（0.0〜1.0）が、インクで覆われる面積の
/// 割合になるように点の半径を決める。
///
/// 半径は密度の**平方根**に比例させる。円の面積は半径の2乗に比例するため、
/// 半径を密度に正比例させると「10%」と「20%」で面積が4倍違ってしまい、
/// 名前の数字と見た目が一致しない。
///
/// セルは16px。以前は8pxだったが、1セル64画素では表現できる濃さの段階が
/// 粗すぎて、10%と20%、40%と50%がそれぞれ同じ見た目（点1個ぶんの差も
/// 出ない）になっていた。16pxなら1セル256画素あり、10%刻みの9段階すべてが
/// 異なる濃さになる（test/builtin_presets_test.dartが単調増加を検証）。
void _fillDotPattern(Uint8List data, int size, double density) {
  const cell = 16;
  final maxR = cell / 2.2;
  final radius = maxR * math.sqrt(density.clamp(0.0, 1.0));
  for (int y = 0; y < size; y++) {
    final cy = (y ~/ cell) * cell + cell / 2;
    for (int x = 0; x < size; x++) {
      final cx = (x ~/ cell) * cell + cell / 2;
      final dx = x - cx;
      final dy = y - cy;
      final idx = (y * size + x) * 4;
      if ((dx * dx + dy * dy) <= radius * radius) {
        data[idx + 3] = 255; // 色はRGB=0（黒）のまま・alphaのみ立てる
      }
    }
  }
}

/// スタンプのテクスチャを取得する。自作スタンプ（[Stamp.imagePath]が
/// 設定済み）の場合はその画像をそのまま（RGBA・自身の色情報を保持したまま）
/// 使用し、それ以外は組み込みスタンプ向けの簡易図形（三角形・五角形・
/// 六角形・星・ハート・吹き出し・矢印）を固定色（黒）でラスタライズする
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
  int size = 128,
}) async {
  final path = stamp.imagePath;
  Uint8List? texture;
  if (path != null) {
    texture = await _loadImageRgba(path, size);
  }
  if (texture == null) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..color = const ui.Color(0xFF222222);
    canvas.drawPath(_shapePathForName(stamp.name, size.toDouble()), paint);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    texture = byteData!.buffer.asUint8List();
  }
  if (stamp.pixelMode) {
    texture = FilterEngine().applyPixelate(texture, size, size);
  }
  final opacityScale = stamp.opacity.clamp(1, 100) / 100.0;
  if (opacityScale < 1.0) {
    final adjusted = Uint8List.fromList(texture);
    for (int i = 3; i < adjusted.length; i += 4) {
      adjusted[i] = (adjusted[i] * opacityScale).round().clamp(0, 255);
    }
    texture = adjusted;
  }
  return texture;
}

ui.Path _shapePathForName(String name, double s) {
  final c = ui.Offset(s / 2, s / 2);
  final r = s * 0.42;
  // トーンと同様、**判定の順序が仕様**になっている。「両矢印」は「矢印」を、
  // 「四芒星」「六芒星」「八芒星」は「星」を含むため、限定的な名前から先に
  // 判定する。新しい図形を足すときはこの並びの適切な位置へ差し込むこと。
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
