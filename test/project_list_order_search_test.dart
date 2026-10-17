import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/name_collation.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// プロジェクト一覧の並び順・検索・空の表示・表示サイズの保存。実際の
/// 起動画面から「作品をつくる」で入ったホームで確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('compareNames', () {
    List<String> sorted(List<String> names) => [...names]..sort(compareNames);

    test('numbers in names compare as numbers', () {
      expect(sorted(['作品10', '作品2', '作品1']), ['作品1', '作品2', '作品10']);
      expect(sorted(['a10b', 'a9b', 'a010b']), ['a9b', 'a10b', 'a010b']);
    });

    test('case, width and kana do not change the order', () {
      expect(sorted(['cherry', 'Banana', 'apple']), [
        'apple',
        'Banana',
        'cherry',
      ]);
      expect(sorted(['banana', 'ＡＢＣ', 'abd']), ['ＡＢＣ', 'abd', 'banana']);
      expect(sorted(['すいか', 'ｶﾀｶﾅ', 'あめ']), ['あめ', 'ｶﾀｶﾅ', 'すいか']);
    });

    test('names that fold to the same text keep a fixed order', () {
      expect(compareNames('Apple', 'apple'), isNot(0));
      expect(compareNames('Apple', 'apple'), -compareNames('apple', 'Apple'));
    });

    test('searching folds case, width and kana', () {
      expect(nameMatches('ＡＢＣ全角', foldName('abc')), isTrue);
      expect(nameMatches('ｶﾀｶﾅ半角', foldName('かたかな')), isTrue);
      expect(nameMatches('ｶﾞｯﾂﾎﾟｰｽﾞ', foldName('ガッツポーズ')), isTrue);
      expect(nameMatches('シーン1', foldName('しーん')), isTrue);
      expect(nameMatches('シーン1', foldName('しーん2')), isFalse);
    });
  });

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_list_order_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      // テストの端末は低スペック扱いで小表示が初期値になるので、中表示に
      // そろえる。
      'home_view_mode': 'medium',
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // 作品・フォルダを作ってからホームを開く。作る順に更新日時が新しくなる。
  Future<ProjectService> boot(
    WidgetTester tester, {
    List<String> names = const [],
    Future<void> Function(ProjectService service)? extra,
    Size size = const Size(800, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final service = tester
        .element(find.byType(SplashScreen))
        .read<ProjectService>();
    await tester.runAsync(() async {
      for (final name in names) {
        await service.createProject(
          name: name,
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }
      await extra?.call(service);
    });
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    return service;
  }

  // 一覧に出ている名前（上の行から、行の中は左から）。
  List<String> shownNames(WidgetTester tester) {
    final list = find.byType(ProjectListWidget);
    final names = <(Offset, String)>[];
    for (final element
        in find.descendant(of: list, matching: find.byType(Text)).evaluate()) {
      final text = (element.widget as Text).data;
      if (text == null) continue;
      // カードの名前（見出しフォント）だけ。
      if ((element.widget as Text).style?.fontFamily != 'Kuramubon') continue;
      final box = element.renderObject! as RenderBox;
      names.add((box.localToGlobal(Offset.zero), text));
    }
    names.sort((a, b) {
      final dy = (a.$1.dy - b.$1.dy);
      if (dy.abs() > 8) return dy.sign.toInt();
      return a.$1.dx.compareTo(b.$1.dx);
    });
    return [for (final n in names) n.$2];
  }

  Future<void> chooseNameAscending(WidgetTester tester) async {
    await tester.tap(find.text('更新日時'));
    await settle(tester);
    await tester.tap(find.text('名前').last);
    await settle(tester);
    // 名前を選ぶと降順のまま。矢印で昇順にする。
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await settle(tester);
  }

  testWidgets('folders come first, then works in reading order', (
    tester,
  ) async {
    await boot(
      tester,
      names: ['作品10', '作品2', '作品1', 'Banana', 'apple', 'ＡＢＣ全角', 'ｶﾀｶﾅ'],
      extra: (service) async {
        await service.createFolder('フォルダB');
      },
    );
    await chooseNameAscending(tester);
    final names = shownNames(tester);
    expect(names, [
      'フォルダB',
      'ＡＢＣ全角',
      'apple',
      'Banana',
      'ｶﾀｶﾅ',
      '作品1',
      '作品2',
      '作品10',
    ]);
  });

  testWidgets('a folder is as new as the newest work inside it', (
    tester,
  ) async {
    await boot(
      tester,
      names: ['古い作品'],
      extra: (service) async {
        final folder = await service.createFolder('フォルダ');
        await Future<void>.delayed(const Duration(milliseconds: 3));
        await service.createFolder('後で作ったフォルダ');
        await Future<void>.delayed(const Duration(milliseconds: 3));
        final inner = await service.createProject(
          name: '新しい作品',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await service.moveToFolder(inner.id, folder.id);
      },
    );
    // 既定は更新日時の新しい順。
    expect(shownNames(tester), ['フォルダ', '後で作ったフォルダ', '古い作品']);
  });

  Future<void> search(WidgetTester tester, String query) async {
    if (find.byType(TextField).evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.search));
      await settle(tester);
    }
    await tester.enterText(find.byType(TextField), query);
    await settle(tester);
  }

  testWidgets('search ignores case, width and kana and shows the folder', (
    tester,
  ) async {
    await boot(
      tester,
      names: ['ＡＢＣ全角', 'ｶﾀｶﾅ半角', 'シーン1', 'シーン1'],
      extra: (service) async {
        final folder = await service.createFolder('第1話');
        await service.moveToFolder(service.projects.last.id, folder.id);
      },
    );
    await search(tester, 'abc');
    expect(find.text('ＡＢＣ全角'), findsOneWidget);
    await search(tester, 'かたかな');
    expect(find.text('ｶﾀｶﾅ半角'), findsOneWidget);
    await search(tester, 'しーん');
    expect(find.text('シーン1'), findsNWidgets(2));
    // 同じ名前の作品のうち、フォルダの中の方にはフォルダ名が添えられる。
    expect(find.text('第1話'), findsOneWidget);
  });

  testWidgets('no match offers to clear the search, not to create', (
    tester,
  ) async {
    await boot(tester, names: ['apple']);
    await search(tester, 'zzz');
    expect(find.text('「zzz」に一致する作品はありません'), findsOneWidget);
    expect(find.text('＋ ボタンから新規作成'), findsNothing);
    await tester.tap(find.text('検索をやめる'));
    await settle(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('apple'), findsOneWidget);
  });

  testWidgets('favorites-only with none offers to show all', (tester) async {
    await boot(tester, names: ['apple']);
    await tester.tap(find.widgetWithText(FilterChip, 'お気に入り'));
    await settle(tester);
    expect(find.text('お気に入りの作品はありません'), findsOneWidget);
    await tester.tap(find.text('すべて表示'));
    await settle(tester);
    expect(find.text('apple'), findsOneWidget);
  });

  testWidgets('a search hidden only by favorites says so', (tester) async {
    await boot(
      tester,
      names: ['apple', 'banana'],
      extra: (service) async {
        await service.toggleFavorite(service.projects.last.id);
      },
    );
    await tester.tap(find.widgetWithText(FilterChip, 'お気に入り'));
    await settle(tester);
    await search(tester, 'apple');
    // 「apple」は検索には当たるが、お気に入りではない。
    expect(find.text('「apple」に一致する作品はありません'), findsNothing);
    expect(find.text('お気に入りの作品はありません'), findsOneWidget);
    await tester.tap(find.text('すべて表示'));
    await settle(tester);
    expect(
      find.descendant(
        of: find.byType(ProjectListWidget),
        matching: find.text('apple'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('small cards at 2x text keep their pictures in search results', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'home_view_mode': 'small',
    });
    await boot(
      tester,
      size: const Size(320, 700),
      names: ['표정 연습', '표정 연습 2'],
      extra: (service) async {
        final folder = await service.createFolder('연습 폴더');
        await service.moveToFolder(service.projects.first.id, folder.id);
      },
    );
    await search(tester, '표정');
    expect(tester.takeException(), isNull);
    // どのカードも絵の欄が残っている（名前の帯が絵を押しつぶさない）。
    for (final element in find.byType(FramePreviewBackground).evaluate()) {
      final box = element.renderObject! as RenderBox;
      expect(box.size.height, greaterThan(24));
    }
  });

  testWidgets('an empty folder says so', (tester) async {
    await boot(
      tester,
      extra: (service) async {
        await service.createFolder('空');
      },
    );
    await tester.tap(find.text('空'));
    await settle(tester);
    expect(find.text('このフォルダは空です'), findsOneWidget);
  });

  testWidgets('menus mark the current choice and the choice is kept', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'home_view_mode': 'medium',
    });
    await boot(tester, names: ['apple']);
    await tester.tap(find.byTooltip('表示の大きさ'));
    await settle(tester);
    expect(
      tester.getSemantics(find.text('中').last),
      isSemantics(
        label: '中',
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    await tester.tap(find.text('詳細').last);
    await settle(tester);
    await tester.tap(find.text('更新日時'));
    await settle(tester);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('名前').last);
    await settle(tester);
    final settings = tester
        .element(find.byType(ProjectListWidget))
        .read<SettingsService>();
    expect(settings.homeViewMode, 'detail');
    expect(settings.homeSortMode, 'nameDesc');
    handle.dispose();

    // 起動し直しても引き継ぐ。
    appRouter.go('/');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    expect(find.byIcon(Icons.view_list), findsOneWidget);
    expect(find.text('名前'), findsOneWidget);
  });

  testWidgets('cards show the name below the picture on the project paper', (
    tester,
  ) async {
    await boot(
      tester,
      extra: (service) async {
        await service.createProject(
          name: '黒い背景',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFF000000,
          exportWidth: 1080,
          exportHeight: 1920,
        );
        await service.toggleFavorite(service.projects.last.id);
      },
    );
    final paper = find.byType(FramePreviewBackground);
    expect(
      tester.widget<FramePreviewBackground>(paper).backgroundColor,
      0xFF000000,
    );
    expect(
      tester.widget<FramePreviewBackground>(paper).aspectRatio,
      closeTo(1080 / 1920, 1e-9),
    );
    // 名前は絵の外（下）にあり、絵の色に重ならない。
    final picture = tester.getRect(paper);
    final name = tester.getRect(find.text('黒い背景'));
    expect(name.top, greaterThanOrEqualTo(picture.bottom));

    // 詳細表示でもお気に入りの星が出る。
    await tester.tap(find.byTooltip('表示の大きさ'));
    await settle(tester);
    await tester.tap(find.text('詳細').last);
    await settle(tester);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '黒い背景'),
        matching: find.byIcon(Icons.star),
      ),
      findsOneWidget,
    );
  });
}
