import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame strip uses one circular movie icon button for timeline', () {
    final source = File(
      'lib/screens/canvas/widgets/frame_strip_widget.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('SegmentedButton<String>')));
    expect(source, contains('Icons.movie_filter_outlined'));
    expect(source, contains("ValueKey('frameStripTimelineButton')"));
    expect(source, contains('shape: const CircleBorder()'));
    expect(source, contains('onPressed: widget.onTimelineTap'));
  });
}
