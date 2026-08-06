import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/stamp.dart';
import '../models/tone.dart';

/// [Tone.texturePath] / [Stamp.imagePath] が未設定（アプリ組み込みの初期
/// トーン・スタンプにはテクスチャ画像が同梱されていない）の場合に、名前から
/// 簡易的な代替テクスチャを生成するユーティリティ。
/// ユーザーが画像を登録した場合は、そちらの読み込み（未実装・将来対応）を
/// 優先すべきだが、当面はこの生成結果をフォールバックとして使う。

/// 組み込みトーン向けの簡易パターン（網点／ライン）を生成する。
Uint8List generateBuiltInToneTexture(Tone tone, {int size = 64}) {
  final data = Uint8List(size * size * 4);
  final name = tone.name;
  if (name.contains('網点')) {
    final percent =
        int.tryParse(RegExp(r'(\d+)%').firstMatch(name)?.group(1) ?? '30') ?? 30;
    _fillDotPattern(data, size, percent / 100.0);
  } else if (name.contains('ライン')) {
    _fillLinePattern(data, size, name.contains('太') ? 3 : 1);
  } else {
    _fillDotPattern(data, size, 0.3);
  }
  return data;
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

/// 組み込みスタンプ向けの簡易図形（三角形・五角形・六角形・星・ハート・
/// 吹き出し・矢印）をラスタライズして返す。スタンプは現在色を使わず自身の
/// 色情報を保持する仕様（仕様書17）のため、固定色（黒）で焼き込む。
Future<Uint8List> generateBuiltInStampTexture(Stamp stamp, {int size = 128}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFF222222);
  canvas.drawPath(_shapePathForName(stamp.name, size.toDouble()), paint);
  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return byteData!.buffer.asUint8List();
}

ui.Path _shapePathForName(String name, double s) {
  final c = ui.Offset(s / 2, s / 2);
  final r = s * 0.42;
  if (name.contains('三角')) return _regularPolygon(c, r, 3, rotation: -math.pi / 2);
  if (name.contains('五角')) return _regularPolygon(c, r, 5, rotation: -math.pi / 2);
  if (name.contains('六角')) return _regularPolygon(c, r, 6);
  if (name.contains('星')) return _star(c, r, r * 0.42, 5);
  if (name.contains('ハート')) return _heart(c, r);
  if (name.contains('吹き出し')) return _speechBubble(c, r);
  if (name.contains('矢印')) return _arrow(c, r);
  return ui.Path()..addOval(ui.Rect.fromCircle(center: c, radius: r));
}

ui.Path _regularPolygon(ui.Offset c, double r, int sides, {double rotation = 0}) {
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
  path.cubicTo(c.dx - r * 1.4, c.dy - r * 0.3, c.dx - r * 0.5, c.dy - r * 1.3, c.dx, c.dy - r * 0.5);
  path.cubicTo(c.dx + r * 0.5, c.dy - r * 1.3, c.dx + r * 1.4, c.dy - r * 0.3, c.dx, c.dy + r * 0.8);
  path.close();
  return path;
}

ui.Path _speechBubble(ui.Offset c, double r) {
  final rect =
      ui.Rect.fromCenter(center: ui.Offset(c.dx, c.dy - r * 0.15), width: r * 1.8, height: r * 1.3);
  final body = ui.Path()..addRRect(ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(r * 0.25)));
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
