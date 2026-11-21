import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_selection.dart';

/// The helpers that keep a filter inside the canvas selection, and paint the
/// glasses filter's own lens area.
void main() {
  test('the canvas selection becomes full coverage', () {
    final coverage = selectionCoverage(Uint8List.fromList([0, 1, 255, 7]));
    expect(coverage, [0, 255, 255, 255]);
    expect(selectsAnything(coverage), isTrue);
    expect(selectsAnything(Uint8List(4)), isFalse);
    expect(selectsAnything(null), isFalse);
  });

  test('a filter keeps the original outside the selection', () {
    final original = Uint8List.fromList([10, 20, 30, 255, 10, 20, 30, 255]);
    final filtered = Uint8List.fromList([200, 100, 0, 255, 200, 100, 0, 255]);
    final out = restrictToSelection(
      original,
      filtered,
      Uint8List.fromList([255, 0]),
    );
    expect(out.sublist(0, 4), [200, 100, 0, 255]);
    expect(out.sublist(4), [10, 20, 30, 255]);
    // A partly selected edge mixes the two.
    final edge = restrictToSelection(
      original,
      filtered,
      Uint8List.fromList([128, 128]),
    );
    expect(edge[0], closeTo((200 + 10) / 2, 1));
  });

  test('a generated layer is cleared outside the selection', () {
    final pixels = Uint8List.fromList([255, 0, 0, 255, 255, 0, 0, 255]);
    final out = clearOutsideSelection(pixels, Uint8List.fromList([0, 255]));
    expect(out.sublist(0, 4), [0, 0, 0, 0]);
    expect(out.sublist(4), [255, 0, 0, 255]);
  });

  test('a scaled-down selection keeps the share selected', () {
    // 4×2, the left half selected → 2×1: one in, one out.
    final coverage = Uint8List.fromList([255, 255, 0, 0, 255, 255, 0, 0]);
    expect(scaleSelectionCoverage(coverage, 4, 2, 2, 1), [255, 0]);
    // 4×1 with three of four selected → 1×1 at 75 %.
    expect(
      scaleSelectionCoverage(
        Uint8List.fromList([255, 255, 255, 0]),
        4,
        1,
        1,
        1,
      ),
      [191],
    );
  });

  test('coverage and RGBA masks convert both ways', () {
    final rgba = coverageAsRgbaMask(Uint8List.fromList([0, 200]));
    expect(rgba, [0, 0, 0, 0, 200, 200, 200, 200]);
    expect(rgbaMaskCoverage(rgba), [0, 200]);
  });

  test('the lens brush paints and erases a round stroke', () {
    const w = 40, h = 20;
    final coverage = Uint8List(w * h);
    paintCoverageStroke(coverage, w, h, const [(5, 10), (35, 10)], radius: 4);
    int at(int x, int y) => coverage[y * w + x];
    expect(at(5, 10), 255);
    expect(at(20, 10), 255);
    expect(at(35, 10), 255);
    expect(at(20, 13), 255, reason: 'inside the radius');
    expect(at(20, 16), 0, reason: 'outside the radius');
    expect(at(0, 10), 0, reason: 'round end, not beyond it');
    // The eraser takes a hole out of the middle.
    paintCoverageStroke(
      coverage,
      w,
      h,
      const [(20, 10)],
      radius: 3,
      erase: true,
    );
    expect(at(20, 10), 0);
    expect(at(10, 10), 255);
    // Erasing along the whole stroke with the same size leaves nothing,
    // not even the soft edge.
    paintCoverageStroke(
      coverage,
      w,
      h,
      const [(5, 10), (35, 10)],
      radius: 4,
      erase: true,
    );
    expect(coverage.every((c) => c == 0), isTrue);
  });
}
