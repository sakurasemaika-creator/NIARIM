import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/lasso_line_snap_engine.dart';

void main() {
  Uint8List image(int w, int h, Iterable<(int, int)> ink) {
    final out = Uint8List(w * h * 4);
    for (final (x, y) in ink) {
      final i = (y * w + x) * 4;
      out[i + 3] = 255;
    }
    return out;
  }

  test('follows the intended contour through a perpendicular crossing', () {
    const w = 80, h = 80;
    final pixels = <(int, int)>[];
    for (var x = 5; x < 75; x++) {
      pixels.add((x, 40));
    }
    for (var y = 5; y < 75; y++) {
      pixels.add((40, y));
    }
    final rgba = image(w, h, pixels);
    final guide = <Offset>[
      for (var x = 8; x <= 72; x += 4) Offset(x.toDouble(), 43),
    ];
    final snapped = const LassoLineSnapEngine().snapPath(
      guide: guide,
      rgba: rgba,
      width: w,
      height: h,
      radius: 8,
    );

    expect(snapped.length, guide.length);
    expect(snapped.every((p) => (p.dy - 40.5).abs() < 1), isTrue);
    for (var i = 1; i < snapped.length; i++) {
      expect(snapped[i].dx, greaterThanOrEqualTo(snapped[i - 1].dx));
    }
  });

  test('coarse rectangle guide is pulled onto nearby line-art boundary', () {
    const w = 64, h = 64;
    final pixels = <(int, int)>[];
    for (var x = 16; x <= 48; x++) {
      pixels.add((x, 16));
      pixels.add((x, 48));
    }
    for (var y = 16; y <= 48; y++) {
      pixels.add((16, y));
      pixels.add((48, y));
    }
    final rgba = image(w, h, pixels);
    final guide = <Offset>[
      const Offset(13, 13),
      const Offset(30, 13),
      const Offset(51, 13),
      const Offset(51, 30),
      const Offset(51, 51),
      const Offset(30, 51),
      const Offset(13, 51),
      const Offset(13, 30),
      const Offset(13, 13),
    ];
    final snapped = const LassoLineSnapEngine().snapPath(
      guide: guide,
      rgba: rgba,
      width: w,
      height: h,
      radius: 6,
    );
    expect(
      snapped
          .where(
            (p) =>
                (p.dx - 16.5).abs() < 1 ||
                (p.dx - 48.5).abs() < 1 ||
                (p.dy - 16.5).abs() < 1 ||
                (p.dy - 48.5).abs() < 1,
          )
          .length,
      greaterThanOrEqualTo(7),
    );
  });

  test(
    'lasso selection exposes a dedicated snap checkbox only for lasso mode',
    () {
      final source = File(
        'lib/screens/canvas/canvas_screen.dart',
      ).readAsStringSync();
      expect(source, contains("ValueKey('lasso-snap-to-lines')"));
      expect(source, contains('_currentTool == DrawingTool.selectLasso'));
      expect(source, contains('l10n.canvasLassoSnapToLines'));
    },
  );
}
