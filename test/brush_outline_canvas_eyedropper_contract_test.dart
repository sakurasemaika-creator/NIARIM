import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canvas root wires brush outline eyedropper into composite sampling', () {
    final source = File('lib/screens/canvas/canvas_screen.dart').readAsStringSync();

    expect(source, contains('_pendingBrushOutlineEyedropper'));
    expect(source, contains('onEyedropOutlineColor: _startBrushOutlineEyedropper'));
    expect(source, contains('_pendingBrushOutlineEyedropper?.complete(color.toARGB32())'));
    expect(source, contains('_brushOutlineEyedropperActive'));
  });
}
