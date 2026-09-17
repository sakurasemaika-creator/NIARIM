import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/ruler.dart';

void main() {
  const ruler = Ruler(
    type: RulerType.line,
    position: Offset.zero,
    settings: RulerSettings(),
  );

  test('ruler snap is enabled by default', () {
    expect(ruler.snapEnabled, isTrue);
  });

  test('copyWith preserves and toggles snap independently of visibility', () {
    final disabled = ruler.copyWith(snapEnabled: false);
    expect(disabled.snapEnabled, isFalse);
    expect(disabled.isVisible, isTrue);

    final hidden = disabled.copyWith(isVisible: false);
    expect(hidden.snapEnabled, isFalse);
    expect(hidden.isVisible, isFalse);
  });

  test('changing ruler type does not reset snap state', () {
    final changed = ruler
        .copyWith(snapEnabled: false)
        .copyWith(type: RulerType.twoPointPerspective);
    expect(changed.snapEnabled, isFalse);
    expect(changed.type, RulerType.twoPointPerspective);
  });
}
