import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';

import '../test/font_coverage_test.dart'
    show cmapCodePoints, handWrittenL10nCharsOf, handWrittenLibFiles;
import '../test/helpers/load_app_fonts.dart';

/// Draws Kuramubon before and after `tool/build_kuramubon_font.py` with the
/// engine's own text renderer and fails if a single pixel or line metric
/// differs.
///
/// Run with:
/// git show 367d8b07:assets/fonts/Kuramubon.otf > /tmp/Kuramubon-original.otf
/// KURAMUBON_BEFORE=/tmp/Kuramubon-original.otf \
///   flutter test tool/compare_kuramubon_render_test.dart
///
/// `KURAMUBON_AFTER` defaults to assets/fonts/Kuramubon.otf.
///
/// Compared:
///   - every character the font maps, one per cell, at a few sizes;
///   - every character of the 7 ARB files and the lib/ string literals that
///     the font maps, one per cell, at every size the app uses (also times
///     the 1.3x and 2x text scale and phone pixel ratios, and sizes Skia
///     draws as paths), regular and bold, at quarter-pixel offsets
///     (Kuramubon declares weight 900, so the engine draws bold headings with
///     the same glyphs and no synthetic bold; bold is compared in case that
///     changes);
///   - every ARB value laid out with the heading fallback list, in all the
///     weights the app uses (image bytes and line metrics).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kuramubon draws the same before and after', (tester) async {
    final beforePath = Platform.environment['KURAMUBON_BEFORE'];
    if (beforePath == null) {
      fail('Set KURAMUBON_BEFORE to the font as distributed.');
    }
    final afterPath =
        Platform.environment['KURAMUBON_AFTER'] ?? 'assets/fonts/Kuramubon.otf';
    await loadAppFonts(tester);
    await tester.runAsync(() async {
      for (final (family, path) in [
        (_before, beforePath),
        (_after, afterPath),
      ]) {
        final bytes = File(path).readAsBytesSync();
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });

    final mapped = cmapCodePoints(afterPath);
    expect(cmapCodePoints(beforePath), mapped);
    bool drawable(int r) =>
        r > 0x20 && !(r >= 0xD800 && r <= 0xDFFF) && mapped.contains(r);
    final all = mapped.where(drawable).toList()..sort();

    final appChars = <int>{};
    for (final arb in _arbFiles()) {
      appChars.addAll(_arbValues(arb).join().runes);
    }
    for (final file in handWrittenLibFiles()) {
      appChars.addAll(handWrittenL10nCharsOf(file));
    }
    final app = appChars.where(drawable).toList()..sort();
    debugPrint('font maps ${all.length} characters, app uses ${app.length}');

    // The check can see a different face.
    final sample = app.take(60).toList();
    Future<Uint8List> sampleOf(String family) =>
        _drawCells(tester, sample, family, 24, 400, 60, 10);
    expect(
      _same(await sampleOf(_before), await sampleOf('DelaGothicOne')),
      isFalse,
    );

    var cells = 0;
    final differing = <String>[];
    Future<void> compareCells(List<int> runes, double size, int weight) async {
      // The font's glyphs reach 0.53em left of the origin, 1.61em right,
      // 1.41em up and 0.59em down.
      final cell = (size * 2.4).ceil() + 2;
      final columns = (4096 ~/ cell).clamp(1, 64);
      final rows = (4096 ~/ cell).clamp(1, 64);
      final perImage = columns * rows;
      for (var start = 0; start < runes.length; start += perImage) {
        final batch = runes.sublist(
          start,
          (start + perImage).clamp(0, runes.length),
        );
        final before = await _drawCells(
          tester,
          batch,
          _before,
          size,
          weight,
          cell,
          columns,
        );
        final after = await _drawCells(
          tester,
          batch,
          _after,
          size,
          weight,
          cell,
          columns,
        );
        cells += batch.length;
        if (_same(before, after)) continue;
        final width = columns * cell;
        for (var i = 0; i < batch.length; i++) {
          if (!_sameCell(before, after, width, i, cell, columns)) {
            differing.add(
              'U+${batch[i].toRadixString(16).toUpperCase()} '
              '${size}px w$weight',
            );
          }
        }
      }
    }

    for (final size in _allCharSizes) {
      for (final weight in const [400, 700]) {
        await compareCells(all, size, weight);
      }
    }
    for (final size in _appSizes) {
      for (final weight in const [400, 700]) {
        await compareCells(app, size, weight);
      }
    }
    debugPrint('compared $cells glyph cells');

    var paragraphs = 0;
    for (final arb in _arbFiles()) {
      final values = _arbValues(arb);
      for (var start = 0; start < values.length; start += 40) {
        final text = values
            .sublist(start, (start + 40).clamp(0, values.length))
            .join('\n');
        for (final (size, weight) in _stringStyles) {
          final before = await _drawText(tester, text, _before, size, weight);
          final after = await _drawText(tester, text, _after, size, weight);
          paragraphs++;
          if (before.metrics != after.metrics ||
              !_same(before.pixels, after.pixels)) {
            differing.add(
              '${arb.uri.pathSegments.last} values $start- ${size}px w$weight',
            );
          }
        }
      }
    }
    debugPrint('compared $paragraphs paragraphs of ARB values');

    expect(cells, greaterThan(100000));
    expect(differing, isEmpty, reason: differing.take(40).join('\n'));
  }, timeout: const Timeout(Duration(minutes: 60)));
}

