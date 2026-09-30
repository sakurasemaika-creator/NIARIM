import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CommunityWork makeWork({
  String title = '静かな街',
  List<String> tags = const ['手描き'],
  String authorName = '作者',
  bool containsGenerativeAiImageOrVideo = false,
}) => CommunityWork(
  id: '${title}_${tags.join("_")}_$authorName',
  title: title,
  authorId: 'author_x',
  authorName: authorName,
  viewCount: 0,
  likeCount: 0,
  bookmarkCount: 0,
  postedAt: DateTime(2026),
  durationSeconds: 10,
  thumbnailColorIndex: 0,
  tags: tags,
  containsGenerativeAiImageOrVideo: containsGenerativeAiImageOrVideo,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mute word filters title but not author or plaza tags', () async {
    final service = CommunityService();
    await service.setMutedWords(['禁止語']);
    service.replaceWorksForTest([
      makeWork(title: '禁止語を含む作品'),
      makeWork(authorName: '禁止語作者'),
      makeWork(tags: const ['禁止語']),
    ]);

    final visible = service.discoverableWorks;
    expect(visible.map((w) => w.authorName), contains('禁止語作者'));
    expect(visible.any((w) => w.tags.contains('禁止語')), isTrue);
    expect(visible.any((w) => w.title.contains('禁止語')), isFalse);
  });

  test('mute tag filters exact work-plaza tag only', () async {
    final service = CommunityService();
    await service.setMutedTags(['手描き']);
    service.replaceWorksForTest([
      makeWork(title: '#手描き はタイトル文字列', tags: const ['風景']),
      makeWork(tags: const ['手描き風']),
      makeWork(tags: const ['手描き']),
    ]);

    final visible = service.discoverableWorks;
    expect(visible.any((w) => w.title.startsWith('#手描き')), isTrue);
    expect(visible.any((w) => w.tags.contains('手描き風')), isTrue);
    expect(visible.any((w) => w.tags.contains('手描き')), isFalse);
  });

  test('content filters restore and later writes win over async restore', () async {
    SharedPreferences.setMockInitialValues({
      'community.hideGenerativeAiImageVideo': true,
      'community.mutedWords': ['old title'],
      'community.mutedTags': ['old-tag'],
    });

    final service = CommunityService();
    await service.contentFiltersReady;
    expect(service.hideGenerativeAiImageVideo, isTrue);
    expect(service.mutedWords, contains('old title'));
    expect(service.mutedTags, contains('old-tag'));

    await service.setHideGenerativeAiImageVideo(false);
    await service.setMutedWords(['New Title']);
    await service.setMutedTags(['New-Tag']);

    final restored = CommunityService();
    await restored.contentFiltersReady;
    expect(restored.hideGenerativeAiImageVideo, isFalse);
    expect(restored.mutedWords, {'new title'});
    expect(restored.mutedTags, {'new-tag'});
  });

  test('author lists apply viewer filters but owner list can still manage hidden works', () async {
    final service = CommunityService();
    await service.setMutedWords(['mute']);
    service.replaceWorksForTest([
      makeWork(title: 'visible'),
      makeWork(title: 'mute this'),
    ]);

    expect(
      service.worksByAuthor('author_x').map((w) => w.title),
      ['visible'],
    );
    expect(
      service.worksByAuthor('author_x', includeHidden: true).map((w) => w.title),
      containsAll(['visible', 'mute this']),
    );
  });

  test('viewer predicate follows AI, title, and tag filters', () async {
    final service = CommunityService();
    final ai = makeWork(
      title: 'ai',
      containsGenerativeAiImageOrVideo: true,
    );
    final mutedTitle = makeWork(title: 'blocked title');
    final mutedTag = makeWork(title: 'tagged', tags: const ['blocked-tag']);
    final visible = makeWork(title: 'visible', tags: const ['safe']);

    await service.setHideGenerativeAiImageVideo(true);
    await service.setMutedWords(['blocked']);
    await service.setMutedTags(['blocked-tag']);

    expect(service.isDiscoverableForViewer(ai), isFalse);
    expect(service.isDiscoverableForViewer(mutedTitle), isFalse);
    expect(service.isDiscoverableForViewer(mutedTag), isFalse);
    expect(service.isDiscoverableForViewer(visible), isTrue);
  });

  test('AI image/video usage filter hides only disclosed works', () async {
    final service = CommunityService();
    service.replaceWorksForTest([
      makeWork(title: 'AI使用作品', containsGenerativeAiImageOrVideo: true),
      makeWork(title: '通常作品'),
    ]);

    expect(service.discoverableWorks.map((w) => w.title), containsAll(['AI使用作品', '通常作品']));

    await service.setHideGenerativeAiImageVideo(true);
    final visible = service.discoverableWorks;
    expect(visible.map((w) => w.title), contains('通常作品'));
    expect(visible.map((w) => w.title), isNot(contains('AI使用作品')));
  });
}
