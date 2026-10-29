import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/community_milestone_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'first observation establishes baselines with no notification',
    () async {
      final store = CommunityMilestoneStore();
      final events = await store.observe(
        'owner-A',
        followers: 9,
        bookmarks: {'work-1': ('Example work', 49)},
      );
      expect(events, isEmpty);
      expect(await store.load('owner-A'), isEmpty);
    },
  );

  test(
    'crossing milestones creates anonymous account-scoped notifications',
    () async {
      final store = CommunityMilestoneStore();
      await store.observe(
        'owner-A',
        followers: 9,
        bookmarks: {'work-1': ('Example work', 49)},
      );
      final events = await store.observe(
        'owner-A',
        followers: 10,
        bookmarks: {'work-1': ('Example work', 50)},
      );
      expect(events.length, 2);
      expect(events.any((e) => e.isFollower && e.count == 10), isTrue);
      expect(
        events.any(
          (e) =>
              !e.isFollower && e.count == 50 && e.workTitle == 'Example work',
        ),
        isTrue,
      );
      expect(events.every((e) => !e.id.contains('followerId')), isTrue);
      expect(await store.load('owner-B'), isEmpty);
      expect((await store.observe('owner-A', followers: 10)).length, 2);
      final read = await store.markAllRead('owner-A');
      expect(read.every((e) => e.read), isTrue);
    },
  );

  test('concurrent count updates do not overwrite each other', () async {
    final store = CommunityMilestoneStore();
    await store.observe(
      'owner-A',
      followers: 9,
      bookmarks: {'work-1': ('Art', 49)},
    );
    await Future.wait([
      store.observe('owner-A', followers: 10),
      store.observe('owner-A', bookmarks: {'work-1': ('Art', 50)}),
    ]);
    final events = await store.load('owner-A');
    expect(events.length, 2);
  });
}
