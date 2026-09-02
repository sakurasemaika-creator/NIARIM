import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/community_service.dart';

/// ホーム画面「ブクマ済み」タブの並び順（新しくブックマークした順）を守る。
///
/// 以前はcommunityService.worksの並び（ダミーデータの生成順）そのままで、
/// たった今ブックマークした作品が一覧のどこに出るか分からなかった。
void main() {
  group('bookmarkedIdsNewestFirst', () {
    test('ブックマークが無いときは空', () {
      expect(CommunityService().bookmarkedIdsNewestFirst, isEmpty);
    });

    test('新しくブックマークした作品ほど先頭に来る', () {
      final service = CommunityService();
      final ids = service.works.take(3).map((w) => w.id).toList();
      for (final id in ids) {
        service.toggleBookmark(id);
      }
      expect(service.bookmarkedIdsNewestFirst, ids.reversed.toList());
    });

    test('解除するとその作品だけが一覧から消える', () {
      final service = CommunityService();
      final ids = service.works.take(3).map((w) => w.id).toList();
      for (final id in ids) {
        service.toggleBookmark(id);
      }
      service.toggleBookmark(ids[1]);
      expect(service.bookmarkedIdsNewestFirst, [ids[2], ids[0]]);
    });

    test('付け直すと「付け直した時点が新しい」扱いで先頭へ移動する', () {
      final service = CommunityService();
      final ids = service.works.take(3).map((w) => w.id).toList();
      for (final id in ids) {
        service.toggleBookmark(id);
      }
      service.toggleBookmark(ids[0]); // 解除
      service.toggleBookmark(ids[0]); // 付け直し
      expect(service.bookmarkedIdsNewestFirst.first, ids[0]);
    });

    test('bookmarkedIdsと同じ集合を返す（片方だけ更新される取りこぼしが無い）', () {
      final service = CommunityService();
      for (final w in service.works.take(4)) {
        service.toggleBookmark(w.id);
      }
      expect(service.bookmarkedIdsNewestFirst.toSet(), service.bookmarkedIds);
    });
  });
}
