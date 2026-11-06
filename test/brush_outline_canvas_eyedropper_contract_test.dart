import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'canvas root wires brush outline eyedropper into composite sampling',
    () {
      final source = File(
        'lib/screens/canvas/canvas_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_pendingBrushOutlineEyedropper'));
      expect(
        source,
        contains('onEyedropOutlineColor: _startBrushOutlineEyedropper'),
      );
      expect(
        source,
        contains('pendingBrushOutline.complete(color.toARGB32())'),
      );
      expect(
        source,
        isNot(
          contains(
            '_pendingBrushOutlineEyedropper?.complete(color.toARGB32())',
          ),
        ),
      );
      expect(source, contains('_brushOutlineEyedropperActive'));
    },
  );

  test(
    'brush settings dismisses modal sheet before canvas outline sampling',
    () {
      final source = File(
        'lib/screens/canvas/widgets/brush_panel.dart',
      ).readAsStringSync();

      final methodStart = source.indexOf(
        'Future<void> _eyedropOutlineColor() async',
      );
      expect(methodStart, greaterThanOrEqualTo(0));
      final methodEnd = source.indexOf('\n  late Brush _brush;', methodStart);
      expect(methodEnd, greaterThan(methodStart));
      final method = source.substring(methodStart, methodEnd);

      expect(method, contains('Navigator.of(context).pop();'));
      expect(method, contains('final sampled = await callback();'));
      expect(
        method.indexOf('Navigator.of(context).pop();'),
        lessThan(method.indexOf('final sampled = await callback();')),
      );
      expect(
        method,
        contains('service.updateBrush(draft.copyWith(outlineColor: sampled));'),
      );
    },
  );
}
