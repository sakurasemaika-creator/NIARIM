import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('homeWidgetRoute', () {
    test('作品ウィジェットは選ばれた作品を開く', () {
      expect(
        homeWidgetRoute(HomeWidgetKind.artwork, projectId: 'abc'),
        '/project/abc',
      );
    });

    test('作品が未選択なら作品一覧へ落とす', () {
      expect(homeWidgetRoute(HomeWidgetKind.artwork), '/home');
      expect(homeWidgetRoute(HomeWidgetKind.artwork, projectId: ''), '/home');
    });

    test('ショートカット2種は固定のルート', () {
      expect(homeWidgetRoute(HomeWidgetKind.create), '/new-project');
      expect(homeWidgetRoute(HomeWidgetKind.plaza), '/community');
    });
  });

  group('HomeWidgetService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('初期状態はテーマ追従・作品未選択', () async {
      final service = HomeWidgetService();
      await service.init();
      expect(service.projectId, isNull);
      expect(service.backgroundColor, isNull);
      expect(service.followsTheme, isTrue);
    });

    test('設定は再起動をまたいで復元される', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectProject('p1');
      await service.setBackgroundColor(0xFF123456);

      final reloaded = HomeWidgetService();
      await reloaded.init();
      expect(reloaded.projectId, 'p1');
      expect(reloaded.backgroundColor, 0xFF123456);
      expect(reloaded.followsTheme, isFalse);
    });

    test('背景色にnullを渡すとテーマ追従へ戻る', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(0xFF123456);
      expect(service.followsTheme, isFalse);
      await service.setBackgroundColor(null);
      expect(service.followsTheme, isTrue);
    });

    test('空文字のプロジェクトIDは未選択として扱う', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectProject('');
      expect(service.projectId, isNull);
    });

    test('壊れた保存値でも既定値で起動できる', () async {
      SharedPreferences.setMockInitialValues({
        'home_widget_config_v1': 'これはJSONではない',
      });
      final service = HomeWidgetService();
      await service.init();
      expect(service.projectId, isNull);
      expect(service.followsTheme, isTrue);
    });

    test('テーマ追従のときはテーマカラーが背景色になる', () async {
      final service = HomeWidgetService();
      await service.init();
      final payload = service.widgetPayload(themeColor: 0xFFABCDEF);
      expect(payload['backgroundColor'], 0xFFABCDEF);
    });

    test('色を指定しているときはテーマカラーを無視する', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(0xFF112233);
      final payload = service.widgetPayload(themeColor: 0xFFABCDEF);
      expect(payload['backgroundColor'], 0xFF112233);
    });

    test('payloadのルートはhomeWidgetRouteと一致する', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectProject('p9');
      final payload = service.widgetPayload(
        themeColor: 0xFF000000,
        projectName: 'テスト作品',
        thumbnailPath: '/tmp/a.png',
      );
      expect(payload['routeArtwork'], '/project/p9');
      expect(payload['routeCreate'], '/new-project');
      expect(payload['routePlaza'], '/community');
      expect(payload['projectId'], 'p9');
      expect(payload['projectName'], 'テスト作品');
      expect(payload['thumbnailPath'], '/tmp/a.png');
    });

    test('payloadはnullを含まない（ネイティブへ渡せる形にする）', () async {
      final service = HomeWidgetService();
      await service.init();
      final payload = service.widgetPayload(themeColor: 0xFF000000);
      expect(payload.values.every((v) => v != null), isTrue);
    });
  });
}
