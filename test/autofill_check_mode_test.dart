import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/autofill_engine.dart';

void main() {
  test('part separation mode produces distinct opaque high-chroma colors', () {
    final colors = [for (var i = 0; i < 12; i++) autofillCheckColor(AutofillCheckMode.partSeparation, i)];
    expect(colors.toSet().length, 12);
    for (final color in colors) {
      expect((color >> 24) & 0xff, 0xff);
      final channels = [(color >> 16) & 0xff, (color >> 8) & 0xff, color & 0xff];
      expect(channels.reduce((a, b) => a > b ? a : b) - channels.reduce((a, b) => a < b ? a : b), greaterThan(150));
    }
  });

  test('silhouette mode is the exact same low-value achromatic gray for every part', () {
    final colors = [for (var i = 0; i < 20; i++) autofillCheckColor(AutofillCheckMode.silhouette, i)];
    expect(colors.toSet(), {0xFF3D3D3D});
  });

  test('check recolor preserves alpha, transparent pixels, and source bytes', () {
    final source = Uint8List.fromList([10, 20, 30, 0, 40, 50, 60, 64, 70, 80, 90, 255]);
    final before = Uint8List.fromList(source);
    final out = applyAutofillCheckColor(source, 0xFF3D3D3D);
    expect(source, before, reason: 'preview must never mutate production autofill pixels');
    expect(out, [10, 20, 30, 0, 61, 61, 61, 64, 61, 61, 61, 255]);
  });

  test('normal check mode has no override color', () {
    expect(() => autofillCheckColor(AutofillCheckMode.normal, 0), throwsArgumentError);
  });
}