const _before = 'KuramubonBefore';
const _after = 'KuramubonAfter';

/// Sizes for every character the font maps.
const _allCharSizes = <double>[12, 16, 24, 42];

/// The sizes the app draws headings at (lib/ fontSize values, the Material
/// text theme), times the 1.3x and 2x text scale and the usual phone pixel
/// ratios (2.625, 3), and sizes above 256px that Skia draws as paths.
const _appSizes = <double>[
  8, 9, 10, 11, 11.5, 12, 12.5, 13, 14, 14.3, 15, 16, 17, 18, 18.2, 19, 20, //
  20.8, 22, 24, 28, 28.6, 31.2, 32, 36, 36.75, 38, 42, 45, 48, 57, 63, 72, //
  76, 96, 114, 150, 171, 300,
];

const _stringStyles = <(double, int)>[
  (14, 400),
  (14, 700),
  (16, 500),
  (16, 600),
  (16, 800),
  (16, 900),
  (22, 400),
  (22, 700),
  (42, 700),
];

List<File> _arbFiles() =>
    Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

List<String> _arbValues(File arb) {
  final data = json.decode(arb.readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final entry in data.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        (entry.value as String).replaceAll(RegExp(r'\{[^}]*\}'), ''),
  ];
}

ui.FontWeight _weight(int value) =>
    ui.FontWeight.values.firstWhere((w) => w.value == value);

Future<Uint8List> _drawCells(
  WidgetTester tester,
  List<int> runes,
  String family,
  double size,
  int weight,
  int cell,
  int columns,
) async {
  final rows = (runes.length + columns - 1) ~/ columns;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var i = 0; i < runes.length; i++) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family))
      ..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xFF000000),
          fontFamily: family,
          fontFamilyFallback: const [],
          fontSize: size,
          fontWeight: _weight(weight),
        ),
      )
      ..addText(String.fromCharCode(runes[i]));
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: cell.toDouble()));
    // Quarter-pixel offsets reach every subpixel glyph image.
    final shift = (i % 4) * 0.25;
    canvas.drawParagraph(
      paragraph,
      ui.Offset(
        (i % columns) * cell + size * 0.6 + shift,
        (i ~/ columns) * cell + size * 0.6 + shift,
      ),
    );
    paragraph.dispose();
  }
  final picture = recorder.endRecording();
  final bytes = await tester.runAsync(() async {
    final image = await picture.toImage(columns * cell, rows * cell);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  picture.dispose();
  return bytes!;
}

Future<({Uint8List pixels, String metrics})> _drawText(
  WidgetTester tester,
  String text,
  String family,
  double size,
  int weight,
) async {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family))
    ..pushStyle(
      ui.TextStyle(
        color: const ui.Color(0xFF000000),
        fontFamily: family,
        fontFamilyFallback: kHeadingFontFallback,
        fontSize: size,
        fontWeight: _weight(weight),
      ),
    )
    ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 900));
  final metrics = [
    paragraph.width,
    paragraph.height,
    paragraph.longestLine,
    paragraph.alphabeticBaseline,
    for (final line in paragraph.computeLineMetrics())
      '${line.left} ${line.width} ${line.ascent} ${line.descent} '
          '${line.baseline} ${line.lineNumber}',
  ].join('|');
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
  final width = 900;
  final height = paragraph.height.ceil().clamp(1, 1 << 16);
  paragraph.dispose();
  final picture = recorder.endRecording();
  final pixels = await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  picture.dispose();
  return (pixels: pixels!, metrics: metrics);
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  final x = Uint64List.sublistView(a, 0, a.length ~/ 8 * 8);
  final y = Uint64List.sublistView(b, 0, b.length ~/ 8 * 8);
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  for (var i = x.length * 8; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameCell(
  Uint8List a,
  Uint8List b,
  int width,
  int index,
  int cell,
  int columns,
) {
  final x0 = (index % columns) * cell;
  final y0 = (index ~/ columns) * cell;
  for (var y = y0; y < y0 + cell; y++) {
    for (var x = x0; x < x0 + cell; x++) {
      final i = (y * width + x) * 4;
      for (var c = 0; c < 4; c++) {
        if (a[i + c] != b[i + c]) return false;
      }
    }
  }
  return true;
}
