import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/screens/community/community_post_screen.dart',
  ).readAsStringSync();

  test(
    'checks existing NIARIM work before requesting YouTube upload scope',
    () {
      final myWorks = source.indexOf('final ownWorks = await api.myWorks()');
      final youtubeScope = source.indexOf(
        'await auth.youtubeUploadAccessToken',
      );

      expect(myWorks, greaterThanOrEqualTo(0));
      expect(youtubeScope, greaterThan(myWorks));
      expect(source, contains('if (work.workId != videoId) continue;'));
      expect(source, contains('recovered: true'));
    },
  );

  test(
    'reconciles the saved NIARIM visibility before clearing recovered state',
    () {
      final existingWork = source.indexOf(
        'if (work.workId != videoId) continue;',
      );
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
      expect(source, contains('work.isNiarimPublished != _isNiarimPublished'));
    },
  );

  test('keeps NIARIM and YouTube descriptions independent during posting', () {
    expect(source, contains("key: const Key('communityPostDescription')"));
    expect(
      source,
      contains("key: const Key('communityPostYoutubeDescription')"),
    );
    expect(source, contains('description: youtubeDescription,'));
    expect(source, contains('description: description,'));
    expect(source, contains('utf8.encode(youtubeDescription).length > 5000'));
    expect(source, contains('prefs.remove(_pendingYoutubeDescriptionKey)'));
  });

  test('separates both titles and persists YouTube title for recovery', () {
    expect(source, contains("key: const Key('communityPostTitle')"));
    expect(source, contains("key: const Key('communityPostYoutubeTitle')"));
    expect(source, contains('title: youtubeTitle,'));
    expect(source, contains('title: title,'));
    expect(
      source.replaceAll(RegExp(r'\s+'), ' '),
      contains(
        'prefs.readString(_pendingYoutubeTitleKey) ?? _titleController.text',
      ),
    );
    expect(source, contains('prefs.remove(_pendingYoutubeTitleKey)'));
  });

  test('offers four one-tap directional copy controls below the fields', () {
    for (final key in [
      'copyNiarimTitleToYoutube',
      'copyYoutubeTitleToNiarim',
      'copyNiarimDescriptionToYoutube',
      'copyYoutubeDescriptionToNiarim',
    ]) {
      expect(source, contains("key: const Key('$key')"));
    }
    expect(source, contains('youtubeDescription: true,'));
  });

  test(
    'registration retries request upload permission only for a pending thumbnail',
    () {
      final compact = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        compact,
        contains(
          'videoId == null || (_thumbnailFile != null && !_thumbnailApplied)',
        ),
      );
      expect(
        compact,
        contains(
          'needsUpload ? await auth.youtubeUploadAccessToken(promptIfNecessary: true) : await auth.youtubeReadAccessToken(promptIfNecessary: true)',
        ),
      );
      expect(source, contains('await api.createWork('));
    },
  );
}
