import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 作品・フォルダの選択、一括の操作、切り取り・コピー・貼り付け、
/// 右クリックのメニュー、名前の入力。実際の起動画面から入ったホームで
/// 確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_selection_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
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

  // ファイルの読み書きを伴う操作（複製・保存）を実時間で終わらせる。
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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

  Finder card(String name) => find.descendant(
    of: find.byType(ProjectListWidget),
    matching: find.text(name),
  );

  String? snackText(WidgetTester tester) {
    final texts = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (texts.evaluate().isEmpty) return null;
    return (texts.evaluate().first.widget as Text).data;
  }

  for (final (size, scale) in const [
    (Size(320, 700), 1.0),
    (Size(390, 844), 1.0),
    (Size(390, 844), 2.0),
  ]) {
    testWidgets('the selection bar fits a ${size.width.toInt()}px phone at '
        '${scale}x text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(
        tester,
        size: size,
        names: ['apple'],
        extra: (service) async {
          await service.createFolder('フォルダ');
        },
      );
      await tester.longPress(card('apple'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // 削除まで押せる位置にある（以前は86pxはみ出して削除が画面外だった）。
      final delete = find.byTooltip('ゴミ箱へ移動');
      expect(delete, findsOneWidget);
      final rect = tester.getRect(delete);
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.left, greaterThanOrEqualTo(0));
    });
  }

  testWidgets('bulk delete leaves favorites and folders, and can be undone', (
    tester,
  ) async {
    final service = await boot(
      tester,
      names: ['apple', 'banana'],
      extra: (service) async {
        await service.toggleFavorite(
          service.projects.firstWhere((p) => p.name == 'banana').id,
        );
        await service.createFolder('フォルダ');
      },
    );
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(card('banana'));
    await tester.tap(card('フォルダ'));
    await settle(tester);
    await tester.tap(find.byTooltip('ゴミ箱へ移動'));
    await settle(tester);
    expect(find.text('1件をゴミ箱へ移動しますか？'), findsOneWidget);
    expect(find.textContaining('お気に入りの1件は移動しません'), findsOneWidget);
    expect(find.textContaining('フォルダ1件は移動しません'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '移動'));
    await settle(tester);
    expect(service.projects.map((p) => p.name), ['banana']);
    expect(service.folders.map((f) => f.name), ['フォルダ']);
    expect(snackText(tester), '1件をゴミ箱へ移動しました');
    await tester.tap(find.text('元に戻す'));
    await settleIo(tester);
    expect(service.projects.map((p) => p.name).toSet(), {'apple', 'banana'});
    // 戻した作品は中身ごと読み直され、一覧に出る。
    final apple = service.projects.firstWhere((p) => p.name == 'apple');
    expect(service.scenesOf(apple.id), isNotEmpty);
    expect(card('apple'), findsOneWidget);
  });

  testWidgets('bulk delete of only favorites says nothing can move', (
    tester,
  ) async {
    final service = await boot(
      tester,
      names: ['banana'],
      extra: (service) async {
        await service.toggleFavorite(service.projects.single.id);
      },
    );
    await tester.longPress(card('banana'));
    await settle(tester);
    await tester.tap(find.byTooltip('ゴミ箱へ移動'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(snackText(tester), contains('ゴミ箱へ移動できる作品がありません'));
    expect(service.projects, hasLength(1));
  });

  testWidgets('a cut folder pasted into itself stays cut and says why', (
    tester,
  ) async {
    final service = await boot(
      tester,
      extra: (service) async {
        await service.createFolder('親');
      },
    );
    await tester.longPress(card('親'));
    await settle(tester);
    await tester.tap(find.byTooltip('切り取り'));
    await settle(tester);
    expect(snackText(tester), contains('1件を切り取りました'));
    // 切り取った項目は薄く表示される。
    expect(
      find.ancestor(of: card('親'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    await tester.tap(card('親'));
    await settle(tester);
    await tester.tap(find.byTooltip('1件を貼り付け'));
    await settleIo(tester);
    expect(snackText(tester), contains('自分自身やその中へは移動できない'));
    expect(service.folders.single.parentFolderId, isNull);
    // まだ切り取ったままなので、別の場所へ貼り付けられる。
    expect(find.byTooltip('1件を貼り付け'), findsOneWidget);
  });

  testWidgets('pasting a copy of a work that was trashed says so', (
    tester,
  ) async {
    final service = await boot(tester, names: ['apple', 'banana']);
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('コピー'));
    await settle(tester);
    expect(snackText(tester), contains('1件をコピーしました'));
    await tester.runAsync(
      () => service.deleteProject(
        service.projects.firstWhere((p) => p.name == 'apple').id,
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('1件を貼り付け'));
    await settleIo(tester);
    expect(snackText(tester), contains('元の作品が見つからない'));
    expect(service.projects.map((p) => p.name), ['banana']);
  });

  testWidgets('a pasted copy gets its own materials and thumbnail', (
    tester,
  ) async {
    late String sourceId;
    final service = await boot(
      tester,
      extra: (service) async {
        final source = await service.createProject(
          name: 'apple',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        sourceId = source.id;
        final materials = Directory(
          '${tempDir.path}/niarim/projects/$sourceId/Materials',
        )..createSync(recursive: true);
        File('${materials.path}/m1.png').writeAsBytesSync([1, 2, 3]);
        File(
          '${materials.path}/materials.json',
        ).writeAsStringSync('{"nextCounter":1,"materials":[]}');
        await service.generateAndSaveThumbnail(sourceId);
      },
    );
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('コピー'));
    await settle(tester);
    await tester.tap(find.byTooltip('1件を貼り付け'));
    await settleIo(tester);
    final copy = service.projects.firstWhere((p) => p.id != sourceId);
    expect(copy.name, 'apple (コピー)');
    final copied = Directory(
      '${tempDir.path}/niarim/projects/${copy.id}/Materials',
    );
    expect(File('${copied.path}/m1.png').readAsBytesSync(), [1, 2, 3]);
    expect(File('${copied.path}/materials.json').existsSync(), isTrue);
    // サムネイルは複製元と別のファイル（複製元を消しても残る）。
    final original = service.projects.firstWhere((p) => p.id == sourceId);
    expect(copy.thumbnailPath, isNotNull);
    expect(copy.thumbnailPath, isNot(original.thumbnailPath));
    expect(copy.thumbnailPath, contains(copy.id));
    expect(File(copy.thumbnailPath!).existsSync(), isTrue);
  });

  testWidgets('pasting the same copy again numbers the new copies', (
    tester,
  ) async {
    final service = await boot(
      tester,
      extra: (service) => service.createProject(
        name: 'apple',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      ),
    );
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('コピー'));
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('1件を貼り付け'));
      await settleIo(tester);
    }
    expect(service.projects.map((p) => p.name).toSet(), {
      'apple',
      'apple (コピー)',
      'apple (コピー 2)',
      'apple (コピー 3)',
    });
  });

  testWidgets('right-clicking a card opens its menu', (tester) async {
    await boot(tester, names: ['apple']);
    await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
    await settle(tester);
    expect(find.text('名前変更'), findsOneWidget);
    expect(find.text('ゴミ箱へ移動'), findsOneWidget);
    await tester.tap(find.text('名前変更'));
    await settle(tester);
    expect(find.byType(NameEntryDialog), findsOneWidget);
  });

  testWidgets('Escape ends selection', (tester) async {
    await boot(tester, names: ['apple']);
    await tester.longPress(card('apple'));
    await settle(tester);
    expect(find.text('1件選択中'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('1件選択中'), findsNothing);
  });

  testWidgets('names must not be blank; Enter renames; a double tap makes one '
      'folder', (tester) async {
    final service = await boot(tester, names: ['apple']);
    await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
    await settle(tester);
    await tester.tap(find.text('名前変更'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final change = find.widgetWithText(FilledButton, '変更');
    expect(tester.widget<FilledButton>(change).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  りんご  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(service.projects.single.name, 'りんご');

    var created = 0;
    final context = tester.element(find.byType(ProjectListWidget));
    showCreateFolderNameDialog(context, (name) async {
      created++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'シリーズ');
    await tester.pump();
    final create = find.widgetWithText(FilledButton, '作成');
    await tester.tap(create);
    await tester.tap(create, warnIfMissed: false);
    await settle(tester);
    expect(created, 1);
  });

  testWidgets('moving one work to the trash from its menu can be undone', (
    tester,
  ) async {
    final service = await boot(tester, names: ['apple']);
    await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
    await settle(tester);
    await tester.tap(find.text('ゴミ箱へ移動'));
    await settle(tester);
    expect(service.projects, isEmpty);
    expect(snackText(tester), '1件をゴミ箱へ移動しました');
    await tester.tap(find.text('元に戻す'));
    await settleIo(tester);
    expect(service.projects.single.name, 'apple');
    expect(service.scenesOf(service.projects.single.id), isNotEmpty);
    expect(card('apple'), findsOneWidget);
  });

  testWidgets('the undo bar goes away by itself', (tester) async {
    await boot(tester, names: ['apple']);
    await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
    await settle(tester);
    await tester.tap(find.text('ゴミ箱へ移動'));
    await settle(tester);
    expect(find.text('元に戻す'), findsOneWidget);
    // 操作ボタン付きのSnackBarは既定では消えず、次の画面のツールバーに
    // 重なり続けた。
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('undo puts a work back at the top when its folder is gone', (
    tester,
  ) async {
    late String folderId;
    final service = await boot(
      tester,
      extra: (service) async {
        folderId = (await service.createFolder('箱')).id;
        final project = await service.createProject(
          name: 'apple',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await service.moveToFolder(project.id, folderId);
      },
    );
    final id = service.projects.single.id;
    await tester.tap(card('箱'));
    await settle(tester);
    await tester.tap(card('apple'), buttons: kSecondaryMouseButton);
    await settle(tester);
    await tester.tap(find.text('ゴミ箱へ移動'));
    await settle(tester);
    await tester.runAsync(() => service.deleteFolder(folderId));
    await tester.tap(find.text('元に戻す'));
    await settleIo(tester);
    expect(service.projects.single.folderId, isNull);
    // 一番上の一覧に出る（消えたフォルダを指したままだと検索でしか
    // 見つからなかった）。
    await tester.tap(find.byIcon(Icons.home).first);
    await settle(tester);
    expect(card('apple'), findsOneWidget);
    expect(service.projects.single.id, id);
  });

  testWidgets('the selection bar is one line when it fits', (tester) async {
    await boot(tester, size: const Size(1280, 800), names: ['apple']);
    await tester.longPress(card('apple'));
    await settle(tester);
    final selectAll = tester.getCenter(find.text('全選択'));
    final delete = tester.getCenter(find.byTooltip('ゴミ箱へ移動'));
    // 同じ行の左端と右端（以前はどの幅でも2行で、左上と右下に分かれた）。
    expect(delete.dy, moreOrLessEquals(selectAll.dy, epsilon: 1));
    expect(selectAll.dx, lessThan(200));
    expect(delete.dx, greaterThan(1100));
  });

  testWidgets('on a phone the bar stays on one line without bulk favorites', (
    tester,
  ) async {
    await boot(tester, size: const Size(390, 844), names: ['apple']);
    await tester.longPress(card('apple'));
    await settle(tester);
    final selectAll = tester.getCenter(find.text('全選択'));
    final delete = tester.getCenter(find.byTooltip('ゴミ箱へ移動'));
    // 1行のまま、全選択は左、ゴミ箱は右。
    expect(delete.dy, moreOrLessEquals(selectAll.dy, epsilon: 1));
    expect(selectAll.dx, lessThan(80));
    expect(delete.dx, greaterThan(330));
    // お気に入りは一括では付け外ししない（各項目のメニューから）。
    expect(find.byTooltip('お気に入りに登録'), findsNothing);
    expect(find.byTooltip('お気に入りを解除'), findsNothing);
    // 収まる幅では全選択・全解除は文字のまま。
    expect(find.byIcon(Icons.select_all), findsNothing);
    expect(find.byIcon(Icons.deselect), findsNothing);
  });

  // 仏語の「Tout sélectionner」「Tout désélectionner」はどちらも「Tou…」、
  // 韓国語の「전체 선택」「전체 선택 해제」はどちらも「전체 …」と同じに
  // 省略され、2つのボタンを見分けられなかった。省略されるほど狭いときは
  // 2つともアイコンにする（全文はツールチップ）。
  for (final language in const ['fr', 'ko']) {
    testWidgets('at 320px in $language, select and deselect become icons', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'home_view_mode': 'medium',
        'language': language,
      });
      final l10n = lookupAppLocalizations(Locale(language));
      await boot(tester, size: const Size(320, 700), names: ['apple', 'pear']);
      await tester.longPress(card('apple'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.homeSelectionAllSelect), findsNothing);
      expect(find.text(l10n.homeSelectionAllDeselect), findsNothing);
      final selectAll = find.byTooltip(l10n.homeSelectionAllSelect);
      final deselectAll = find.byTooltip(l10n.homeSelectionAllDeselect);
      expect(
        find.descendant(of: selectAll, matching: find.byIcon(Icons.select_all)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: deselectAll, matching: find.byIcon(Icons.deselect)),
        findsOneWidget,
      );
      // 押せば今までどおり全選択・全解除になる。
      await tester.tap(selectAll);
      await settle(tester);
      expect(find.byTooltip(l10n.homeSelectionCount(2)), findsOneWidget);
      await tester.tap(deselectAll);
      await settle(tester);
      expect(find.byIcon(Icons.content_cut), findsNothing);
    });
  }

  testWidgets('Ctrl+C with a folder selected keeps the clipboard', (
    tester,
  ) async {
    await boot(
      tester,
      names: ['apple', 'banana'],
      extra: (service) async {
        await service.createFolder('箱');
      },
    );
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('切り取り'));
    await settle(tester);
    await tester.longPress(card('banana'));
    await settle(tester);
    await tester.tap(card('箱'));
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(snackText(tester), contains('フォルダはコピーできません'));
    // 選択も、前に切り取った作品もそのまま。
    expect(find.text('2件選択中'), findsOneWidget);
    expect(find.byTooltip('1件を貼り付け'), findsOneWidget);
  });

  testWidgets('Escape closes the drawer before ending selection', (
    tester,
  ) async {
    await boot(tester, names: ['apple']);
    await tester.longPress(card('apple'));
    await settle(tester);
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffold.openDrawer();
    await settle(tester);
    expect(scaffold.isDrawerOpen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(scaffold.isDrawerOpen, isFalse);
    expect(find.text('1件選択中'), findsOneWidget);
  });

  testWidgets('a cut can be cancelled; screen readers hear it is cut', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await boot(tester, names: ['apple']);
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('切り取り'));
    await settle(tester);
    // 読み上げが止まる、押せるカードの節に付く。
    expect(
      tester.getSemantics(card('apple')).parent,
      isSemantics(hint: '切り取り中（貼り付けを待っています）', hasTapAction: true),
    );
    // SnackBarの「元に戻す」でやめられる。
    await tester.tap(find.text('元に戻す'));
    await settle(tester);
    expect(find.byTooltip('1件を貼り付け'), findsNothing);
    expect(
      find.ancestor(of: card('apple'), matching: find.byType(Opacity)),
      findsNothing,
    );
    // Escでもやめられる。
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('切り取り'));
    await settle(tester);
    expect(find.byTooltip('1件を貼り付け'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byTooltip('1件を貼り付け'), findsNothing);
    handle.dispose();
  });

  testWidgets('a paste that fails part way says so and adds no copy', (
    tester,
  ) async {
    final service = await boot(tester, names: ['apple']);
    await tester.longPress(card('apple'));
    await settle(tester);
    await tester.tap(find.byTooltip('コピー'));
    await settle(tester);
    // 作品のフォルダが取れない状態にする。
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        throw PlatformException(code: 'gone');
      }
      return tempDir.path;
    });
    await tester.tap(find.byTooltip('1件を貼り付け'));
    await settleIo(tester);
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => tempDir.path,
    );
    expect(snackText(tester), contains('一部を貼り付けられませんでした'));
    // 素材を写せないうちは、複製を一覧へ加えない。
    expect(service.projects, hasLength(1));
    // 貼り付けはもう一度できる。
    expect(find.byTooltip('1件を貼り付け'), findsOneWidget);
  });

  testWidgets('a name dialog that fails to save stays open', (tester) async {
    await boot(tester);
    final context = tester.element(find.byType(ProjectListWidget));
    var calls = 0;
    showCreateFolderNameDialog(context, (name) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (calls == 1) throw const FileSystemException('full');
    });
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'シリーズ');
    await tester.pump();
    final create = find.widgetWithText(FilledButton, '作成');
    await tester.tap(create);
    await tester.pump(const Duration(milliseconds: 10));
    // 保存中は取り消しも戻るも効かない。
    final cancel = find.widgetWithText(TextButton, 'キャンセル');
    expect(tester.widget<TextButton>(cancel).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(NameEntryDialog), findsOneWidget);
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    await tester.tap(create);
    await settle(tester);
    expect(calls, 2);
    expect(find.byType(NameEntryDialog), findsNothing);
    // ホームは閉じていない。
    expect(find.byType(ProjectListWidget), findsOneWidget);
  });
}
