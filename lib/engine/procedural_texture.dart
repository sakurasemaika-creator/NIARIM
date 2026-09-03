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
  if (name.contains('網点')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '30') ??
        30;
    _fillDotPattern(data, size, percent / 100.0);
  } else if (name.contains('ライン')) {
    _fillLinePattern(data, size, name.contains('太') ? 3 : 1);
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
  } else if (name.contains('ピクセルディザ')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '50') ??
        50;
    _fillPixelDitherPattern(
      data,
      size,
      percent / 100.0,
      coarse: name.contains('粗'),
    );
  } else if (name.contains('ストッキング') || name.contains('タイツ')) {
    final denier =
        int.tryParse(RegExp(r'(\d+)デニール').firstMatch(name)?.group(1) ?? '20') ??
        20;
    _fillStockingMeshPattern(data, size, denier);
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

/// オーダードディザ（Bayer行列）によるトーンパターン。[coarse]がtrueの
/// 場合は2×2行列（4段階）、falseの場合は4×4行列（16段階）を使い、
/// [density]（0.0〜1.0）に応じた閾値で塗る画素を決める。
void _fillPixelDitherPattern(
  Uint8List data,
  int size,
  double density, {
  bool coarse = false,
}) {
  final matrix = coarse ? _bayerMatrix2x2 : _bayerMatrix4x4;
  final n = matrix.length;
  final threshold = (density.clamp(0.0, 1.0) * (n * n)).round();
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (matrix[y % n][x % n] < threshold) {
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
  final spacing = (2 + (clampedDenier - 10) / 90 * 6).round().clamp(2, 8);
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

void _fillDotPattern(Uint8List data, int size, double density) {
  const cell = 8;
  final maxR = cell / 2.2;
  final radius = maxR * density.clamp(0.05, 1.0);
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

void _fillLinePattern(Uint8List data, int size, int thickness) {
  const spacing = 6;
  for (int y = 0; y < size; y++) {
    if ((y % spacing) >= thickness) continue;
    for (int x = 0; x < size; x++) {
      data[(y * size + x) * 4 + 3] = 255;
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
  if (name.contains('三角')) {
    return _regularPolygon(c, r, 3, rotation: -math.pi / 2);
  }
  if (name.contains('五角')) {
    return _regularPolygon(c, r, 5, rotation: -math.pi / 2);
  }
  if (name.contains('六角')) return _regularPolygon(c, r, 6);
  if (name.contains('星')) return _star(c, r, r * 0.42, 5);
  if (name.contains('ハート')) return _heart(c, r);
  if (name.contains('吹き出し')) return _speechBubble(c, r);
  if (name.contains('矢印')) return _arrow(c, r);
  return ui.Path()..addOval(ui.Rect.fromCircle(center: c, radius: r));
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
