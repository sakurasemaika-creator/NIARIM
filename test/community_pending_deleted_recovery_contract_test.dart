import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleted or missing pending YouTube videos are made unrecoverable', () {
    final source = File(
      'lib/screens/community/community_post_screen.dart',
    ).readAsStringSync();

    expect(source, contains("work.youtubePrivacyStatus == 'deleted'"));
    expect(source, contains("error.code == 'VIDEO_NOT_FOUND'"));
    expect(source, contains('await _markPendingVideoUnavailable();'));
    expect(source, contains('await _clearPendingUpload();'));
    expect(
      source,
      contains('このvideoIdのNIARIM登録は再試行できません'),
      reason: '削除済み／見つからない保留動画を再試行可能と誤案内しない',
    );
  });
}
