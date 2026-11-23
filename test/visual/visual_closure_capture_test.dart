// 見た目の締め（全面監査のD029）の素材を作る。
//
// 組み込みの描画フィルター・ブラシ・トーン・スタンプ・テーマと、ブラシの
// 設定（縁取りペン・折り畳みの5種・入り抜き・先端の形・混色ほか）を1件ずつ、
// 「前（BEFORE）」「設定（SETTINGS）」「後（AFTER）」の組として
// build/visual-closure/ に画像と manifest.json で書く。PDFにするのは
// tool/build_visual_closure_pdf.py（名前・ID・設定を頁に書き込む）。
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/filter_preview.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/load_app_fonts.dart';

const _w = 480, _h = 270;
final _out = Directory('build/visual-closure');
final _manifest = <Map<String, Object?>>[];

/// A small character drawing on a transparent layer: lines, flat colours
/// and a soft shadow, so every filter has something to act on.
Future<Uint8List> _sampleLayer() async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  final line = Paint()
    ..color = const Color(0xFF2B2A3A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  c.drawRect(
    const Rect.fromLTWH(150, 170, 180, 100),
    Paint()..color = const Color(0xFFE5483D),
  );
  c.drawCircle(
    const Offset(240, 110),
    70,
    Paint()..color = const Color(0xFFF7D9C4),
  );
  c.drawArc(
    Rect.fromCircle(center: const Offset(240, 100), radius: 78),
    math.pi,
    math.pi,
    true,
    Paint()..color = const Color(0xFF5B3A29),
  );
  c.drawCircle(const Offset(240, 110), 70, line);
  c.drawCircle(const Offset(215, 115), 8, Paint()..color = Colors.black);
  c.drawCircle(const Offset(265, 115), 8, Paint()..color = Colors.black);
  c.drawArc(
    Rect.fromCenter(center: const Offset(240, 140), width: 40, height: 22),
    0.2,
    math.pi - 0.4,
    false,
    line..strokeWidth = 4,
  );
  c.drawLine(const Offset(40, 250), const Offset(440, 230), line);
  c.drawOval(
    const Rect.fromLTWH(360, 60, 80, 50),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF3AA6FF), Color(0x003AA6FF)],
      ).createShader(const Rect.fromLTWH(360, 60, 80, 50)),
  );
  final image = await recorder.endRecording().toImage(_w, _h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Line art only (the input the ink pool and auto line-art filters expect):
/// a head, a collar crossing at a corner, and an X.
Future<Uint8List> _lineSample() async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  final line = Paint()
    ..color = const Color(0xFF2B2A3A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  c.drawCircle(const Offset(200, 110), 70, line);
  c.drawLine(const Offset(120, 200), const Offset(200, 175), line);
  c.drawLine(const Offset(200, 175), const Offset(280, 200), line);
  c.drawLine(const Offset(200, 175), const Offset(200, 260), line);
  c.drawLine(const Offset(330, 60), const Offset(440, 200), line);
  c.drawLine(const Offset(440, 60), const Offset(330, 200), line);
  final image = await recorder.endRecording().toImage(_w, _h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// [rgba] (premultiplied, [w]×[h]) on white, as a PNG file.
void _writeOnWhite(String path, Uint8List rgba, int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var i = 0, p = 0; p < w * h; p++, i += 4) {
    final a = rgba[i + 3];
    // Premultiplied over white: c + (255 - a).
    image.setPixelRgb(
      p % w,
      p ~/ w,
      (rgba[i] + 255 - a).clamp(0, 255),
      (rgba[i + 1] + 255 - a).clamp(0, 255),
      (rgba[i + 2] + 255 - a).clamp(0, 255),
    );
  }
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}

String _settings(Map<String, dynamic> json, Set<String> skip) {
  final parts = <String>[];
  json.forEach((key, value) {
    if (skip.contains(key) || value == null) return;
    if (value is Map || value is List) return;
    // Colours (ARGB integers) are written the usual way.
    parts.add(
      value is int && value > 0xFFFFFF && key.toLowerCase().contains('color')
          ? '$key=#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}'
          : '$key=$value',
    );
  });
  return parts.take(10).join(', ');
}

/// The filter's kind and the values that differ from a plain filter of the
/// same kind (the settings that make this preset what it is).
String _filterSettings(FilterDef filter) {
  final plain = FilterDef(
    id: filter.id,
    name: filter.name,
    kind: filter.kind,
  ).toJson();
  final changed = <String>[];
  filter.toJson().forEach((key, value) {
    if ({'id', 'name', 'kind', 'tags', 'isFavorite'}.contains(key)) return;
    if (value is Map || value is List) return;
    if (plain[key] != value) changed.add('$key=$value');
  });
  return 'kind=${filter.kind.name}'
      '${changed.isEmpty ? '（その種類の既定の値）' : ', ${changed.join(', ')}'}';
}

void _add(
  String kind,
  String id,
  String name,
  String settings,
  String? before,
  String after,
) {
  _manifest.add({
    'kind': kind,
    'id': id,
    'name': name,
    'settings': settings,
    'before': before,
    'after': after,
  });
}

/// The pixels of [strokes] drawn one after another with [brush] (over a
/// red band first when [overRed], for the colour-mixing modes).
Future<Uint8List> _drawStrokes(
  WidgetTester tester,
  Brush brush,
  List<List<Offset>> strokes, {
  bool overRed = false,
  Color color = const Color(0xFF2B2A3A),
}) async => (await tester.runAsync(() async {
  final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
  try {
    final engine = DrawingEngine(tileManager: tm)..pressureEnabled = false;
    void draw(Brush b, Color c, List<Offset> points) {
      engine
        ..currentBrush = b
        ..currentColor = c;
      // Like the canvas: the first pass is taken back before the final one
      // (a custom fade-out and an outline's 強弱 need the whole stroke).
      tm.beginUndoRecording('l');
      engine.beginStroke(
        StrokePoint(x: points.first.dx, y: points.first.dy),
        'l',
      );
      for (final p in points.skip(1)) {
        engine.continueStroke(StrokePoint(x: p.dx, y: p.dy), 'l');
      }
      final firstPass = tm.endUndoRecording();
      if (engine.needsFinalFadeReplay) {
        tm.applyTileSnapshot('l', firstPass.before);
        engine.replayCurrentStrokeWithFinalFade();
      }
      engine.endStroke();
    }

    if (overRed) {
      draw(
        BrushService.builtInBrushes.first.copyWith(size: 90, opacity: 100),
        const Color(0xFFE5483D),
        [for (var x = 60.0; x <= 420; x += 6) Offset(x, 135)],
      );
    }
    for (final points in strokes) {
      draw(brush, color, points);
    }
    final image = await tm.compositeLayerToImage('l');
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  } finally {
    tm.dispose();
  }
}))!;

/// A wave from left to right (the stroke used for every brush).
List<Offset> _wave() => [
  for (var x = 40.0; x <= 440; x += 4)
    Offset(
      x,
      200 -
          120 * math.sin((x - 40) / 400 * math.pi) +
          20 * math.sin((x - 40) / 400 * 9),
    ),
];

/// A zigzag with sharp turns, where hair folds.
List<Offset> _zigzag() {
  const corners = [
    Offset(40, 220),
    Offset(130, 60),
    Offset(210, 220),
    Offset(300, 60),
    Offset(380, 220),
    Offset(440, 120),
  ];
  return [
    for (var i = 0; i + 1 < corners.length; i++)
      for (var t = 0.0; t < 1; t += 0.05)
        Offset.lerp(corners[i], corners[i + 1], t)!,
    corners.last,
  ];
}

/// A round curl (a C that comes back), for the crescent fold.
List<Offset> _curl() => [
  for (var a = 0.0; a <= 1.6 * math.pi; a += 0.06)
    Offset(240 + 100 * math.cos(a + math.pi), 135 - 90 * math.sin(a + math.pi)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() => _out.createSync(recursive: true));
  tearDownAll(
    () => File(
      '${_out.path}/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_manifest)),
  );

  testWidgets('描画フィルター：前・設定・後', (tester) async {
    final picture = (await tester.runAsync(_sampleLayer))!;
    final lines = (await tester.runAsync(_lineSample))!;
    final pictureBefore = '${_out.path}/filter/_before.png';
    final linesBefore = '${_out.path}/filter/_before_lines.png';
    _writeOnWhite(pictureBefore, picture, _w, _h);
    _writeOnWhite(linesBefore, lines, _w, _h);
    for (final filter in FilterService.builtInFilters) {
      final onLines =
          filter.kind == FilterKind.inkPool ||
          filter.kind == FilterKind.autoLineart;
      final sample = onLines ? lines : picture;
      final before = onLines ? linesBefore : pictureBefore;
      final after = runFilterPreview((
        filter: filter,
        data: sample,
        width: _w,
        height: _h,
        scale: 1,
        canvasWidth: _w,
        canvasHeight: _h,
        mask: null,
        background: null,
        frameIndex: 0,
      ));
      expect(after.length, sample.length, reason: filter.id);
      final path = '${_out.path}/filter/${filter.id}.png';
      _writeOnWhite(path, after, _w, _h);
      _add(
        'filter',
        filter.id,
        filter.name,
        _filterSettings(filter),
        before,
        path,
      );
    }
  });

  testWidgets('ブラシ：前（白紙）・設定・後（線）', (tester) async {
    final blank = Uint8List(_w * _h * 4);
    final before = '${_out.path}/brush/_before.png';
    _writeOnWhite(before, blank, _w, _h);
    for (final brush in BrushService.builtInBrushes) {
      final pixels = await _drawStrokes(tester, brush, [_wave()]);
      final path = '${_out.path}/brush/${brush.id}.png';
      _writeOnWhite(path, pixels, _w, _h);
      _add(
        'brush',
        brush.id,
        brush.name,
        'size=${brush.size}, opacity=${brush.opacity}, '
            'pixelMode=${brush.pixelMode}, scatter=${brush.scatter}',
        before,
        path,
      );
    }
  });

  testWidgets('ブラシの設定：縁取りペン・折り畳み5種・入り抜き・先端・混色', (tester) async {
    final pen = BrushService.builtInBrushes.first;
    final blank = '${_out.path}/brush/_before.png';
    final redBefore = '${_out.path}/brushmode/_before_red.png';
    _writeOnWhite(
      redBefore,
      await _drawStrokes(tester, pen, const [], overRed: true),
      _w,
      _h,
    );
    final outlined = pen.copyWith(
      size: 26,
      outlineEnabled: true,
      outlineWidth: 3,
      outlineColor: 0xFF2B2A3A,
    );
    const fill = Color(0xFFF2C14E);
    final crossing = [
      _wave(),
      [for (var x = 40.0; x <= 440; x += 4) Offset(x, 60 + (x - 40) * 0.4)],
    ];
    final cases = <(String, String, Brush, List<List<Offset>>, Color, bool)>[
      ('outline_w3', '縁取りペン（縁取り幅3）', outlined, [_wave()], fill, false),
      (
        'outline_w8',
        '縁取りペン（縁取り幅8）',
        outlined.copyWith(outlineWidth: 8),
        [_wave()],
        fill,
        false,
      ),
      (
        'outline_keep_on',
        '縁取りペン（重なりを維持：オン）',
        outlined.copyWith(outlineKeepOverlap: true),
        crossing,
        fill,
        false,
      ),
      (
        'outline_keep_off',
        '縁取りペン（重なりを維持：オフ）',
        outlined.copyWith(outlineKeepOverlap: false),
        crossing,
        fill,
        false,
      ),
      (
        'outline_accent',
        '縁取りペン（強弱：頂点の縁取り幅9）',
        outlined.copyWith(outlineAccentEnabled: true, outlineAccentWidth: 9),
        [_zigzag()],
        fill,
        false,
      ),
      for (final mode in HairFoldMode.values)
        (
          'fold_${mode.name}',
          '折り畳み（${mode.name}）',
          outlined.copyWith(foldEnabled: true, foldMode: mode),
          [mode == HairFoldMode.crescent ? _curl() : _zigzag()],
          fill,
          false,
        ),
      for (final fade in FadeMode.values)
        (
          'fade_${fade.name}',
          '入り抜き（${fade.name}）',
          pen.copyWith(
            size: 22,
            fadeMode: fade,
            fadeIn: const FadeEndpointSettings(value: 0, rangePx: 120),
            fadeOut: const FadeEndpointSettings(value: 0, rangePx: 220),
          ),
          [_wave()],
          const Color(0xFF2B2A3A),
          false,
        ),
      for (final tip in BrushTipShape.values)
        (
          'tip_${tip.name}',
          '先端の形（${tip.name}）',
          pen.copyWith(size: 24, tipShape: tip),
          [_wave()],
          const Color(0xFF2B2A3A),
          false,
        ),
      (
        'lateral3',
        '横に並べる（3本）',
        pen.copyWith(
          size: 10,
          lateralRepeatEnabled: true,
          lateralRepeatCount: 3,
          lateralRepeatSpacing: 2,
        ),
        [_wave()],
        const Color(0xFF2B2A3A),
        false,
      ),
      (
        'scatter',
        '散布（0.8）',
        pen.copyWith(size: 14, scatter: 0.8),
        [_wave()],
        const Color(0xFF2B2A3A),
        false,
      ),
      (
        'pixel',
        'ピクセルモード',
        pen.copyWith(size: 12, pixelMode: true),
        [_wave()],
        const Color(0xFF2B2A3A),
        false,
      ),
      for (final mode in BrushMixingMode.values)
        (
          'mix_${mode.name}',
          '混色（${mode.name}、混色度合い60）',
          pen.copyWith(
            size: 30,
            pressureOff: pen.pressureOff.copyWith(
              mixing: PressureMixingOffSetting(
                enabled: mode != BrushMixingMode.off,
                mode: mode,
                rate: 60,
              ),
            ),
          ),
          [
            [
              for (var y = 30.0; y <= 240; y += 4)
                Offset(240 + (y - 30) * 0.3, y),
            ],
          ],
          const Color(0xFF2E5BD8),
          true,
        ),
    ];
    for (final (id, name, brush, strokes, color, overRed) in cases) {
      final pixels = await _drawStrokes(
        tester,
        brush,
        strokes,
        overRed: overRed,
        color: color,
      );
      expect(pixels.any((v) => v != 0), isTrue, reason: id);
      final path = '${_out.path}/brushmode/$id.png';
      _writeOnWhite(path, pixels, _w, _h);
      final json = brush.toJson();
      final base = pen.toJson();
      final changed = <String>[
        for (final e in json.entries)
          if (e.key != 'id' &&
              e.key != 'name' &&
              jsonEncode(e.value) != jsonEncode(base[e.key]))
            '${e.key}=${e.value is Map ? jsonEncode(e.value) : e.value}',
      ];
      _add(
        'brushmode',
        id,
        name,
        '基のブラシ=${pen.name}（${pen.id}）, 色=#${color.toARGB32().toRadixString(16).toUpperCase()}, ${changed.join(', ')}',
        overRed ? redBefore : blank,
        path,
      );
    }
  });

  test('トーン・スタンプ：設定・後', () async {
    final tones = ToneService();
    await tones.init();
    final builtInTones = [
      for (final tone in tones.tones)
        if (tones.isBuiltIn(tone.id)) tone,
    ];
    await Future.wait(builtInTones.map(ensureToneTextureLoaded));
    for (final tone in builtInTones) {
      final path = '${_out.path}/tone/${tone.id}.png';
      _writeOnWhite(
        path,
        generateBuiltInToneTexture(tone, size: 128),
        128,
        128,
      );
      _add(
        'tone',
        tone.id,
        tone.name,
        _settings(tone.toJson(), {'id', 'name', 'tags'}),
        null,
        path,
      );
    }
    final stamps = StampService();
    await stamps.init();
    for (final stamp in stamps.stamps) {
      if (!stamps.isBuiltIn(stamp.id)) continue;
      final path = '${_out.path}/stamp/${stamp.id}.png';
      _writeOnWhite(path, await generateBuiltInStampTexture(stamp), 128, 128);
      _add(
        'stamp',
        stamp.id,
        stamp.name,
        _settings(stamp.toJson(), {'id', 'name', 'tags'}),
        null,
        path,
      );
    }
  });

  testWidgets('テーマ：設定（9色）・後（画面の部品）', (tester) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(360, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = ThemeService();
    await tester.runAsync(service.init);
    final key = GlobalKey();
    for (final preset in [
      for (final p in service.presets)
        if (ThemeService.isBuiltInPreset(p.id)) p,
    ]) {
      service.restoreCurrent(preset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: service.themeData,
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              appBar: AppBar(title: const Text('NIARIM')),
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('保存')),
                    OutlinedButton(onPressed: () {}, child: const Text('取消')),
                    const Chip(label: Text('タグ')),
                    Switch(value: true, onChanged: (_) {}),
                    const Text('本文の文字 Body text'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
      final path = '${_out.path}/theme/${preset.id}.png';
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      _add(
        'theme',
        preset.id,
        preset.name,
        _settings(preset.toJson(), {'id', 'name'}),
        null,
        path,
      );
    }
    service.dispose();
  });
}
