import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// フォルダをゴミ箱へ移すと中身（下の階層のフォルダ・作品）も一緒に移り、
/// ゴミ箱でフォルダを戻すと中身もすべて元の場所へ戻る。フォルダは中身ごと
/// 複製できる（ユーザー指定）。パンくずは指で押せる大きさで、深い階層でも
/// 今いるフォルダが見える。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_folder_trash_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'home_view_mode': 'medium',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<Project> work(ProjectService service, String name) async {
    final project = await service.createProject(
      name: name,
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
    );
    // 作った順に並ぶよう、更新日時を少しずらす。
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return project;
  }

  /// 親 ─ 子 ─ 孫 の3階層に、親・子・孫それぞれ1作品ずつと、一番上に1作品。
  Future<
    ({
      ProjectFolder parent,
      ProjectFolder child,
      ProjectFolder grandchild,
      Map<String, Project> works,
    })
  >
  tree(ProjectService service) async {
    final parent = await service.createFolder('親');
    final child = await service.createFolder('子', parentFolderId: parent.id);
    final grandchild = await service.createFolder(
      '孫',
      parentFolderId: child.id,
    );
    final works = <String, Project>{};
    for (final (name, folder) in [
      ('上の作品', null),
      ('親の作品', parent.id),
      ('子の作品', child.id),
      ('孫の作品', grandchild.id),
    ]) {
      final project = await work(service, name);
      if (folder != null) await service.moveToFolder(project.id, folder);
      works[name] = project;
    }
    return (parent: parent, child: child, grandchild: grandchild, works: works);
  }

  Map<String, String?> folderOf(ProjectService service) => {
    for (final p in service.projects) p.name: p.folderId,
  };

  group('service', () {
    test('a folder goes to the trash with everything inside it', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      expect(service.folderContentCounts(t.parent.id), (
        projects: 3,
        folders: 2,
      ));
      final record = await service.moveFolderToTrash(t.parent.id);
      expect(record, isNotNull);
      expect(service.folders, isEmpty);
      expect(service.projects.map((p) => p.name), ['上の作品']);
      expect(service.trash.map((p) => p.name).toSet(), {
        '親の作品',
        '子の作品',
        '孫の作品',
      });
      // ゴミ箱の一覧には、フォルダと一緒に移した作品を1件ずつは出さない。
      expect(service.looseTrash, isEmpty);
      expect(service.trashedFolders.single.folder.id, t.parent.id);
      expect(service.trashedFolders.single.subfolders.map((f) => f.name), [
        '子',
        '孫',
      ]);
      expect(
        service.trashedFolderOf(t.works['孫の作品']!.id)?.folder.id,
        t.parent.id,
      );

      await service.restoreTrashedFolder(t.parent.id);
      expect(service.trashedFolders, isEmpty);
      expect(service.trash, isEmpty);
      expect(service.folders.map((f) => f.name).toSet(), {'親', '子', '孫'});
      expect(
        service.folders.firstWhere((f) => f.name == '孫').parentFolderId,
        t.child.id,
      );
      expect(folderOf(service), {
        '上の作品': null,
        '親の作品': t.parent.id,
        '子の作品': t.child.id,
        '孫の作品': t.grandchild.id,
      });
      // 戻した作品は中身ごと読み直される。
      for (final p in service.projects) {
        expect(service.scenesOf(p.id), isNotEmpty, reason: p.name);
      }
    });

    test('a work trashed on its own stays in the trash on its own', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      await service.deleteProject(t.works['子の作品']!.id);
      await service.moveFolderToTrash(t.parent.id);
      expect(service.looseTrash.map((p) => p.name), ['子の作品']);
      expect(service.trashedFolders.single.projectIds, hasLength(2));
      await service.restoreTrashedFolder(t.parent.id);
      expect(service.looseTrash.map((p) => p.name), ['子の作品']);
      // 後から戻すと、戻ったフォルダへ入る。
      await service.restoreProject(t.works['子の作品']!.id);
      expect(folderOf(service)['子の作品'], t.child.id);
    });

    test('a folder whose parent is gone comes back at the top', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      await service.moveFolderToTrash(t.child.id);
      expect(service.folders.map((f) => f.name), ['親']);
      await service.moveFolderToTrash(t.parent.id);
      // 親を先に戻すと、子は親の中へ戻る。
      await service.restoreTrashedFolder(t.parent.id);
      await service.restoreTrashedFolder(t.child.id);
      expect(
        service.folders.firstWhere((f) => f.name == '子').parentFolderId,
        t.parent.id,
      );
      // 親がゴミ箱のままなら、子は一番上へ戻る。
      await service.moveFolderToTrash(t.child.id);
      await service.moveFolderToTrash(t.parent.id);
      await service.restoreTrashedFolder(t.child.id);
      final child = service.folders.firstWhere((f) => f.name == '子');
      expect(child.parentFolderId, isNull);
      expect(
        service.folders.firstWhere((f) => f.name == '孫').parentFolderId,
        child.id,
      );
      expect(folderOf(service)['孫の作品'], t.grandchild.id);
      expect(service.trashedFolders.single.folder.name, '親');
    });

    test('deleting a trashed folder deletes the works inside', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      final base = await NiaproSerializer.projectsBasePath();
      final dirs = [
        for (final name in ['親の作品', '孫の作品']) '$base/${t.works[name]!.id}',
      ];
      for (final dir in dirs) {
        expect(Directory(dir).existsSync(), isTrue);
      }
      await service.moveFolderToTrash(t.parent.id);
      await service.permanentDeleteTrashedFolder(t.parent.id);
      expect(service.trashedFolders, isEmpty);
      expect(service.trash, isEmpty);
      expect(service.projects.map((p) => p.name), ['上の作品']);
      for (final dir in dirs) {
        expect(Directory(dir).existsSync(), isFalse, reason: dir);
      }
    });

    test('emptying the trash removes folders and works', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      await service.deleteProject(t.works['上の作品']!.id);
      await service.moveFolderToTrash(t.parent.id);
      await service.emptyTrash();
      expect(service.trashedFolders, isEmpty);
      expect(service.trash, isEmpty);
      expect(service.projects, isEmpty);
    });

    test('the trash keeps folders after a restart and expires them', () async {
      final first = ProjectService();
      await first.init();
      final t = await tree(first);
      await first.moveFolderToTrash(t.parent.id);

      final second = ProjectService();
      await second.init();
      expect(second.trashedFolders.single.folder.name, '親');
      expect(second.looseTrash, isEmpty);
      expect(second.trash, hasLength(3));

      // 30日より前にゴミ箱へ移したことにして、自動削除を走らせる。
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('trashed_project_folders')!)
              as List<dynamic>;
      (saved.single as Map<String, dynamic>)['deletedAt'] = DateTime.now()
          .subtract(const Duration(days: 31))
          .toIso8601String();
      await prefs.setString('trashed_project_folders', jsonEncode(saved));
      final third = ProjectService();
      await third.init();
      await third.sweepExpiredTrash(30);
      expect(third.trashedFolders, isEmpty);
      expect(third.trash, isEmpty);

      final fourth = ProjectService();
      await fourth.init();
      expect(fourth.trashedFolders, isEmpty);
      expect(fourth.projects.map((p) => p.name), ['上の作品']);
    });

    test('a restored folder is restored after a restart too', () async {
      final first = ProjectService();
      await first.init();
      final t = await tree(first);
      await first.moveFolderToTrash(t.parent.id);
      final second = ProjectService();
      await second.init();
      await second.restoreTrashedFolder(t.parent.id);
      final third = ProjectService();
      await third.init();
      expect(third.trashedFolders, isEmpty);
      expect(third.folders, hasLength(3));
      expect(folderOf(third)['孫の作品'], t.grandchild.id);
    });

    test('a new or renamed folder gets a number when the name is taken '
        'at its level', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      expect((await service.createFolder('親')).name, '親 (2)');
      expect((await service.createFolder('親')).name, '親 (3)');
      // ほかの階層の同じ名前は数えない。
      expect(
        (await service.createFolder('孫', parentFolderId: t.parent.id)).name,
        '孫',
      );
      expect(
        (await service.createFolder('子', parentFolderId: t.parent.id)).name,
        '子 (2)',
      );
      // 名前の変更：自分自身は数えない。
      await service.renameFolder(t.parent.id, '親');
      expect(service.folders.firstWhere((f) => f.id == t.parent.id).name, '親');
      final other = service.folders.firstWhere((f) => f.name == '親 (2)');
      await service.renameFolder(other.id, '親 (3)');
      expect(service.folders.firstWhere((f) => f.id == other.id).name, '親 (4)');
    });

    test('a folder copy copies the folders and works inside', () async {
      final service = ProjectService();
      await service.init();
      final t = await tree(service);
      final copy = await service.duplicateFolder(t.parent.id, name: '親 (コピー)');
      expect(copy, isNotNull);
      expect(copy!.parentFolderId, isNull);
      final copiedChild = service.folders.singleWhere(
        (f) => f.name == '子' && f.parentFolderId == copy.id,
      );
      final copiedGrandchild = service.folders.singleWhere(
        (f) => f.name == '孫' && f.parentFolderId == copiedChild.id,
      );
      expect(service.folders, hasLength(6));
      final inCopy = {
        for (final p in service.projects)
          if (p.folderId == copy.id ||
              p.folderId == copiedChild.id ||
              p.folderId == copiedGrandchild.id)
            p.name: p.folderId,
      };
      expect(inCopy, {
        '親の作品': copy.id,
        '子の作品': copiedChild.id,
        '孫の作品': copiedGrandchild.id,
      });
      // 元はそのまま。
      expect(service.folderContentCounts(t.parent.id), (
        projects: 3,
        folders: 2,
      ));
      for (final p in service.projects) {
        expect(service.scenesOf(p.id), isNotEmpty, reason: p.name);
      }
    });

    test(
      'a folder can be copied into itself without copying the copy',
      () async {
        final service = ProjectService();
        await service.init();
        final t = await tree(service);
        final copy = await service.duplicateFolder(
          t.parent.id,
          targetParentId: t.grandchild.id,
          name: '親 (コピー)',
        );
        expect(copy!.parentFolderId, t.grandchild.id);
        expect(service.folders, hasLength(6));
        expect(service.projects, hasLength(7));
        expect(service.folderContentCounts(copy.id), (projects: 3, folders: 2));
      },
    );
  });

  group('home', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> settleIo(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // ファイルを読み直す処理（ゴミ箱から戻す等）が終わるまで実時間で待つ。
    Future<void> waitFor(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settle(tester);
    }

    Future<ProjectService> boot(
      WidgetTester tester, {
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
      await tester.runAsync(() => tree(service));
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await settle(tester);
      return service;
    }

    Finder card(String name) => find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.text(name),
    );

    Future<void> openFolderMenu(WidgetTester tester, String name) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: card(name), matching: find.byType(Card)).first,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await settle(tester);
    }

    testWidgets('the folder menu moves the folder and its contents to the '
        'trash, and undo brings them back', (tester) async {
      final service = await boot(tester);
      await openFolderMenu(tester, '親');
      await tester.tap(find.text('ゴミ箱へ移動').last);
      await settle(tester);
      expect(find.text('フォルダをゴミ箱へ移動しますか？'), findsOneWidget);
      // 本文は、移す件数の行と一緒に1つの文で出る。
      expect(
        find.textContaining('「親」をゴミ箱へ移動します。ゴミ箱からフォルダごと元に戻せます。'),
        findsOneWidget,
      );
      expect(
        find.textContaining('フォルダの中のプロジェクト3件・フォルダ2件も一緒に移動します。'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '移動'));
      await settleIo(tester);
      expect(service.folders, isEmpty);
      expect(service.projects.map((p) => p.name), ['上の作品']);
      expect(find.text('「親」をゴミ箱へ移動しました'), findsOneWidget);
      await tester.tap(find.text('元に戻す'));
      await waitFor(tester, () => service.projects.length == 4);
      // 作品は一覧に戻った後もファイルから読み直しているので、戻し終わる
      // まで待つ（フォルダの処理は1つずつ順に動くので、次のフォルダの作成は
      // 戻し終わるのを待つ）。
      await settleIo(tester);
      expect(service.folders, hasLength(3));
      expect(service.projects, hasLength(4));
      expect(service.trash, isEmpty);
      expect(card('親'), findsOneWidget);

      // 空のフォルダでは中身の行を出さない。
      await tester.runAsync(() => service.createFolder('空'));
      await settle(tester);
      await openFolderMenu(tester, '空');
      await tester.tap(find.text('ゴミ箱へ移動').last);
      await settle(tester);
      expect(
        find.textContaining('「空」をゴミ箱へ移動します。ゴミ箱からフォルダごと元に戻せます。'),
        findsOneWidget,
      );
      expect(find.textContaining('も一緒に移動します'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the trash shows a folder with its works and restores or '
        'deletes it whole', (tester) async {
      final service = await boot(tester);
      await tester.runAsync(() async {
        await service.deleteProject(
          service.projects.firstWhere((p) => p.name == '上の作品').id,
        );
        await service.moveFolderToTrash(
          service.folders.firstWhere((f) => f.name == '親').id,
        );
      });
      appRouter.push('/trash');
      await settle(tester);
      final folder = find.byKey(
        ValueKey('trashedFolder_${service.trashedFolders.single.folder.id}'),
      );
      expect(folder, findsOneWidget);
      expect(
        find.descendant(
          of: folder,
          matching: find.textContaining('プロジェクト3件・フォルダ2件'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: folder, matching: find.text('親の作品、子の作品、孫の作品')),
        findsOneWidget,
      );
      // フォルダの中の作品は1件ずつ並ばない。単独で移した作品は並ぶ。
      expect(find.text('上の作品'), findsOneWidget);
      expect(find.text('子の作品'), findsNothing);

      final id = service.trashedFolders.single.folder.id;
      await tester.tap(find.byKey(ValueKey('trashedFolderRestore_$id')));
      await waitFor(tester, () => service.projects.length == 3);
      // 戻した作品をファイルから読み直し終わるまで待つ（次のフォルダの処理は
      // それを待ってから動く）。
      await settleIo(tester);
      expect(service.trashedFolders, isEmpty);
      expect(service.folders, hasLength(3));
      expect(folder, findsNothing);
      expect(find.text('上の作品'), findsOneWidget);

      await tester.runAsync(() => service.moveFolderToTrash(id));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('trashedFolderDelete_$id')));
      await settle(tester);
      // 確認はdev_branchの作り（失敗したらやり直せるダイアログ）で、本文は
      // 1つの文に2行で入る。
      expect(find.textContaining('「親」を完全に削除します。元に戻すことはできません。'), findsOneWidget);
      expect(
        find.textContaining('フォルダの中のプロジェクト3件・フォルダ2件も一緒に削除します。'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '削除'));
      // 中の作品を1件ずつファイルごと消し終わるまで待つ。
      await waitFor(tester, () => service.trash.length == 1);
      expect(service.trashedFolders, isEmpty);
      expect(service.trash.map((p) => p.name), ['上の作品']);
      expect(service.projects, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restore and delete sit in the same place on work and '
        'folder cards', (tester) async {
      final service = await boot(tester);
      late final String workId;
      late final String folderId;
      await tester.runAsync(() async {
        workId = service.projects.firstWhere((p) => p.name == '上の作品').id;
        await service.deleteProject(workId);
        folderId = service.folders.firstWhere((f) => f.name == '親').id;
        await service.moveFolderToTrash(folderId);
      });
      appRouter.push('/trash');
      await settle(tester);
      final settings = tester
          .element(find.byType(Scaffold).last)
          .read<SettingsService>();
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // カードの右下の角から見た位置（狭い画面・大きな文字では作品のカードが
      // 画面の下にあるので、見える所までスクロールしてから測る）。
      Future<Offset> fromCorner(Finder button) async {
        await tester.scrollUntilVisible(
          button,
          60,
          scrollable: find.byType(Scrollable).last,
        );
        await settle(tester);
        final card = tester.getRect(
          find.ancestor(of: button, matching: find.byType(Card)).first,
        );
        return card.bottomRight - tester.getRect(button).bottomRight;
      }

      for (final code in ['ja', 'fr', 'ko']) {
        await tester.runAsync(() => settings.setLanguage(code));
        for (final size in const [
          Size(320, 700),
          Size(390, 844),
          Size(800, 900),
        ]) {
          for (final scale in const [1.0, 2.0]) {
            final where = '$code ${size.width.toInt()} x$scale';
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await settle(tester);
            expect(tester.takeException(), isNull, reason: where);
            for (final (work, folder) in [
              (
                find.byKey(ValueKey('trashedProjectRestore_$workId')),
                find.byKey(ValueKey('trashedFolderRestore_$folderId')),
              ),
              (
                find.byKey(ValueKey('trashedProjectDelete_$workId')),
                find.byKey(ValueKey('trashedFolderDelete_$folderId')),
              ),
            ]) {
              final a = await fromCorner(work);
              final card = tester.getRect(
                find.ancestor(of: work, matching: find.byType(Card)).first,
              );
              final workCentre =
                  tester.getRect(work).center.dy - card.center.dy;
              // フォルダのカードは一覧の上の方にあるので、戻して測る。
              await tester.drag(
                find.byType(Scrollable).last,
                const Offset(0, 3000),
              );
              await settle(tester);
              final b = await fromCorner(folder);
              final folderCard = tester.getRect(
                find.ancestor(of: folder, matching: find.byType(Card)).first,
              );
              final folderCentre =
                  tester.getRect(folder).center.dy - folderCard.center.dy;
              // 狭い画面・大きな文字では名前の下の右端の別の行、広い画面では
              // 名前の右の上下の真ん中（どちらも作品とフォルダで同じ）。
              if (card.width < 600 * scale) {
                expect((a - b).distance, lessThan(0.5), reason: '$where $a $b');
              } else {
                expect((a.dx - b.dx).abs(), lessThan(0.5), reason: where);
                expect(workCentre.abs(), lessThan(0.5), reason: '$where work');
                expect(
                  folderCentre.abs(),
                  lessThan(0.5),
                  reason: '$where folder',
                );
              }
              expect(a.dx, greaterThanOrEqualTo(0), reason: where);
              expect(a.dy, greaterThanOrEqualTo(0), reason: where);
            }
          }
        }
      }
    });

    testWidgets('the folder menu copies a folder with its contents', (
      tester,
    ) async {
      final service = await boot(tester);
      await openFolderMenu(tester, '親');
      await tester.tap(find.text('複製').last);
      await settleIo(tester);
      await settleIo(tester);
      final copy = service.folders.singleWhere((f) => f.name == '親 (コピー)');
      expect(copy.parentFolderId, isNull);
      expect(service.folderContentCounts(copy.id), (projects: 3, folders: 2));
      expect(card('親 (コピー)'), findsOneWidget);
      await openFolderMenu(tester, '親');
      await tester.tap(find.text('複製').last);
      await settleIo(tester);
      await settleIo(tester);
      expect(service.folders.where((f) => f.name == '親 (コピー 2)'), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the folder edit dialog: colours big enough to press, '
        'no blank names, Enter saves', (tester) async {
      final service = await boot(tester);
      await openFolderMenu(tester, '親');
      await tester.tap(find.text('名前・色を編集').last);
      await settle(tester);
      final green = find.byTooltip('フォルダ色: #3DDC97');
      final size = tester.getSize(green);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(green);
      await settle(tester);
      // 空白だけの名前では保存できない。
      final field = find.byType(TextField).last;
      await tester.enterText(field, '   ');
      await settle(tester);
      final save = find.widgetWithText(FilledButton, '保存');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      // Enterで名前と色を保存する。
      await tester.enterText(field, '  背景  ');
      await settle(tester);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleIo(tester);
      expect(find.byType(AlertDialog), findsNothing);
      final folder = service.folders.firstWhere(
        (f) => f.id == service.folders.firstWhere((f) => f.name == '背景').id,
      );
      expect(folder.color, 0xFF3DDC97);
      expect(card('背景'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('breadcrumbs are big enough to press and show the current '
        'folder', (tester) async {
      final service = await boot(tester, size: const Size(320, 700));
      await tester.runAsync(() async {
        var parent = service.folders.firstWhere((f) => f.name == '孫').id;
        for (var i = 0; i < 4; i++) {
          parent = (await service.createFolder(
            'とても長い名前の階層$i',
            parentFolderId: parent,
          )).id;
        }
      });
      await settle(tester);
      for (final name in [
        '親',
        '子',
        '孫',
        'とても長い名前の階層0',
        'とても長い名前の階層1',
        'とても長い名前の階層2',
        'とても長い名前の階層3',
      ]) {
        await tester.tap(card(name));
        await settle(tester);
      }
      final crumbs = find.byKey(const Key('homeBreadcrumb'));
      final home = find.descendant(
        of: crumbs,
        matching: find.byIcon(Icons.home),
      );
      final current = find.descendant(
        of: crumbs,
        matching: find.text('とても長い名前の階層3'),
      );
      // 深い階層では、今いるフォルダ（右端）が見える。
      final view = tester.getRect(crumbs);
      final currentRect = tester.getRect(current);
      expect(currentRect.right, lessThanOrEqualTo(view.right + .5));
      expect(currentRect.left, greaterThanOrEqualTo(view.left - .5));
      for (final target in [
        find.ancestor(of: current, matching: find.byType(InkWell)).first,
      ]) {
        final rect = tester.getRect(target);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(
        tester.getSemantics(current),
        isSemantics(label: 'とても長い名前の階層3', isButton: true),
      );
      // 一番上（ホーム）へ戻るボタンも、名前が読み上げられ押せる大きさ。
      await tester.drag(crumbs, const Offset(2000, 0));
      await settle(tester);
      final homeTarget = find
          .ancestor(of: home, matching: find.byType(InkWell))
          .first;
      final homeRect = tester.getRect(homeTarget);
      expect(homeRect.width, greaterThanOrEqualTo(48));
      expect(homeRect.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(home),
        isSemantics(tooltip: 'フォルダなし（ルート）', isButton: true),
      );
      await tester.tap(homeTarget);
      await settle(tester);
      expect(crumbs, findsNothing);
      expect(card('親'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the contents phrase leaves out counts of zero in every language', () {
    final expected = {
      'ja': ['中身なし', 'フォルダ2件', 'プロジェクト1件', 'プロジェクト3件・フォルダ1件'],
      'en': ['Empty', '2 folders', '1 project', '3 projects and 1 folder'],
      'es': ['Vacía', '2 carpetas', '1 proyecto', '3 proyectos y 1 carpeta'],
      'fr': ['Vide', '2 dossiers', '1 projet', '3 projets et 1 dossier'],
      'ko': ['비어 있음', '폴더 2개', '프로젝트 1개', '프로젝트 3개, 폴더 1개'],
      'zh': ['空', '2个文件夹', '1个项目', '3个项目和1个文件夹'],
      'zh-Hant': ['空', '2個資料夾', '1個專案', '3個專案和1個資料夾'],
    };
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = appLocalizationsFor(locale);
      final tag = locale.toLanguageTag();
      expect(
        [
          l10n.homeFolderContents(0, 0),
          l10n.homeFolderContents(0, 2),
          l10n.homeFolderContents(1, 0),
          l10n.homeFolderContents(3, 1),
        ],
        expected[tag],
        reason: tag,
      );
      expect(
        l10n.homeMoveToTrashFolderContents(l10n.homeFolderContents(3, 1)),
        isNot(contains('0')),
        reason: tag,
      );
    }
  });
}
