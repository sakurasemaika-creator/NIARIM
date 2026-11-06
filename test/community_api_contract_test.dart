import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/api/community_api.dart';

void main() {
  group('CommunityApi contract', () {
    test('ランキング期間はバックエンドのパス値と一致する', () {
      expect(RankingPeriod.all.pathValue, 'all');
      expect(RankingPeriod.year.pathValue, 'yearly');
      expect(RankingPeriod.month.pathValue, 'monthly');
      expect(RankingPeriod.week.pathValue, 'weekly');
      expect(RankingPeriod.day.pathValue, 'daily');
      expect(RankingPeriod.bookmarks.pathValue, 'bookmarks');
    });
  });
}
