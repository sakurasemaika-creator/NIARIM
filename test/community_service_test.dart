import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/services/community_service.dart';

/// CommunityService（Task#157：NIARIM作品広場独自の公開/非公開設定）の
/// 単体テスト。
void main() {
  test('作品はデフォルトで公開状態であり、discoverableWorksに含まれる', () {
    final service = CommunityService();
    final work = service.works.first;
    expect(work.isNiarimPublished, isTrue);
    expect(service.discoverableWorks.map((w) => w.id), contains(work.id));
  });

  test('toggleNiarimVisibilityで非公開にするとdiscoverableWorksから除外される', () {
    final service = CommunityService();
    final work = service.works.first;

    service.toggleNiarimVisibility(work.id);

    expect(service.byId(work.id)!.isNiarimPublished, isFalse);
    expect(service.discoverableWorks.map((w) => w.id), isNot(contains(work.id)));

    // 再度呼ぶと公開状態へ戻る（トグル）。
    service.toggleNiarimVisibility(work.id);
    expect(service.byId(work.id)!.isNiarimPublished, isTrue);
    expect(service.discoverableWorks.map((w) => w.id), contains(work.id));
  });

  test('worksByAuthorはincludeHidden未指定（false）の場合、非公開作品を除外する', () {
    final service = CommunityService();
    final selfWorks = service.worksByAuthor(kDummySelfAuthorId);
    expect(selfWorks, isNotEmpty, reason: 'ダミーデータにkDummySelfAuthorIdの作品が含まれる前提');
    final target = selfWorks.first;

    service.toggleNiarimVisibility(target.id);

    final afterHiding = service.worksByAuthor(kDummySelfAuthorId);
    expect(afterHiding.map((w) => w.id), isNot(contains(target.id)));
  });

  test('worksByAuthorはincludeHidden:trueの場合、非公開作品も含めて返す（投稿者本人が自分の一覧を開く想定）', () {
    final service = CommunityService();
    final selfWorks = service.worksByAuthor(kDummySelfAuthorId);
    final target = selfWorks.first;
    final beforeCount = selfWorks.length;

    service.toggleNiarimVisibility(target.id);

    final withHidden = service.worksByAuthor(kDummySelfAuthorId, includeHidden: true);
    expect(withHidden, hasLength(beforeCount), reason: '非公開になっても本人向け一覧では件数が減らないはず');
    expect(withHidden.map((w) => w.id), contains(target.id));
  });

  test('非公開設定はブックマークやタグなど他の状態に影響しない', () {
    final service = CommunityService();
    final work = service.works.first;
    service.toggleBookmark(work.id);
    service.addTag(work.id, 'テストタグ');

    service.toggleNiarimVisibility(work.id);

    final updated = service.byId(work.id)!;
    expect(service.isBookmarked(work.id), isTrue);
    expect(updated.tags, contains('テストタグ'));
    expect(updated.isNiarimPublished, isFalse);
  });

  // Task#159：横動画/ショート動画の区別。ダミーデータ生成時点で
  // isShortを模擬的に付与しており、一覧・ショートモード双方の見た目を
  // 確認できるよう横動画・ショートの両方が混在することを確認する。
  // （実装では投稿元プロジェクトのキャンバス縦横比から判定する想定。
  // community_work.dartのisShortドキュメントコメント参照）。
  test('ダミー作品には横動画・ショート動画の両方が混在する', () {
    final service = CommunityService();
    expect(service.works.any((w) => w.isShort), isTrue, reason: 'ショート動画が1件も無い');
    expect(service.works.any((w) => !w.isShort), isTrue, reason: '横動画が1件も無い');
  });

  test('ショート動画は横動画よりも短尺（60秒以内）に寄せてある', () {
    final service = CommunityService();
    for (final w in service.works.where((w) => w.isShort)) {
      expect(w.durationSeconds, lessThanOrEqualTo(60));
    }
  });

  // Task#144：お気に入り作者（フォロー）機能。
  group('お気に入り作者（フォロー）', () {
    test('toggleFavoriteAuthorで登録・解除がトグルされる', () {
      final service = CommunityService();
      final authorId = service.works.first.authorId;

      expect(service.isFavoriteAuthor(authorId), isFalse);

      service.toggleFavoriteAuthor(authorId);
      expect(service.isFavoriteAuthor(authorId), isTrue);
      expect(service.favoriteAuthorIds, contains(authorId));

      service.toggleFavoriteAuthor(authorId);
      expect(service.isFavoriteAuthor(authorId), isFalse);
      expect(service.favoriteAuthorIds, isNot(contains(authorId)));
    });

    test('favoriteAuthorWorksはお気に入り登録した作者の作品のみを新着順で返す', () {
      final service = CommunityService();
      final authorId = service.works.first.authorId;
      service.toggleFavoriteAuthor(authorId);

      final works = service.favoriteAuthorWorks;
      expect(works, isNotEmpty);
      expect(works.every((w) => w.authorId == authorId), isTrue);

      for (var i = 0; i < works.length - 1; i++) {
        expect(
          works[i].postedAt.isAfter(works[i + 1].postedAt) ||
              works[i].postedAt.isAtSameMomentAs(works[i + 1].postedAt),
          isTrue,
          reason: '新着順（postedAt降順）になっているはず',
        );
      }
    });

    test('favoriteAuthorWorksはNIARIM非公開にした作品を除外する（discoverableWorksと同じ扱い）', () {
      final service = CommunityService();
      final authorId = service.works.first.authorId;
      service.toggleFavoriteAuthor(authorId);

      final target = service.favoriteAuthorWorks.first;
      service.toggleNiarimVisibility(target.id);

      expect(service.favoriteAuthorWorks.map((w) => w.id), isNot(contains(target.id)));
    });

    test('followerCountOfは自分がフォローすると+1され、解除すると元に戻る', () {
      final service = CommunityService();
      final authorId = service.works.firstWhere((w) => w.authorId != kDummySelfAuthorId).authorId;
      final before = service.followerCountOf(authorId);

      service.toggleFavoriteAuthor(authorId);
      expect(service.followerCountOf(authorId), before + 1);

      service.toggleFavoriteAuthor(authorId);
      expect(service.followerCountOf(authorId), before);
    });

    test('followerIdsOfはfollowerCountOfと同じ人数を返し、自分がフォローすると自分自身のIDが含まれる', () {
      final service = CommunityService();
      final authorId = service.works.firstWhere((w) => w.authorId != kDummySelfAuthorId).authorId;

      expect(service.followerIdsOf(authorId).length, service.followerCountOf(authorId));
      expect(service.followerIdsOf(authorId), isNot(contains(kDummySelfAuthorId)));

      service.toggleFavoriteAuthor(authorId);
      expect(service.followerIdsOf(authorId), contains(kDummySelfAuthorId));
      expect(service.followerNamesOf(authorId), contains(service.authorNameOf(kDummySelfAuthorId)));
    });

    test('フォロワー一覧の公開設定は既定で非公開、setSelfFollowersPublicで変更できる', () {
      final service = CommunityService();
      expect(service.selfFollowersPublic, isFalse);
      expect(service.isFollowersPublic(kDummySelfAuthorId), isFalse);

      service.setSelfFollowersPublic(true);
      expect(service.selfFollowersPublic, isTrue);

      service.setSelfFollowersPublic(false);
      expect(service.selfFollowersPublic, isFalse);
    });

    test('followingIdsOfは自分の場合favoriteAuthorIdsと一致し、フォローすると増える', () {
      final service = CommunityService();
      expect(service.followingIdsOf(kDummySelfAuthorId), isEmpty);

      final authorId = service.works.firstWhere((w) => w.authorId != kDummySelfAuthorId).authorId;
      service.toggleFavoriteAuthor(authorId);
      expect(service.followingIdsOf(kDummySelfAuthorId), [authorId]);
      expect(service.followingCountOf(kDummySelfAuthorId), 1);
      expect(service.followingNamesOf(kDummySelfAuthorId), [service.authorNameOf(authorId)]);
    });

    test('followingIdsOfはfollowerIdsOfの逆引きとして整合する（他のダミー作者同士）', () {
      final service = CommunityService();
      for (final authorId in service.works.map((w) => w.authorId).toSet()) {
        for (final followingId in service.followingIdsOf(authorId)) {
          expect(service.followerIdsOf(followingId), contains(authorId),
              reason: '$authorIdが$followingIdをフォロー中なら、$followingIdのフォロワーに$authorIdが含まれるはず');
        }
      }
    });
  });

  // Task#145：リポスト機能・ブックマークの公開設定・ユーザー別ブックマーク一覧。
  group('リポスト', () {
    test('toggleRepostで自分のリポストが登録・解除される', () {
      final service = CommunityService();
      final work = service.works.firstWhere((w) => w.authorId != kDummySelfAuthorId);

      expect(service.isRepostedBySelf(work.id), isFalse);

      service.toggleRepost(work.id);
      expect(service.isRepostedBySelf(work.id), isTrue);

      service.toggleRepost(work.id);
      expect(service.isRepostedBySelf(work.id), isFalse);
    });

    test('自分自身が投稿した作品もリポストできる', () {
      final service = CommunityService();
      final ownWork = service.works.firstWhere((w) => w.authorId == kDummySelfAuthorId);

      service.toggleRepost(ownWork.id);
      expect(service.isRepostedBySelf(ownWork.id), isTrue, reason: '自作もフォロワーへ改めて周知する用途でリポストできるはず');

      service.toggleRepost(ownWork.id);
      expect(service.isRepostedBySelf(ownWork.id), isFalse);
    });

    test('repostCountOfはリポスト数を反映する', () {
      final service = CommunityService();
      final work = service.works.firstWhere((w) => w.authorId != kDummySelfAuthorId);
      final before = service.repostCountOf(work.id);

      service.toggleRepost(work.id);
      expect(service.repostCountOf(work.id), before + 1);

      service.toggleRepost(work.id);
      expect(service.repostCountOf(work.id), before);
    });

    test('favoriteAuthorFeedはフォロー中の作者自身の投稿だけでなく、'
        'フォロー中の作者が他者の作品をリポストした場合も含める', () {
      final service = CommunityService();
      // 自分がフォローしている作者（author_02）が、フォローしていない
      // 別の作者（author_03）の作品をリポストした状況を作る。
      const followedAuthorId = 'author_02';
      final otherAuthorsWork =
          service.works.firstWhere((w) => w.authorId != followedAuthorId && w.authorId != kDummySelfAuthorId);

      service.toggleFavoriteAuthor(followedAuthorId);
      expect(
        service.favoriteAuthorFeed.map((e) => e.work.id),
        isNot(contains(otherAuthorsWork.id)),
        reason: 'リポストされる前は、フォローしていない作者の作品は含まれないはず',
      );

      service.toggleRepost(otherAuthorsWork.id, authorId: followedAuthorId);

      final feed = service.favoriteAuthorFeed;
      final entry = feed.firstWhere((e) => e.work.id == otherAuthorsWork.id);
      expect(entry.isRepost, isTrue);
      expect(entry.repostedByAuthorId, followedAuthorId);
      // リポストは「今」行われたため、一覧の先頭（最新）に来るはず。
      expect(feed.first.work.id, otherAuthorsWork.id);
    });

    test('favoriteAuthorFeedは同じ作品が複数の理由で該当する場合、より新しい方を採用する', () {
      final service = CommunityService();
      const followedAuthorId = 'author_02';
      final ownWorkOfFollowed = service.worksByAuthor(followedAuthorId).first;

      service.toggleFavoriteAuthor(followedAuthorId);
      // フォロー中の作者自身の投稿として既に一覧に含まれている作品を、
      // 同じ作者が自分の作品として改めてリポストするケース（自作リポストも
      // 許可した設計。フォロワーへ改めて周知する用途を想定）。
      // postedAtより明らかに新しいリポストのため、そちらのrepostedAtが
      // 採用されるはず。
      service.toggleRepost(ownWorkOfFollowed.id, authorId: followedAuthorId);
      final entry = service.favoriteAuthorFeed.firstWhere((e) => e.work.id == ownWorkOfFollowed.id);
      expect(entry.isRepost, isTrue, reason: '自作リポストの方が新しければそちらが採用されるはず');
      expect(entry.repostedByAuthorId, followedAuthorId);
    });
  });

  group('ブックマークの公開設定・ユーザー別ブックマーク一覧', () {
    test('自分のブックマーク公開設定は既定で非公開', () {
      final service = CommunityService();
      expect(service.selfBookmarksPublic, isFalse);
      expect(service.isBookmarksPublic(kDummySelfAuthorId), isFalse);
    });

    test('setSelfBookmarksPublicで公開設定を変更できる', () {
      final service = CommunityService();
      service.setSelfBookmarksPublic(true);
      expect(service.selfBookmarksPublic, isTrue);
      service.setSelfBookmarksPublic(false);
      expect(service.selfBookmarksPublic, isFalse);
    });

    test('bookmarkedWorksOfは自分自身の場合、実際にトグルしたブックマークを返す', () {
      final service = CommunityService();
      final work = service.works.first;
      expect(service.bookmarkedWorksOf(kDummySelfAuthorId), isEmpty);

      service.toggleBookmark(work.id);

      expect(service.bookmarkedWorksOf(kDummySelfAuthorId).map((w) => w.id), contains(work.id));
    });

    test('bookmarkedWorksOfは他のダミー作者の場合、生成済みの固定ダミーブックマークを返す', () {
      final service = CommunityService();
      // 少なくとも1人はダミーブックマークを持つ想定
      // （_buildDummyBookmarksByAuthorは各作者2〜5件を生成する）。
      final works = service.bookmarkedWorksOf('author_02');
      expect(works, isNotEmpty);
    });

    test('同じ引数で呼び出すたびに同じ結果を返す（固定シードで再現可能）', () {
      final service = CommunityService();
      final first = service.bookmarkedWorksOf('author_03').map((w) => w.id).toList();
      final second = service.bookmarkedWorksOf('author_03').map((w) => w.id).toList();
      expect(first, second);
    });
  });

  // Task#134継続：フォロー通知（「フォローされたら通知が来るように
  // してほしい」という要望を受けた実装）。
  group('フォロー通知', () {
    test('followNotificationsは自分のフォロワー（ダミー）と件数が一致する', () {
      final service = CommunityService();
      expect(service.followNotifications.length, service.followerCountOf(kDummySelfAuthorId));
    });

    test('followNotificationsの通知元は自分のフォロワー一覧と一致する', () {
      final service = CommunityService();
      final notifiedIds = service.followNotifications.map((n) => n.followerId).toSet();
      expect(notifiedIds, service.followerIdsOf(kDummySelfAuthorId).toSet());
    });

    test('初期状態では未読数が通知件数と一致し、markAllFollowNotificationsReadで0になる', () {
      final service = CommunityService();
      final total = service.followNotifications.length;
      expect(total, greaterThan(0), reason: 'ダミーデータ上、少なくとも1件はフォロワーがいる想定');
      expect(service.unreadFollowNotificationCount, total);

      service.markAllFollowNotificationsRead();
      expect(service.unreadFollowNotificationCount, 0);
      expect(service.followNotifications.every((n) => n.isRead), isTrue);
    });

    test('followNotificationsは新着順（followedAt降順）で返す', () {
      final service = CommunityService();
      final list = service.followNotifications;
      for (var i = 0; i < list.length - 1; i++) {
        expect(
          list[i].followedAt.isAfter(list[i + 1].followedAt) ||
              list[i].followedAt.isAtSameMomentAs(list[i + 1].followedAt),
          isTrue,
        );
      }
    });
  });
}
