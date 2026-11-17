import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editor mode switches are in the top bars', () {
    final canvas = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();
    final timeline = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();
    final strip = File(
      'lib/screens/canvas/widgets/frame_strip_widget.dart',
    ).readAsStringSync();

    expect("canvasTimelineModeButton".allMatches(canvas), hasLength(1));
    expect(canvas, contains('Icons.movie_filter_outlined'));
    expect(timeline, contains('tooltip: l10n.timelineBackToCanvasTooltip'));
    expect(strip, isNot(contains('onTimelineTap')));
    expect(strip, isNot(contains('Icons.movie_filter_outlined')));
  });
}
