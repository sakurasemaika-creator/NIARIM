import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeline mode switch uses a Material icon instead of emoji', () {
    final source = File(
      'lib/screens/canvas/widgets/frame_strip_widget.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('frameStripTimelineButton')"));
    expect(source, contains('Icons.movie_filter_outlined'));
    expect(source, contains("ValueKey('frameStripTimelineArrow')"));
    expect(source, contains('Icons.chevron_right_rounded'));
    expect(source, isNot(contains('🎞')));
  });
}
