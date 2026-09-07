import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/community/community_post_screen.dart',
  ).readAsStringSync();

  test('checks existing NIARIM work before requesting YouTube upload scope', () {
    final myWorks = source.indexOf('final ownWorks = await api.myWorks()');
    final youtubeScope = source.indexOf(
      'final youtubeToken = await auth.youtubeUploadAccessToken',
    );

    expect(myWorks, greaterThanOrEqualTo(0));
    expect(youtubeScope, greaterThan(myWorks));
    expect(source, contains('if (work.workId != videoId) continue;'));
    expect(source, contains('recovered: true'));
  });

  test('reconciles the saved NIARIM visibility before clearing recovered state', () {
    final existingWork = source.indexOf('if (work.workId != videoId) continue;');
    final visibilityPatch = source.indexOf(
      'await api.updateWorkVisibility(',
      existingWork,
    );
    final recoveredFinish = source.indexOf(
      'await _finishRegistration(',
      existingWork,
    );

    expect(existingWork, greaterThanOrEqualTo(0));
    expect(visibilityPatch, greaterThan(existingWork));
    expect(recoveredFinish, greaterThan(visibilityPatch));
    expect(
      source,
      contains('work.isNiarimPublished != _isNiarimPublished'),
    );
  });

  test('still requests YouTube scope when pending video is not registered', () {
    expect(
      source,
      contains('ここへ来るのは新規YouTubeアップロード、またはYouTubeには存在するが'),
    );
    expect(source, contains('promptIfNecessary: true'));
    expect(source, contains('await api.createWork('));
  });
}
