import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final post = File('lib/screens/community/community_post_screen.dart')
      .readAsStringSync();
  final work = File('lib/screens/community/community_my_works_screen.dart')
      .readAsStringSync();
  final api = File('lib/services/api/community_api.dart').readAsStringSync();
  final detail = File('lib/screens/community/community_work_detail_screen.dart')
      .readAsStringSync();

  test('submission carries YouTube scheduling and preserves the video ID', () {
    expect(post, contains("value: 'scheduled'"));
    expect(post, contains('scheduledPublishAt: _youtubePrivacyStatus'));
    expect(post, contains('privacyStatus: _youtubePrivacyStatus'));
    expect(post, contains('_pendingScheduledPublishAtKey'));
    expect(post, contains('await _persistPendingUpload('));
    expect(post, contains('await thumbnail.setThumbnail('));
    expect(post.indexOf('await _persistPendingUpload('),
      lessThan(post.indexOf('await thumbnail.setThumbnail(')));
  });

  test('successful NIARIM work registration precedes OS success notification',
      () {
    final register = post.indexOf('await api.createWork(');
    final finish = post.lastIndexOf('await _finishRegistration(');
    final notify = post.indexOf('PostCompletionNotificationService.notifySuccess(');
    expect(register, greaterThan(0));
    expect(finish, greaterThan(register));
    expect(notify, greaterThan(0));
    expect(post, contains('workId: registeredVideoId'));
  });

  test('successful registration notification does not depend on feed refresh',
      () {
    final start = post.indexOf('Future<void> _finishRegistration(');
    final end = post.indexOf('Future<void> _submit()', start);
    final completion = post.substring(start, end);
    final clear = completion.indexOf('await _clearPendingUpload()');
    final notify = completion.indexOf('PostCompletionNotificationService.notifySuccess(');
    final refresh = completion.indexOf('await community.refreshFromBackend()');
    expect(clear, greaterThanOrEqualTo(0));
    expect(notify, greaterThan(clear));
    expect(refresh, greaterThan(notify));
    expect(completion, contains('on Object catch (error)'));
  });

  test('Shorts wait for completed YouTube processing before thumbnail setting',
      () {
    final start = post.indexOf('final thumbnail = YoutubeThumbnailService();');
    final end = post.indexOf('thumbnail.close();', start);
    final upload = post.substring(start, end);
    expect(upload, contains('if (_isShort)'));
    expect(upload, contains('await thumbnail.waitUntilProcessed('));
    expect(upload.indexOf('await thumbnail.waitUntilProcessed('),
        lessThan(upload.indexOf('await thumbnail.setThumbnail(')));
  });

  test('owner-only management differentiates scheduled and private uploads', () {
    expect(work, contains('_scheduledPublishById'));
    expect(work, contains("youtubePrivacy == 'private'"));
    expect(work, contains('予約公開中'));
    expect(work, contains('YouTubeの公開処理を確認中'));
    expect(api, contains("'/me/works/"));
    expect(detail, contains('_loadOwnerOnlyWorkIfNeeded'));
    expect(detail, contains('_ownerOnlyAccountId'));
    expect(detail, contains('cached.isUnavailable'));
    expect(detail, contains('(ownerFallback ?? cachedWork)'));
  });
}
