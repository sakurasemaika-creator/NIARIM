import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeline exposes split and range cut integration anchors', () {
    final source =
        File('lib/screens/timeline/timeline_screen.dart').readAsStringSync();

    expect(source, contains('_startClipSplitCut'));
    expect(source, contains('_confirmClipSplitCut'));
    expect(source, contains('_startClipRangeCut'));
    expect(source, contains('_confirmClipRangeCut'));
    expect(source, contains('splitTimelineClip('));
    expect(source, contains('cutTimelineClipRange('));
    expect(source, contains('cutPreviewFrame('));
  });
}
