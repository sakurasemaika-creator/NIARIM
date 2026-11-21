import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_filename.dart';

void main() {
  final time = DateTime(2026, 11, 20, 14, 30);
  test('project names and frame numbers remain readable when shared', () {
    expect(exportFilenameStem("月明かりの谷", time), '月明かりの谷 20261120-143000');
    expect(
      exportFilenameStem("Studio 2's reel", time, frameIndex: 2),
      "Studio 2's reel F003 20261120-143000",
    );
  });
  test('keeps names portable and handles missing or unreadable titles', () {
    expect(
      exportFilenameStem(' ../雨/風:*?"<>|\\\u202E ', time),
      '雨 風 20261120-143000',
    );
    expect(exportFilenameStem('CON.old', time), '_CON.old 20261120-143000');
    expect(
      exportFilenameStem('...', time),
      'niarim_${time.millisecondsSinceEpoch}',
    );
    expect(
      exportFilenameStem(null, time, frameIndex: 0),
      'niarim_frame_${time.millisecondsSinceEpoch}',
    );
  });
  test('byte limits keep emoji sequences and combining marks intact', () {
    final prefix = 'a' * 153;
    final title = '$prefix👩🏽‍🎨';
    expect(exportFilenameStem(title, time), '$prefix 20261120-143000');
    final longTitle = '青' * 100;
    expect(
      utf8.encode(exportFilenameStem(longTitle, time)).length,
      lessThan(180),
    );
  });
}
