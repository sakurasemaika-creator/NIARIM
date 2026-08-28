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
}
