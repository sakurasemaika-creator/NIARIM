import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/widgets/filter_sample_preview.dart';

/// Each filter card shows what the filter does with its settings, on a
/// sample picture: every built-in filter's sample differs from the plain
/// sample (except the identity ones), and changes with its settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const w = kFilterSampleWidth, h = kFilterSampleHeight;
  final filters = FilterService.builtInFilters;
  final pictures = {for (final f in filters) f.id: filterSamplePixels(f)};

  int differing(List<int> a, List<int> b) {
    var n = 0;
    for (var i = 0; i < a.length; i += 4) {
      if ((a[i] - b[i]).abs() +
              (a[i + 1] - b[i + 1]).abs() +
              (a[i + 2] - b[i + 2]).abs() >
          12) {
        n++;
      }
    }
    return n;
  }

  test('every filter shows its effect on the sample', () {
    // The plain sample: a tone curve with a custom curve that changes
    // nothing.
    final plain = filterSamplePixels(
      const FilterDef(
        id: 'plain',
        name: 'plain',
        kind: FilterKind.toneCurve,
        toneCurvePoints: [0, 0, 1, 1],
      ),
    );
    for (final f in filters) {
      final p = pictures[f.id]!;
      expect(p.length, w * h * 4);
      // The line-art samples are pictures of their own.
      if (f.kind == FilterKind.inkPool ||
          f.kind == FilterKind.autoLineart ||
          f.kind == FilterKind.prism ||
          f.kind == FilterKind.backgroundBlend) {
        continue;
      }
      expect(differing(p, plain), greaterThan(40), reason: f.name);
    }
  });

  test('the sample follows the settings', () {
    final blur = filters.firstWhere((f) => f.kind == FilterKind.gaussianBlur);
    expect(
      differing(
        filterSamplePixels(blur.copyWith(strength: 2)),
        filterSamplePixels(blur.copyWith(strength: 12)),
      ),
      greaterThan(200),
    );
  });

  tearDownAll(() {
    // A sheet of every sample, for review.
    const columns = 6, scale = 2;
    final rows = (filters.length + columns - 1) ~/ columns;
    final sheet = img.Image(
      width: columns * (w + 4) * scale,
      height: rows * (h + 4) * scale,
    );
    img.fill(sheet, color: img.ColorRgb8(200, 200, 210));
    for (var k = 0; k < filters.length; k++) {
      final p = pictures[filters[k].id]!;
      final ox = (k % columns) * (w + 4), oy = (k ~/ columns) * (h + 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          for (var s = 0; s < scale * scale; s++) {
            sheet.setPixelRgb(
              (ox + x) * scale + s % scale,
              (oy + y) * scale + s ~/ scale,
              p[i],
              p[i + 1],
              p[i + 2],
            );
          }
        }
      }
    }
    final dir = Directory('build/filter-samples')..createSync(recursive: true);
    File('${dir.path}/all.png').writeAsBytesSync(img.encodePng(sheet));
    File('${dir.path}/order.txt').writeAsStringSync(
      [for (final f in filters) '${f.id} ${f.name}'].join('\n'),
    );
  });
}
