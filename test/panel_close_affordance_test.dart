import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('floating tool panels use a small top-right close affordance', () {
    final source = File(
      'lib/screens/canvas/widgets/panel_close_bar.dart',
    ).readAsStringSync();

    expect(source, contains('Alignment.centerRight'));
    expect(source, contains('Icons.close, size: 18'));
    expect(source, contains('minWidth: 44'));
    expect(source, contains('minHeight: 44'));
    expect(source, isNot(contains('return Center(')));
  });

  test('mobile floating panels dismiss when tapping outside', () {
    final source = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();

    expect(source, contains('if (_anyToolPanelOpen && !isDesktop)'));
    expect(source, contains('Positioned.fill('));
    expect(source, contains('behavior: HitTestBehavior.opaque'));
    expect(source, contains('onTap: () => setState(_closeAllOverlayPanels)'));
  });
}
