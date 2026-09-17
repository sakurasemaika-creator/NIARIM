import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/models/ruler.dart';

void main() {
  test('snap disabled keeps ruler active but returns freehand point', () {
    final engine = RulerEngine();
    const ruler = Ruler(
      type: RulerType.line,
      position: Offset.zero,
      snapEnabled: false,
      settings: RulerSettings(),
    );
    engine.setActiveRuler(ruler);

    const input = Offset(12, 30);
    expect(engine.activeRuler, same(ruler));
    expect(engine.snapToRuler(input), input);
  });

  test('snap can be re-enabled on the same ruler', () {
    final engine = RulerEngine();
    const base = Ruler(
      type: RulerType.line,
      position: Offset.zero,
      settings: RulerSettings(),
    );
    engine.setActiveRuler(base.copyWith(snapEnabled: false));
    const input = Offset(12, 30);
    expect(engine.snapToRuler(input), input);

    final enabled = engine.activeRuler!.copyWith(snapEnabled: true);
    engine.setActiveRuler(enabled);
    expect(engine.snapToRuler(input), const Offset(12, 0));
  });
}
