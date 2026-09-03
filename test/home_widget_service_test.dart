import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('homeWidgetRoute', () {
    test('作品ウィジェットは起動画面を開く（作品の編集画面へは飛ばさない）', () {
      expect(homeWidgetRoute(HomeWidgetKind.artwork), '/');
    });

    test('ショートカット2種は固定のルート', () {
      expect(homeWidgetRoute(HomeWidgetKind.create), '/new-project');
      expect(homeWidgetRoute(HomeWidgetKind.plaza), '/community');
    });
  });

  group('HomeWidgetService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('初期状態は全種類テーマ追従・作品未選択', () async {
      final service = HomeWidgetService();
      await service.init();
      expect(service.projectId, isNull);
      expect(service.sceneId, isNull);
      expect(service.frameIndex, isNull);
      for (final kind in HomeWidgetKind.values) {
        expect(service.backgroundColorOf(kind), isNull);
        expect(service.followsTheme(kind), isTrue);
      }
    });

    test('設定は再起動をまたいで復元される', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectArtwork(
        projectId: 'p1',
        sceneId: 's1',
        frameIndex: 3,
      );
      await service.setBackgroundColor(HomeWidgetKind.create, 0xFF123456);

      final reloaded = HomeWidgetService();
      await reloaded.init();
      expect(reloaded.projectId, 'p1');
      expect(reloaded.sceneId, 's1');
      expect(reloaded.frameIndex, 3);
      expect(reloaded.backgroundColorOf(HomeWidgetKind.create), 0xFF123456);
      expect(reloaded.followsTheme(HomeWidgetKind.create), isFalse);
    });

    test('作品を選び直すとシーン・フレームも入れ替わる', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectArtwork(
        projectId: 'p1',
        sceneId: 's1',
        frameIndex: 3,
      );
      await service.selectArtwork(projectId: 'p2', sceneId: 's9');
      expect(service.projectId, 'p2');
      expect(service.sceneId, 's9');
      // frameIndexを省略すると先頭フレーム扱い（null）に戻る。
      expect(service.frameIndex, isNull);
    });

    test('引数無しで選び直すと作品・シーン・フレームがすべてクリアされる', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectArtwork(
        projectId: 'p1',
        sceneId: 's1',
        frameIndex: 3,
      );
      await service.selectArtwork();
      expect(service.projectId, isNull);
      expect(service.sceneId, isNull);
      expect(service.frameIndex, isNull);
    });

    test('色は種類ごとに独立している', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(HomeWidgetKind.create, 0xFF111111);
      expect(service.followsTheme(HomeWidgetKind.create), isFalse);
      // 1種類だけ変えても他の2種類はテーマ追従のまま。
      expect(service.followsTheme(HomeWidgetKind.artwork), isTrue);
      expect(service.followsTheme(HomeWidgetKind.plaza), isTrue);
      expect(service.backgroundColorOf(HomeWidgetKind.artwork), isNull);
    });

    test('背景色にnullを渡すとその種類だけテーマ追従へ戻る', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(HomeWidgetKind.plaza, 0xFF123456);
      await service.setBackgroundColor(HomeWidgetKind.artwork, 0xFF654321);
      await service.setBackgroundColor(HomeWidgetKind.plaza, null);
      expect(service.followsTheme(HomeWidgetKind.plaza), isTrue);
      expect(service.backgroundColorOf(HomeWidgetKind.artwork), 0xFF654321);
    });

    test('種類ごとの色を持つ前の保存値は全種類へ引き継がれる', () async {
      // 旧形式（3種類で1つの色を共有していた頃）のJSON。
      SharedPreferences.setMockInitialValues({
        'home_widget_config_v1':
            '{"projectId":"old","backgroundColor":4278255360}',
      });
      final service = HomeWidgetService();
      await service.init();
      expect(service.projectId, 'old');
      // シーン・フレーム選択に対応する前のデータなので両方null
      // （＝先頭シーン・先頭フレームとして扱われる）。
      expect(service.sceneId, isNull);
      expect(service.frameIndex, isNull);
      for (final kind in HomeWidgetKind.values) {
        expect(service.backgroundColorOf(kind), 4278255360);
      }
    });

    test('空文字のプロジェクトIDは未選択として扱う', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectArtwork(projectId: '');
      expect(service.projectId, isNull);
    });

    test('壊れた保存値でも既定値で起動できる', () async {
      SharedPreferences.setMockInitialValues({
        'home_widget_config_v1': 'これはJSONではない',
      });
      final service = HomeWidgetService();
      await service.init();
      expect(service.projectId, isNull);
      expect(service.followsTheme(HomeWidgetKind.artwork), isTrue);
    });

    test('テーマ追従の種類はテーマカラーが背景色になる', () async {
      final service = HomeWidgetService();
      await service.init();
      final payload = service.widgetPayload(
        themeColor: 0xFFABCDEF,
        themeForegroundColor: 0xFFFFFFFF,
      );
      for (final kind in HomeWidgetKind.values) {
        expect(payload[HomeWidgetService.backgroundColorKey(kind)], 0xFFABCDEF);
      }
    });

    test('色を指定した種類だけテーマカラーを無視する', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(HomeWidgetKind.plaza, 0xFF112233);
      final payload = service.widgetPayload(
        themeColor: 0xFFABCDEF,
        themeForegroundColor: 0xFFFFFFFF,
      );
      expect(
        payload[HomeWidgetService.backgroundColorKey(HomeWidgetKind.plaza)],
        0xFF112233,
      );
      expect(
        payload[HomeWidgetService.backgroundColorKey(HomeWidgetKind.create)],
        0xFFABCDEF,
      );
    });

    test('payloadのルートはhomeWidgetRouteと一致する', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.selectArtwork(projectId: 'p9');
      final payload = service.widgetPayload(
        themeColor: 0xFF000000,
        themeForegroundColor: 0xFFFFFFFF,
        projectName: 'テスト作品',
        thumbnailPath: '/tmp/a.png',
      );
      expect(payload['routeArtwork'], '/');
      expect(payload['routeCreate'], '/new-project');
      expect(payload['routePlaza'], '/community');
      expect(payload['projectId'], 'p9');
      expect(payload['projectName'], 'テスト作品');
      expect(payload['thumbnailPath'], '/tmp/a.png');
    });

    test('文字色は種類ごとに指定でき、未指定ならテーマの色になる', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(HomeWidgetKind.create, 0xFF112233);
      await service.setForegroundColor(HomeWidgetKind.create, 0xFF445566);
      final payload = service.widgetPayload(
        themeColor: 0xFFABCDEF,
        themeForegroundColor: 0xFFFFFFFF,
      );
      expect(
        payload[HomeWidgetService.foregroundColorKey(HomeWidgetKind.create)],
        0xFF445566,
      );
      expect(
        payload[HomeWidgetService.foregroundColorKey(HomeWidgetKind.plaza)],
        0xFFFFFFFF,
      );
    });

    test('背景色をテーマ追従へ戻すと、文字色の指定も一緒に解除される', () async {
      final service = HomeWidgetService();
      await service.init();
      await service.setBackgroundColor(HomeWidgetKind.plaza, 0xFF112233);
      await service.setForegroundColor(HomeWidgetKind.plaza, 0xFF445566);
      await service.setBackgroundColor(HomeWidgetKind.plaza, null);
      expect(service.foregroundColorOf(HomeWidgetKind.plaza), isNull);
      expect(service.followsTheme(HomeWidgetKind.plaza), isTrue);
    });

    test('payloadはnullを含まない（ネイティブへ渡せる形にする）', () async {
      final service = HomeWidgetService();
      await service.init();
      final payload = service.widgetPayload(
        themeColor: 0xFF000000,
        themeForegroundColor: 0xFFFFFFFF,
      );
      expect(payload.values.every((v) => v != null), isTrue);
    });
  });
}
