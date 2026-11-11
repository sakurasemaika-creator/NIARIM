import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 作品の保存先（書類フォルダ/niarim/projects）はあるのに中を一覧できない
/// （権限が無い・入出力の失敗）と、起動が「save_tree」の段で止まり、起動
/// 失敗の画面から先へ進めなかった（保存の一覧を読む処理だけが、一覧の
/// 失敗を受けていなかった）。起動は続け、ホームで「プロジェクトを読み込め
/// ませんでした」と「再試行」を出し、読めるようになってから再試行すると
/// 作品とその手動の保存が読み込まれること。読めなかったものは消さず、
/// 書き換えもしないこと。
///
/// テストはrootで動き、chmodでは読めなくならないので、[_UnreadablePaths]
/// （IOOverrides）で決まったフォルダ・ファイルだけを読めないように見せる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Storage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
    AppErrorReporter.recentErrors.clear();
    storage = _Storage();
  });

  tearDown(() => storage.dispose());

  testWidgets('an unlistable projects folder does not stop startup, and Retry '
      'loads the works with their saves once', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seeded = await tester.runAsync(
      () => _seedProjectWithSaves(name: '読めなかった作品', comments: ['線画まで']),
    );
    final (project, saves) = seeded!;

    storage.paths.blockListing(storage.projectsPath);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    expect(providers, isNotNull, reason: 'startup stopped');
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final notice = find.byKey(const Key('homeProjectsLoadFailed'));
    expect(notice, findsOneWidget);
    expect(find.text('プロジェクトを読み込めませんでした'), findsOneWidget);
    expect(find.text('読めなかった作品'), findsNothing);
    expect(
      _recorded('Directory listing failed', 'save_tree_service.dart'),
      isTrue,
      reason: 'the save lists must record the folder they could not list',
    );

    final context = tester.element(find.byType(Scaffold).first);
    final projects = context.read<ProjectService>();
    final saveTree = context.read<SaveTreeService>();
    expect(saveTree.getNodes(project.id), isEmpty);

    // 読めるようになってから「再試行」を押す。
    storage.paths.clear();
    await tester.tap(find.descendant(of: notice, matching: find.text('再試行')));
    for (
      var i = 0;
      i < 40 &&
          (find.text('読めなかった作品').evaluate().isEmpty ||
              saveTree.getNodes(project.id).isEmpty);
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
    expect(find.text('読めなかった作品'), findsOneWidget);
    expect(saveTree.getNodes(project.id).map((n) => n.id), [saves.single.id]);
    expect(saveTree.getNodes(project.id).single.comment, '線画まで');

    // もう一度読み直しても、作品も保存も二重にならない。
    await tester.runAsync(projects.retryLoadProjects);
    await tester.pumpAndSettle();
    expect(projects.projects.where((p) => p.id == project.id), hasLength(1));
    expect(saveTree.getNodes(project.id), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('save lists: a projects folder that cannot be listed is recorded and '
      'skipped', () async {
    final (project, _) = await _seedProjectWithSaves(comments: ['A']);
    storage.paths.blockListing(storage.projectsPath);

    final service = SaveTreeService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.getNodes(project.id), isEmpty);
    expect(
      _recorded('Directory listing failed', 'save_tree_service.dart'),
      isTrue,
    );
  });

  // 保存先を読めなかった起動では、ゴミ箱の中身が分からない。期限切れの
  // フォルダを片付けると、フォルダの記録だけが消えて中の作品はゴミ箱に
  // 1件ずつ残った（読めなかったものを書き換えた）。
  test(
    'expired trash is not cleaned up while the works could not be read',
    () async {
      final (project, _) = await _seedProjectWithSaves(comments: const []);
      final deletedAt = DateTime.now().subtract(const Duration(days: 90));
      final trashedFolders = jsonEncode([
        TrashedFolder(
          folder: ProjectFolder(id: 'folder_old', name: '古いフォルダ'),
          subfolders: const [],
          projectIds: [project.id],
          deletedAt: deletedAt,
        ).toJson(),
      ]);
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'trashed_projects': ['${project.id}|${deletedAt.toIso8601String()}'],
        'trashed_project_folders': trashedFolders,
      });
      storage.paths.blockListing(storage.projectsPath);

      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.projectsLoadFailed, isTrue);
      await service.sweepExpiredTrash(30);

      expect(service.trashedFolders.map((t) => t.folder.id), ['folder_old']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('trashed_project_folders'), trashedFolders);
      expect(prefs.getStringList('trashed_projects'), [
        '${project.id}|${deletedAt.toIso8601String()}',
      ]);
      expect(
        Directory('${storage.projectsPath}/${project.id}').existsSync(),
        isTrue,
      );

      // 読めるようになれば、作品はフォルダと一緒にゴミ箱に戻る。
      storage.paths.clear();
      await service.retryLoadProjects();
      expect(service.projectsLoadFailed, isFalse);
      expect(service.trash.map((p) => p.id), [project.id]);
      expect(service.trashedFolderOf(project.id)?.folder.id, 'folder_old');
    },
  );

  // 保存の一覧（SaveTree/index.json）を読めなかった作品へ保存すると、
  // 読んでいない一覧を新しい保存1件だけの一覧で上書きし、前の保存の
  // コメント・スロット・枝分かれが失われた。
  test(
    'a save list that cannot be read is not overwritten by the next save',
    () async {
      final (project, saves) = await _seedProjectWithSaves(
        comments: ['A', 'B'],
      );
      final indexPath =
          '${storage.projectsPath}/${project.id}/SaveTree/'
          '${SaveTreeService.indexFileName}';
      final before = File(indexPath).readAsStringSync();
      storage.paths.blockReading(indexPath);

      final service = SaveTreeService()..setSlotMax(5);
      addTearDown(service.dispose);
      await service.init();
      expect(_recorded('Permission denied', 'save_tree_service.dart'), isTrue);
      final added = await _saveToSlot(service, project, 2, 'C');
      expect(service.getNodes(project.id).map((n) => n.id), contains(added.id));

      storage.paths.clear();
      expect(File(indexPath).readAsStringSync(), before);
      // 次に起動したときは、前の保存がコメントごと戻り、新しい保存も残る。
      final again = SaveTreeService()..setSlotMax(5);
      addTearDown(again.dispose);
      await again.init();
      final nodes = {for (final n in again.getNodes(project.id)) n.id: n};
      expect(nodes[saves[0].id]?.comment, 'A');
      expect(nodes[saves[1].id]?.comment, 'B');
      expect(nodes.keys, contains(added.id));
    },
  );

  // 作品の保存のフォルダ（SaveTree/）の中を一覧できないと、読めた一覧の
  // 保存まで出さず（作品ごと飛ばし）、次の保存でその一覧を上書きした。
  test('saves in a readable list come back even if their folder cannot be '
      'listed', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final folder = '${storage.projectsPath}/${project.id}/SaveTree';
    storage.paths.blockListing(folder);

    final service = SaveTreeService()..setSlotMax(5);
    addTearDown(service.dispose);
    await service.init();
    expect(service.getNodes(project.id).map((n) => n.comment), ['A', 'B']);
    expect(
      _recorded('Directory listing failed', 'save_tree_service.dart'),
      isTrue,
    );
    final added = await _saveToSlot(service, project, 2, 'C');

    storage.paths.clear();
    final again = SaveTreeService()..setSlotMax(5);
    addTearDown(again.dispose);
    await again.init();
    expect(again.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
      added.id,
    ]);
    expect(again.getNodes(project.id).map((n) => n.comment), ['A', 'B', 'C']);
  });

  // 作品のフォルダに入れない（中のファイルがあるかどうかも分からない）と、
  // 作品は何も記録されないまま一覧から消えていた。
  test('a work whose folder cannot be entered is recorded, not dropped '
      'silently', () async {
    final (project, _) = await _seedProjectWithSaves(comments: const []);
    final archive =
        '${storage.projectsPath}/${project.id}/${project.id}.niapro';
    storage.paths.blockEntering(archive);

    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.projects, isEmpty);
    expect(_recorded(project.id, 'project_service.dart'), isTrue);
    // 読めなかった作品があることをホームで知らせ、「再試行」を出す
    // （空の一覧だけだと、作品が消えたように見える）。
    expect(service.projectsLoadFailed, isTrue);

    storage.paths.clear();
    final again = ProjectService();
    addTearDown(again.dispose);
    await again.init();
    expect(again.projects.map((p) => p.id), [project.id]);
  });

  test(
    'saved shares: a projects folder that cannot be listed is recorded',
    () async {
      Directory(storage.projectsPath).createSync(recursive: true);
      storage.paths.blockListing(storage.projectsPath);
      final service = ProjectService();
      addTearDown(service.dispose);
      await service.refreshOutgoingShares();
      expect(
        _recorded('Directory listing failed', 'outgoing_share_library.dart'),
        isTrue,
      );
    },
  );

  // 書類フォルダを取れなかった起動（DISC003）でも同じ：再試行で作品を
  // 読めたら、その作品の手動の保存も読む（以前は次に起動するまで、
  // どのスロットも「保存データなし」だった）。
  test('Retry after the documents folder was unavailable also loads the '
      'saves', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A']);
    storage.failDocuments = true;
    final created = <ChangeNotifier>[];
    await buildAppProviders(debugOnCreated: created.add);
    addTearDown(() {
      for (final service in created.reversed) {
        service.dispose();
      }
    });
    final projects = created.whereType<ProjectService>().single;
    final saveTree = created.whereType<SaveTreeService>().single;
    expect(projects.projectsLoadFailed, isTrue);
    expect(saveTree.getNodes(project.id), isEmpty);

    storage.failDocuments = false;
    await projects.retryLoadProjects();
    expect(projects.projects.map((p) => p.id), [project.id]);
    expect(saveTree.getNodes(project.id).map((n) => n.id), [saves.single.id]);
  });

  // 保存のフォルダ（SaveTree/）はあるが中へ入れない（chmod 000・入出力の
  // 失敗）と、一覧（index.json）は「無い」ように見え（existsSyncはfalse）、
  // 作品は「一覧を読んだ（保存は無い）」扱いになった。同じ起動中に入れる
  // ようになってから保存すると、読んでいない一覧を新しい保存1件だけの
  // 一覧で上書きし、前の保存のコメント・スロットが失われた。
  test('a save folder that cannot be entered is not taken as read; the next '
      'save keeps its unread list', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final folder = '${storage.projectsPath}/${project.id}/SaveTree';
    final indexPath = '$folder/${SaveTreeService.indexFileName}';
    final before = File(indexPath).readAsStringSync();
    storage.paths
      ..blockEntering(indexPath)
      ..blockListing(folder);

    final service = SaveTreeService()..setSlotMax(5);
    addTearDown(service.dispose);
    await service.init();
    expect(service.getNodes(project.id), isEmpty);
    expect(_recorded('Permission denied', 'save_tree_service.dart'), isTrue);

    // 一覧の有無がまだ分からない（入出力の失敗で一覧だけ調べられない）
    // あいだに保存できても、一覧は書かない。
    final whileBlocked = await _saveToSlot(service, project, 2, 'C');
    storage.paths.clear();
    expect(File(indexPath).readAsStringSync(), before);
    final added = await _saveToSlot(service, project, 3, 'D');
    expect(File(indexPath).readAsStringSync(), before);

    final again = SaveTreeService()..setSlotMax(5);
    addTearDown(again.dispose);
    await again.init();
    final nodes = {for (final n in again.getNodes(project.id)) n.id: n};
    expect(nodes[saves[0].id]?.comment, 'A');
    expect(nodes[saves[0].id]?.slotIndex, 0);
    expect(nodes[saves[1].id]?.comment, 'B');
    expect(nodes[saves[1].id]?.slotIndex, 1);
    expect(nodes.keys, containsAll([whileBlocked.id, added.id]));
  });

  // 一覧（index.json）の無い保存のフォルダ（一覧を書けなかった・以前の版の
  // 保存）を一覧できないときは、何があるか分からないので読んだことに
  // しない。一覧できるようになれば、読み直しで保存を拾い直す。
  test('a save folder without a list that cannot be listed is read again '
      'later', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final folder = '${storage.projectsPath}/${project.id}/SaveTree';
    File('$folder/${SaveTreeService.indexFileName}').deleteSync();
    storage.paths.blockListing(folder);

    final service = SaveTreeService()..setSlotMax(5);
    addTearDown(service.dispose);
    await service.init();
    expect(service.getNodes(project.id), isEmpty);

    storage.paths.clear();
    await service.loadUnread();
    expect(service.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
    ]);
  });

  // 作品のフォルダごと入れない（保存のフォルダも「無い」ように見える）
  // ときも同じ。入れるようになってから読み直せば（ホームの「再試行」）
  // 前の保存が戻り、その後の保存も前の保存を残す。
  test('saves of a work folder that could not be entered are read on the '
      'next reload, not overwritten', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    final before = File(indexPath).readAsStringSync();
    storage.paths.blockWork(storage.projectsPath, project.id);

    final service = SaveTreeService()..setSlotMax(5);
    addTearDown(service.dispose);
    await service.init();
    expect(service.getNodes(project.id), isEmpty);
    expect(_recorded('Permission denied', 'save_tree_service.dart'), isTrue);
    // 入れないあいだに読み直しても、読めたことにはしない。
    await service.loadUnread();
    expect(service.getNodes(project.id), isEmpty);

    storage.paths.clear();
    expect(File(indexPath).readAsStringSync(), before);
    await service.loadUnread();
    expect(service.getNodes(project.id).map((n) => n.comment), ['A', 'B']);
    final added = await _saveToSlot(service, project, 2, 'C');
    final again = SaveTreeService()..setSlotMax(5);
    addTearDown(again.dispose);
    await again.init();
    expect(again.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
      added.id,
    ]);
    expect(again.getNodes(project.id).map((n) => n.comment), ['A', 'B', 'C']);
  });

  // 保存先は一覧できるようになったが、作品のフォルダにはまだ入れない
  // （chmod -R 000の後に一番上だけ戻した等）。再試行で知らせと「再試行」が
  // 消え、作品の無い普通の空の一覧になっていた（起動し直すまで戻せない）。
  test('Retry keeps the notice while work folders still cannot be entered, '
      'and a later Retry loads them with their saves', () async {
    final (a, savesA) = await _seedProjectWithSaves(name: 'A', comments: ['a']);
    final (b, savesB) = await _seedProjectWithSaves(name: 'B', comments: ['b']);
    storage.paths.blockListing(storage.projectsPath);
    final created = <ChangeNotifier>[];
    await buildAppProviders(debugOnCreated: created.add);
    addTearDown(() {
      for (final service in created.reversed) {
        service.dispose();
      }
    });
    final projects = created.whereType<ProjectService>().single;
    final saveTree = created.whereType<SaveTreeService>().single;
    expect(projects.projectsLoadFailed, isTrue);

    storage.paths
      ..clear()
      ..blockWork(storage.projectsPath, a.id)
      ..blockWork(storage.projectsPath, b.id);
    await projects.retryLoadProjects();
    expect(projects.projects, isEmpty);
    expect(projects.projectsLoadFailed, isTrue);

    // 一部だけ入れるようになった：読めた作品は保存ごと出し、知らせは残す。
    storage.paths
      ..clear()
      ..blockWork(storage.projectsPath, a.id);
    await projects.retryLoadProjects();
    expect(projects.projects.map((p) => p.id), [b.id]);
    expect(projects.projectsLoadFailed, isTrue);
    expect(saveTree.getNodes(b.id).map((n) => n.id), [savesB.single.id]);

    storage.paths.clear();
    await projects.retryLoadProjects();
    expect(projects.projects.map((p) => p.id), unorderedEquals([a.id, b.id]));
    expect(projects.projectsLoadFailed, isFalse);
    expect(saveTree.getNodes(a.id).map((n) => n.id), [savesA.single.id]);
    expect(saveTree.getNodes(b.id).map((n) => n.id), [savesB.single.id]);
  });

  // 作品の保存の無いフォルダ（消す途中で残ったもの等）は、入れないのとは
  // 違うので知らせない。
  test('a work folder without an archive does not raise the notice', () async {
    final (project, _) = await _seedProjectWithSaves(comments: const []);
    Directory('${storage.projectsPath}/leftover').createSync();

    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.projects.map((p) => p.id), [project.id]);
    expect(service.projectsLoadFailed, isFalse);
  });

  // 上のフォルダ（書類フォルダ/niarim等）に入れないと、保存先は「無い」
  // ように見え（existsSyncはfalse）、作品を作ったことが無いのと同じ空の
  // 一覧になり、知らせも「再試行」も出なかった。
  test(
    'a projects folder that cannot be reached is not taken as missing',
    () async {
      final (project, _) = await _seedProjectWithSaves(comments: const []);
      storage.paths.blockEntering(storage.projectsPath);

      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.projects, isEmpty);
      expect(service.projectsLoadFailed, isTrue);

      storage.paths.clear();
      await service.retryLoadProjects();
      expect(service.projects.map((p) => p.id), [project.id]);
      expect(service.projectsLoadFailed, isFalse);
    },
  );

  // 作品の保存を開けない（ファイルだけchmod 000等）ときも、壊れた保存とは
  // 違い読めれば戻るので、知らせと「再試行」を残す。
  test('a work whose archive cannot be opened keeps the notice until it '
      'can be read', () async {
    final (project, _) = await _seedProjectWithSaves(comments: const []);
    final archive =
        '${storage.projectsPath}/${project.id}/${project.id}.niapro';
    storage.paths.blockReading(archive);

    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.projects, isEmpty);
    expect(service.projectsLoadFailed, isTrue);

    storage.paths.clear();
    await service.retryLoadProjects();
    expect(service.projects.map((p) => p.id), [project.id]);
    expect(service.projectsLoadFailed, isFalse);
  });

  // 保存先を読めないあいだ、知らせはプロジェクトのタブにしか出ず、
  // ゴミ箱のタブは「ゴミ箱は空です」、共有のタブ（受け取ったもの）は
  // 「共有プロジェクトがありません」と出ていた（ゴミ箱の作品が消えたと
  // 思わせる）。
  testWidgets('the trash and shared tabs say the works could not be read, '
      'and their Retry brings the trashed work back', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seeded = await tester.runAsync(
      () => _seedProjectWithSaves(name: 'ゴミ箱の作品', comments: const []),
    );
    final (project, _) = seeded!;
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'trashed_projects': ['${project.id}|${DateTime.now().toIso8601String()}'],
    });
    storage.paths.blockListing(storage.projectsPath);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    expect(find.byKey(const Key('homeProjectsLoadFailed')), findsOneWidget);

    // 共有（受け取ったもの）。
    await tester.tap(find.byKey(const ValueKey('home_tab_2')));
    await _settleWithFiles(tester);
    final sharedNotice = find.byKey(const Key('sharedProjectsLoadFailed'));
    expect(sharedNotice, findsOneWidget);
    expect(
      find.descendant(
        of: sharedNotice,
        matching: find.text('プロジェクトを読み込めませんでした'),
      ),
      findsOneWidget,
    );
    expect(find.text('共有プロジェクトがありません'), findsNothing);

    // ゴミ箱。
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await _settleWithFiles(tester);
    final trashNotice = find.byKey(const Key('trashProjectsLoadFailed'));
    expect(trashNotice, findsOneWidget);
    expect(find.text('ゴミ箱は空です'), findsNothing);
    expect(find.text('ゴミ箱の作品'), findsNothing);

    // 読めるようになってから、ゴミ箱のタブの「再試行」を押す。
    storage.paths.clear();
    await tester.tap(
      find.descendant(of: trashNotice, matching: find.text('再試行')),
    );
    for (var i = 0; i < 40 && find.text('ゴミ箱の作品').evaluate().isEmpty; i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    expect(find.text('ゴミ箱の作品'), findsOneWidget);
    expect(trashNotice, findsNothing);
    expect(find.byKey(ValueKey('trash-restore-${project.id}')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_tab_2')));
    await _settleWithFiles(tester);
    expect(sharedNotice, findsNothing);
    expect(find.text('共有プロジェクトがありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 設定の引き継ぎも同じ：「プロジェクトがありません。」と出て、引き継げる
  // 作品が無いように見えた。
  testWidgets('the transfer screen says the works could not be read and can '
      'retry', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => _seedProjectWithSaves(name: '引き継ぐ作品', comments: const []),
    );
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    storage.paths.blockListing(storage.projectsPath);
    appRouter.go('/settings/transfer');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    final notice = find.byKey(const Key('transferProjectsLoadFailed'));
    await tester.scrollUntilVisible(notice, 200);
    expect(notice, findsOneWidget);
    expect(find.text('プロジェクトがありません。'), findsNothing);

    storage.paths.clear();
    await tester.tap(find.descendant(of: notice, matching: find.text('再試行')));
    for (var i = 0; i < 40 && find.text('引き継ぐ作品').evaluate().isEmpty; i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    expect(notice, findsNothing);
    expect(find.text('引き継ぐ作品'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 狭い画面・大きな文字でも、知らせを出したゴミ箱・共有・引き継ぎが
  // はみ出さない（知らせは一覧の先頭でスクロールする）。
  testWidgets('the notices fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    Directory(storage.projectsPath).createSync(recursive: true);
    storage.paths.blockListing(storage.projectsPath);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    for (final (tab, notice) in [
      ('home_tab_2', 'sharedProjectsLoadFailed'),
      ('home_tab_3', 'trashProjectsLoadFailed'),
    ]) {
      final tabKey = find.byKey(ValueKey(tab));
      await tester.ensureVisible(tabKey);
      await tester.tap(tabKey);
      await _settleWithFiles(tester);
      expect(find.byKey(Key(notice)), findsOneWidget, reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    // 引き継ぎの画面は、高さ560では一覧の外（説明と下のボタン）が知らせと
    // 関係なくはみ出すので、縦を伸ばして知らせの欄だけを見る。
    tester.view.physicalSize = const Size(320, 900);
    appRouter.go('/settings/transfer');
    await _settleWithFiles(tester);
    final transfer = find.byKey(const Key('transferProjectsLoadFailed'));
    await tester.scrollUntilVisible(transfer, 200);
    expect(transfer, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// 実際のファイルを読む処理（ゴミ箱の一覧・読み直し）を実時間で待ちながら
/// 画面を進める。
Future<void> _settleWithFiles(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 作品を1つ作り、[comments]の数だけスロット0から順に手動で保存する。
Future<(Project, List<SaveNode>)> _seedProjectWithSaves({
  String name = '作品',
  required List<String> comments,
}) async {
  final projects = ProjectService();
  final project = await projects.createProject(
    name: name,
    fps: 2,
    durationSeconds: 1,
    backgroundColor: 0xFFFFFFFF,
    exportWidth: 64,
    exportHeight: 36,
  );
  final saveTree = SaveTreeService()..setSlotMax(5);
  final saves = <SaveNode>[];
  for (var i = 0; i < comments.length; i++) {
    saves.add(
      await saveTree.saveToSlot(
        projectId: project.id,
        slotIndex: i,
        project: project,
        scenes: projects.scenesOf(project.id),
        tileManager: projects.tileManagerOf(project.id),
        comment: comments[i],
      ),
    );
  }
  _seedServices[project.id] = projects;
  saveTree.dispose();
  return (project, saves);
}

/// 保存し直すときに作品の中身（シーン・タイル）を渡すため、作った
/// ProjectServiceを覚えておく。
final Map<String, ProjectService> _seedServices = {};

Future<SaveNode> _saveToSlot(
  SaveTreeService service,
  Project project,
  int slot,
  String comment,
) {
  final projects = _seedServices[project.id]!;
  return service.saveToSlot(
    projectId: project.id,
    slotIndex: slot,
    project: project,
    scenes: projects.scenesOf(project.id),
    tileManager: projects.tileManagerOf(project.id),
    comment: comment,
  );
}

/// 記録したエラーに、[message]と、それを記録した処理のファイル名
/// （[source]）が両方含まれているか。
bool _recorded(String message, String source) => AppErrorReporter.recentErrors
    .any((entry) => entry.contains(message) && entry.contains(source));

/// 書類フォルダ（一時フォルダ）とpath_providerの差し替え、読めない場所の
/// 差し替え（[paths]）をまとめて持つ。
class _Storage {
  _Storage()
    : directory = Directory.systemTemp.createTempSync('niarim_unreadable_') {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (failDocuments &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
    IOOverrides.global = paths;
  }

  static const _channel = MethodChannel('plugins.flutter.io/path_provider');
  final Directory directory;
  final _UnreadablePaths paths = _UnreadablePaths();
  bool failDocuments = false;

  String get projectsPath => '${directory.path}/niarim/projects';

  void dispose() {
    IOOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    for (final service in _seedServices.values) {
      service.dispose();
    }
    _seedServices.clear();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

/// 決まったフォルダ・ファイルだけを読めないように見せる。端末では、権限の
/// 無いフォルダ（chmod 000等）・入出力の失敗で起きる。
final class _UnreadablePaths extends IOOverrides {
  final Set<String> _watched = {};

  /// 中を一覧できないフォルダ（名前の分かっているものは開ける）。
  final Set<String> unlistable = {};

  /// 開くと権限の失敗になるファイル。
  final Set<String> unreadable = {};

  /// 入れないフォルダの中のファイル・フォルダ（あるかどうかも分からない）。
  final Set<String> inaccessible = {};

  void blockListing(String path) => unlistable.add(_watch(path));
  void blockReading(String path) => unreadable.add(_watch(path));
  void blockEntering(String path) => inaccessible.add(_watch(path));

  /// 作品のフォルダに入れない（chmod 000・入出力の失敗）：作品の保存
  /// （.niapro）も、手動の保存のフォルダ（SaveTree/）と一覧も見えない。
  void blockWork(String projectsPath, String projectId) {
    final folder = '$projectsPath/$projectId';
    blockEntering('$folder/$projectId.niapro');
    blockEntering('$folder/SaveTree');
    blockEntering('$folder/SaveTree/${SaveTreeService.indexFileName}');
  }

  void clear() {
    unlistable.clear();
    unreadable.clear();
    inaccessible.clear();
  }

  String _watch(String path) {
    _watched.add(path);
    return path;
  }

  @override
  Directory createDirectory(String path) {
    final real = super.createDirectory(path);
    return _watched.contains(path) ? _GuardedDirectory(real, this) : real;
  }

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return _watched.contains(path) ? _GuardedFile(real, this) : real;
  }
}

PathAccessException _denied(String path, String message) =>
    PathAccessException(path, const OSError('Permission denied', 13), message);

class _GuardedDirectory implements Directory {
  _GuardedDirectory(this._real, this._paths);

  final Directory _real;
  final _UnreadablePaths _paths;

  /// 入れないフォルダ（親の権限が無い等）：あるかどうかも分からない。
  bool get _hidden => _paths.inaccessible.contains(_real.path);
  bool get _blocked => _hidden || _paths.unlistable.contains(_real.path);

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  Directory get absolute => _real.absolute;
  @override
  Directory get parent => _real.parent;
  @override
  bool existsSync() => !_hidden && _real.existsSync();
  @override
  Future<bool> exists() async => existsSync();
  @override
  FileStat statSync() => _real.statSync();
  @override
  Future<FileStat> stat() => _real.stat();
  @override
  void createSync({bool recursive = false}) =>
      _real.createSync(recursive: recursive);
  @override
  Future<Directory> create({bool recursive = false}) =>
      _real.create(recursive: recursive);
  @override
  Directory createTempSync([String? prefix]) => _real.createTempSync(prefix);
  @override
  Future<Directory> createTemp([String? prefix]) => _real.createTemp(prefix);
  @override
  void deleteSync({bool recursive = false}) =>
      _real.deleteSync(recursive: recursive);
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _real.delete(recursive: recursive);
  @override
  Directory renameSync(String newPath) => _real.renameSync(newPath);
  @override
  Future<Directory> rename(String newPath) => _real.rename(newPath);
  @override
  String resolveSymbolicLinksSync() => _real.resolveSymbolicLinksSync();
  @override
  Future<String> resolveSymbolicLinks() => _real.resolveSymbolicLinks();

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (_blocked) throw _denied(path, 'Directory listing failed');
    return _real.listSync(recursive: recursive, followLinks: followLinks);
  }

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (_blocked) {
      return Stream.error(_denied(path, 'Directory listing failed'));
    }
    return _real.list(recursive: recursive, followLinks: followLinks);
  }

  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a guarded folder');
}

class _GuardedFile implements File {
  _GuardedFile(this._real, this._paths);

  final File _real;
  final _UnreadablePaths _paths;

  bool get _hidden => _paths.inaccessible.contains(_real.path);
  bool get _blocked => _hidden || _paths.unreadable.contains(_real.path);

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  File get absolute => _real.absolute;
  @override
  Directory get parent => _real.parent;
  @override
  bool existsSync() => !_hidden && _real.existsSync();
  @override
  Future<bool> exists() async => existsSync();

  @override
  int lengthSync() {
    if (_hidden) throw _denied(path, 'Cannot retrieve length of file');
    return _real.lengthSync();
  }

  @override
  Future<int> length() async => lengthSync();

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    if (_blocked) throw _denied(path, 'Cannot open file');
    return _real.readAsStringSync(encoding: encoding);
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      readAsStringSync(encoding: encoding);

  @override
  Uint8List readAsBytesSync() {
    if (_blocked) throw _denied(path, 'Cannot open file');
    return _real.readAsBytesSync();
  }

  @override
  Future<Uint8List> readAsBytes() async => readAsBytesSync();

  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a guarded file');
}
