import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('mosaic averages each block without pixel-art palette processing', () {
    final input = Uint8List.fromList([
      0, 0, 0, 255,
      100, 0, 0, 255,
      0, 100, 0, 255,
      100, 100, 0, 255,
    ]);

    final result = FilterEngine().applyMosaic(
      input,
      2,
      2,
      blockSize: 2,
    );

    expect(
      result,
      Uint8List.fromList(List<int>.generate(4, (_) => 0).expand((_) => [50, 50, 0, 255]).toList()),
    );
  });

  test('draw-filter isolate dispatches mosaic to classic mosaic path', () {
    final input = Uint8List.fromList([
      0, 0, 0, 255,
      100, 0, 0, 255,
      0, 100, 0, 255,
      100, 100, 0, 255,
    ]);
    const filter = FilterDef(
      id: 'mosaic-test',
      name: 'モザイク',
      kind: FilterKind.mosaic,
      strength: 2,
    );

    final result = applyDrawFilterInIsolate((input, 2, 2, filter, null));

    for (var i = 0; i < result.length; i += 4) {
      expect(result.sublist(i, i + 4), [50, 50, 0, 255]);
    }
  });
}
