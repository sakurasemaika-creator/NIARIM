import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('draw-filter mosaic dispatches to classic block averaging', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255,
      0, 0, 255, 0,
      0, 255, 0, 255,
      255, 255, 255, 255,
    ]);
    final filter = FilterDef(
      id: 'mosaic-contract',
      name: 'Mosaic',
      kind: FilterKind.mosaic,
      strength: 2,
    );

    final out = applyDrawFilterInIsolate((input, 2, 2, filter, null));

    expect(out.sublist(0, 4), [128, 128, 128, 191]);
    for (var i = 4; i < out.length; i += 4) {
      expect(out.sublist(i, i + 4), out.sublist(0, 4));
    }
  });
}
