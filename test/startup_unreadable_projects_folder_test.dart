import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/storage_info_service.dart';
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

  // 保存先は一覧できるが、関係のない作品1つの保存を開けないだけで、期限の
  // 過ぎたゴミ箱の片付けが丸ごと止まっていた（読めた作品も、起動時にも
  // 保持期間の設定を変えたときにも消えない）。片付けを丸ごと止めるのは
  // 保存先を一覧できなかったときだけ。一部の作品だけ読めないときは、
  // 読めていない作品を含むフォルダ（中の読めた作品ごと）だけを残す。
  // 壊れていて読み直しても読めない作品を含むフォルダは、残さない（残すと
  // いつまでも片付かない）。
  test(
    'expired trash that was read is cleaned up while an unrelated work '
    'cannot be opened; a folder holding an unread work is kept whole',
    () async {
      Future<Project> seed(String name) async =>
          (await _seedProjectWithSaves(name: name, comments: const [])).$1;
      final unrelated = await seed('開けない作品');
      final loose = await seed('期限切れの作品');
      final inReadFolder = await seed('読めたフォルダの作品');
      final readInHeld = await seed('残すフォルダの読めた作品');
      final unreadInHeld = await seed('残すフォルダの読めない作品');
      final damaged = await seed('壊れた作品');
      final besideDamaged = await seed('壊れた作品と同じフォルダの作品');
      final fresh = await seed('まだ新しい作品');
      String folderOf(Project p) => '${storage.projectsPath}/${p.id}';
      String archiveOf(Project p) => '${folderOf(p)}/${p.id}.niapro';
      bool onDisk(Project p) => Directory(folderOf(p)).existsSync();

      final old = DateTime.now().subtract(const Duration(days: 90));
      final recent = DateTime.now().subtract(const Duration(days: 1));
      TrashedFolder record(String id, List<Project> works) => TrashedFolder(
        folder: ProjectFolder(id: id, name: id),
        subfolders: const [],
        projectIds: [for (final p in works) p.id],
        deletedAt: old,
      );
      final held = record('folder_held', [readInHeld, unreadInHeld]);
      SharedPreferences.setMockInitialValues({
        'language': 'ja',
        'trashed_projects': [
          for (final p in [
            loose,
            inReadFolder,
            readInHeld,
            unreadInHeld,
            damaged,
            besideDamaged,
          ])
            '${p.id}|${old.toIso8601String()}',
          '${fresh.id}|${recent.toIso8601String()}',
        ],
        'trashed_project_folders': jsonEncode([
          record('folder_read', [inReadFolder]).toJson(),
          held.toJson(),
          record('folder_damaged', [damaged, besideDamaged]).toJson(),
        ]),
      });
      File(archiveOf(damaged)).writeAsStringSync('not an archive');
      storage.paths
        ..blockReading(archiveOf(unrelated))
        ..blockEntering(archiveOf(unreadInHeld));

      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.projectsLoadFailed, isTrue);
      expect(
        service.trash.map((p) => p.id),
        unorderedEquals([
          loose.id,
          inReadFolder.id,
          readInHeld.id,
          besideDamaged.id,
          fresh.id,
        ]),
      );
      await service.sweepExpiredTrash(30);

      // 読めた期限切れの作品・フォルダは、これまでどおり消える。
      expect(onDisk(loose), isFalse, reason: 'the read expired work stayed');
      expect(onDisk(inReadFolder), isFalse, reason: 'the read folder stayed');
      // 壊れた作品を含むフォルダも（壊れた作品は読み直しても読めない）。
      expect(onDisk(besideDamaged), isFalse, reason: 'held for a damaged work');
      // 読めていない作品を含むフォルダは、記録も中の作品もそのまま。
      expect(service.trashedFolders.map((t) => t.folder.id), ['folder_held']);
      expect(onDisk(readInHeld), isTrue);
      expect(onDisk(unreadInHeld), isTrue);
      expect(
        service.trash.map((p) => p.id),
        unorderedEquals([readInHeld.id, fresh.id]),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('trashed_project_folders'),
        jsonEncode([held.toJson()]),
      );
      expect(
        prefs.getStringList('trashed_projects')!.map((e) => e.split('|').first),
        unorderedEquals([readInHeld.id, unreadInHeld.id, damaged.id, fresh.id]),
      );
      // 開けない作品・期限の来ていない作品には触らない。
      expect(onDisk(unrelated), isTrue);
      expect(onDisk(fresh), isTrue);

      // 読めるようになれば、残したフォルダは中の作品ごとゴミ箱に戻り、
      // 次の片付けでまとめて消える。
      storage.paths.clear();
      await service.retryLoadProjects();
      expect(service.projectsLoadFailed, isFalse);
      expect(service.projects.map((p) => p.id), [unrelated.id]);
      expect(service.trashedFolderOf(readInHeld.id)?.folder.id, 'folder_held');
      expect(
        service.trashedFolderOf(unreadInHeld.id)?.folder.id,
        'folder_held',
      );
      expect(service.looseTrash.map((p) => p.id), [fresh.id]);
      await service.sweepExpiredTrash(30);
      expect(service.trashedFolders, isEmpty);
      expect(onDisk(readInHeld), isFalse);
      expect(onDisk(unreadInHeld), isFalse);
      expect(service.trash.map((p) => p.id), [fresh.id]);
      expect(onDisk(unrelated), isTrue);
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

  // 保存の一覧を読めていない間に書いたスロットのメモは、読んでいない一覧を
  // 上書きしない決まりで保存されず、その後の読み直し（「再試行」）が
  // ディスクのメモで置き換えて消えていた。読めたときに、書いたメモ（消した
  // メモも）をディスクのメモへ重ねてから、一覧を書く。
  test('slot memos written while the save list was unread are laid over the '
      'saved ones when Retry reads it', () async {
    final (project, saves) = await _seedProjectWithSaves(
      name: '保存を読めない作品',
      comments: ['A', 'B'],
    );
    final (other, _) = await _seedProjectWithSaves(
      name: '開けない作品',
      comments: const [],
    );
    // ディスクのメモ：スロット0「A」・1「B」（保存のコメントから）・3。
    final seeder = SaveTreeService()..setSlotMax(5);
    await seeder.init();
    expect(await seeder.setSlotMemo(project.id, 3, '消すメモ'), isTrue);
    seeder.dispose();
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    final before = File(indexPath).readAsStringSync();
    Map<String, dynamic> memosOnDisk() =>
        (jsonDecode(File(indexPath).readAsStringSync()) as Map)['slotMemos']
            as Map<String, dynamic>;
    expect(memosOnDisk(), {'0': 'A', '1': 'B', '3': '消すメモ'});

    // 起動：この作品は読めるが保存の一覧だけ開けず、別の作品も開けない
    // （ホームに知らせと「再試行」が出る）。
    storage.paths
      ..blockReading(indexPath)
      ..blockReading('${storage.projectsPath}/${other.id}/${other.id}.niapro');
    final created = <ChangeNotifier>[];
    await buildAppProviders(debugOnCreated: created.add);
    addTearDown(() {
      for (final service in created.reversed) {
        service.dispose();
      }
    });
    final projects = created.whereType<ProjectService>().single;
    final saveTree = created.whereType<SaveTreeService>().single..setSlotMax(5);
    expect(projects.projects.map((p) => p.id), [project.id]);
    expect(projects.projectsLoadFailed, isTrue);
    expect(saveTree.getNodes(project.id), isEmpty);
    expect(saveTree.slotMemoOf(project.id, 0), isNull);

    // 書き直す・新しく書く・消す。
    await saveTree.setSlotMemo(project.id, 0, '書き直した');
    await saveTree.setSlotMemo(project.id, 2, '新しいメモ');
    await saveTree.setSlotMemo(project.id, 3, '');
    expect(saveTree.slotMemoOf(project.id, 0), '書き直した');

    // 読めていない一覧は書き換えていない。
    storage.paths.clear();
    expect(File(indexPath).readAsStringSync(), before);

    // 読めるようになってから「再試行」。
    await projects.retryLoadProjects();
    expect(projects.projectsLoadFailed, isFalse);
    expect(saveTree.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
    ]);
    void expectMemos(SaveTreeService service) {
      expect(service.slotMemoOf(project.id, 0), '書き直した');
      expect(service.slotMemoOf(project.id, 1), 'B');
      expect(service.slotMemoOf(project.id, 2), '新しいメモ');
      expect(service.slotMemoOf(project.id, 3), '');
    }

    expectMemos(saveTree);
    expect(memosOnDisk(), {'0': '書き直した', '1': 'B', '2': '新しいメモ', '3': ''});
    // もう一度読み直しても変わらない。
    final written = File(indexPath).readAsStringSync();
    await projects.retryLoadProjects();
    expectMemos(saveTree);
    expect(File(indexPath).readAsStringSync(), written);

    // 次の起動でも、メモも前の保存もそのまま。
    final again = SaveTreeService()..setSlotMax(5);
    addTearDown(again.dispose);
    await again.init();
    expectMemos(again);
    expect(again.getNodes(project.id).map((n) => (n.slotIndex, n.comment)), [
      (0, 'A'),
      (1, 'B'),
    ]);
  });

  // 保存が1つも無い作品でも同じ（保存のフォルダも一覧も無い／メモだけの
  // 一覧がある）：作品のフォルダに入れない間に書いたメモは、入れるように
  // なって読み直したときに保存する（以前は画面には出たまま、次の起動で
  // 消えた）。
  for (final hasList in [false, true]) {
    test('a slot memo written while a work without saves could not be '
        'entered is saved once it can be '
        '(${hasList ? 'a list with memos only' : 'no save folder'})', () async {
      final (project, _) = await _seedProjectWithSaves(comments: const []);
      final indexPath =
          '${storage.projectsPath}/${project.id}/SaveTree/'
          '${SaveTreeService.indexFileName}';
      if (hasList) {
        final seeder = SaveTreeService()..setSlotMax(5);
        await seeder.init();
        await seeder.setSlotMemo(project.id, 0, '前のメモ');
        seeder.dispose();
      }
      expect(File(indexPath).existsSync(), hasList);
      storage.paths.blockWork(storage.projectsPath, project.id);

      final service = SaveTreeService()..setSlotMax(5);
      addTearDown(service.dispose);
      await service.init();
      expect(service.slotMemoOf(project.id, 0), isNull);
      await service.setSlotMemo(project.id, 1, '下書き用');
      expect(service.slotMemoOf(project.id, 1), '下書き用');
      storage.paths.clear();
      expect(
        File(indexPath).existsSync() ? File(indexPath).readAsStringSync() : '',
        isNot(contains('下書き用')),
      );

      await service.loadUnread();
      void expectMemos(SaveTreeService saves) {
        expect(saves.slotMemoOf(project.id, 0), hasList ? '前のメモ' : isNull);
        expect(saves.slotMemoOf(project.id, 1), '下書き用');
      }

      expectMemos(service);
      final again = SaveTreeService()..setSlotMax(5);
      addTearDown(again.dispose);
      await again.init();
      expectMemos(again);
    });
  }

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

  // 一覧（index.json）が壊れて文字として読めない（コメントの日本語の途中で
  // 切れた等、UTF-8として正しくない）のは、入れない・開けないのとは違い、
  // 待っても読めるようにならない。「まだ読んでいない」扱いにすると一覧を
  // 書き直さず、起動のたびにその作品の保存が1つも出ず、新しい保存も次の
  // 起動で一覧から消えて、保存のファイルだけが見えないまま増えた。
  test('a list cut inside a character is rebuilt from the save files, and '
      'later saves stay listed', () async {
    final (project, saves) = await _seedProjectWithSaves(
      comments: ['線画まで', '色まで'],
    );
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    final bytes = File(indexPath).readAsBytesSync();
    final firstWide = bytes.indexWhere((byte) => byte >= 0x80);
    expect(firstWide, greaterThan(0), reason: 'the comments are Japanese');
    File(indexPath).writeAsBytesSync(bytes.sublist(0, firstWide + 1));
    expect(
      () => File(indexPath).readAsStringSync(),
      throwsA(isA<FileSystemException>()),
      reason: 'the list must no longer be valid UTF-8',
    );

    // 起動1回目：保存のファイルから拾い直し、一覧を書き直す。
    final first = SaveTreeService()..setSlotMax(5);
    addTearDown(first.dispose);
    await first.init();
    expect(first.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
    ]);
    expect(first.getNodes(project.id).map((n) => n.slotIndex), [0, 1]);
    expect(jsonDecode(File(indexPath).readAsStringSync()), isA<Map>());

    // その起動中の保存は、次の起動でも一覧に出る。
    final added = await _saveToSlot(first, project, 2, '新しい保存');
    final second = SaveTreeService()..setSlotMax(5);
    addTearDown(second.dispose);
    await second.init();
    final nodes = {for (final n in second.getNodes(project.id)) n.id: n};
    expect(nodes.keys, unorderedEquals([saves[0].id, saves[1].id, added.id]));
    expect(nodes[added.id]?.comment, '新しい保存');
    expect(nodes[added.id]?.slotIndex, 2);
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

  // 作品を読めていない間も、ゴミ箱のフォルダの記録（設定から読む）は
  // 残っているので、完全に削除する・空にするが効き、フォルダの記録だけが
  // 消えた。読めた後、中の作品はフォルダではなくゴミ箱の1件ずつの行に
  // 出た。読めていない作品を含むフォルダは、読めるまで消さない（保存先を
  // 一覧できないときも、一部の作品だけ読めないときも）。
  for (final blocked in ['the projects folder', 'one of its works']) {
    test('a trashed folder is not deleted or emptied while '
        '$blocked cannot be read', () async {
      final (folder, works) = await _seedTrashedFolder('旅行', ['海', '山']);
      final (readFolder, readWorks) = await _seedTrashedFolder('読めたフォルダ', [
        '川',
      ]);
      final loose = await _seed((service) async {
        final project = await _createWork(service, 'ばらの作品');
        await service.deleteProject(project.id);
        return project;
      });
      bool onDisk(Project p) =>
          Directory('${storage.projectsPath}/${p.id}').existsSync();
      final prefs = await SharedPreferences.getInstance();
      final recordsBefore = prefs.getString('trashed_project_folders');
      final listingBlocked = blocked == 'the projects folder';
      if (listingBlocked) {
        storage.paths.blockListing(storage.projectsPath);
      } else {
        storage.paths.blockReading(
          '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
        );
      }

      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.projectsLoadFailed, isTrue);
      TrashedFolder recordOf(ProjectFolder f) =>
          service.trashedFolders.singleWhere((t) => t.folder.id == f.id);
      expect(service.trashedFolderHasUnreadWorks(recordOf(folder)), isTrue);
      expect(
        service.trashedFolderHasUnreadWorks(recordOf(readFolder)),
        listingBlocked,
      );

      final refused = throwsA(isA<TrashedFolderUnreadException>());
      await expectLater(
        service.permanentDeleteTrashedFolder(folder.id),
        refused,
      );
      expect(service.folders, isEmpty, reason: 'the folder came back empty');
      expect(prefs.getString('trashed_project_folders'), recordsBefore);
      expect(works.every(onDisk), isTrue);

      // 空にする：読めたものは消し、読めていない作品を含むフォルダは
      // 中の読めた作品ごと残して、空にし切れなかったことを伝える。
      await expectLater(service.emptyTrash(), refused);
      expect(works.every(onDisk), isTrue);
      if (listingBlocked) {
        expect(prefs.getString('trashed_project_folders'), recordsBefore);
        expect(onDisk(readWorks.single), isTrue);
        expect(onDisk(loose), isTrue);
      } else {
        expect(service.trashedFolders.map((t) => t.folder.id), [folder.id]);
        expect(service.trash.map((p) => p.id), [works[0].id]);
        expect(onDisk(readWorks.single), isFalse);
        expect(onDisk(loose), isFalse);
      }

      // 読めるようになれば、フォルダは中の作品ごとゴミ箱にあり、まとめて
      // 元の場所へ戻せる。
      storage.paths.clear();
      await service.retryLoadProjects();
      expect(service.projectsLoadFailed, isFalse);
      for (final work in works) {
        expect(service.trashedFolderOf(work.id)?.folder.id, folder.id);
      }
      expect(
        service.looseTrash.map((p) => p.name),
        listingBlocked ? ['ばらの作品'] : isEmpty,
      );
      expect(service.trashedFolderHasUnreadWorks(recordOf(folder)), isFalse);
      await service.restoreTrashedFolder(folder.id);
      expect(service.folders.map((f) => f.id), [folder.id]);
      expect(
        service.projects.map((p) => (p.name, p.folderId)),
        unorderedEquals([('海', folder.id), ('山', folder.id)]),
      );
      expect(
        service.trashedFolders.map((t) => t.folder.id),
        listingBlocked ? [readFolder.id] : isEmpty,
      );
    });
  }

  // 読めていない作品を含むフォルダも「復元」はできる（断ると、いつまでも
  // 読めない作品が1つあるだけで、同じフォルダの読めた作品までゴミ箱から
  // 出せなかった）。読めた作品はすぐフォルダの中へ戻り、読めていない作品は
  // ゴミ箱の記録から外れて、読めたときに同じフォルダの中に出る。
  for (final blocked in ['the projects folder', 'one of its works']) {
    test(
      'a trashed folder can be restored while $blocked cannot be read: '
      'the read works return at once, the others when they are read',
      () async {
        final (folder, works) = await _seedTrashedFolder('旅行', ['海', '山']);
        bool onDisk(Project p) =>
            Directory('${storage.projectsPath}/${p.id}').existsSync();
        final listingBlocked = blocked == 'the projects folder';
        if (listingBlocked) {
          storage.paths.blockListing(storage.projectsPath);
        } else {
          storage.paths.blockReading(
            '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
          );
        }

        final service = ProjectService();
        addTearDown(service.dispose);
        await service.init();
        expect(service.projectsLoadFailed, isTrue);
        expect(service.looseTrash, isEmpty);

        await service.restoreTrashedFolder(folder.id);
        expect(service.folders.map((f) => f.id), [folder.id]);
        expect(service.trashedFolders, isEmpty);
        expect(
          service.projects.map((p) => (p.name, p.folderId)),
          listingBlocked ? isEmpty : [('海', folder.id)],
        );
        expect(service.trash, isEmpty);
        // 読めていない作品も、ゴミ箱の記録には残さない。
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('trashed_projects'), isEmpty);
        expect(
          jsonDecode(prefs.getString('trashed_project_folders')!),
          isEmpty,
        );
        // 読めないままゴミ箱を空にしても、戻した作品は消えない。
        await service.emptyTrash();
        expect(works.every(onDisk), isTrue);

        // 読めるようになって読み直すと、残りの作品も同じフォルダの中に出る
        // （ゴミ箱の1件ずつの行には出ない）。
        storage.paths.clear();
        await service.retryLoadProjects();
        expect(service.projectsLoadFailed, isFalse);
        void expectRestored(ProjectService projects) {
          expect(projects.folders.map((f) => f.id), [folder.id]);
          expect(
            projects.projects.map((p) => (p.name, p.folderId)),
            unorderedEquals([('海', folder.id), ('山', folder.id)]),
          );
          expect(projects.trash, isEmpty);
          expect(projects.trashedFolders, isEmpty);
        }

        expectRestored(service);
        // 次の起動でも同じ。
        final again = ProjectService();
        addTearDown(again.dispose);
        await again.init();
        expectRestored(again);
      },
    );
  }

  // 作品を読めていない間にフォルダをゴミ箱へ移すと、読めた作品だけが
  // フォルダと一緒に移り（保存先を一覧できないときは「中身なし」）、読めて
  // いない作品は読めた後にフォルダの外へ出た。読めるまでは移さない。
  for (final blocked in ['the projects folder', 'one of its works']) {
    test(
      'a folder is not moved to Trash while $blocked cannot be read',
      () async {
        final (folder, works) = await _seed((service) async {
          final folder = await service.createFolder('旅行');
          final works = <Project>[];
          for (final name in ['海', '山']) {
            final work = await _createWork(service, name);
            await service.moveToFolder(work.id, folder.id);
            works.add(work);
          }
          return (folder, works);
        });
        if (blocked == 'the projects folder') {
          storage.paths.blockListing(storage.projectsPath);
        } else {
          storage.paths.blockReading(
            '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
          );
        }

        final service = ProjectService();
        addTearDown(service.dispose);
        await service.init();
        expect(service.projectsLoadFailed, isTrue);
        final prefs = await SharedPreferences.getInstance();
        final foldersBefore = prefs.getString('project_folders');
        final recordsBefore = prefs.getString('trashed_project_folders');
        final trashBefore = prefs.getStringList('trashed_projects');

        await expectLater(
          service.moveFolderToTrash(folder.id),
          throwsA(isA<TrashedFolderUnreadException>()),
        );
        expect(service.folders.map((f) => f.id), [folder.id]);
        expect(service.trashedFolders, isEmpty);
        expect(service.trash, isEmpty);
        expect(prefs.getString('project_folders'), foldersBefore);
        expect(prefs.getString('trashed_project_folders'), recordsBefore);
        expect(prefs.getStringList('trashed_projects'), trashBefore);

        // 読めるようになれば、中の作品ごと移せる。
        storage.paths.clear();
        await service.retryLoadProjects();
        final record = await service.moveFolderToTrash(folder.id);
        expect(
          record?.projectIds,
          unorderedEquals([for (final w in works) w.id]),
        );
        expect(service.trash.map((p) => p.name), unorderedEquals(['海', '山']));
        expect(service.folders, isEmpty);
      },
    );
  }

  // ゴミ箱の画面：読めていない作品を含むフォルダの行は「完全削除」だけを
  // 押せなくし、その行の中で理由を伝える（知らせは一覧の先頭にしか無く、
  // スクロールすると見えない）。中身を「中身なし」とは言わない。「復元」と
  // 「コピー」（貼り付けた先へ戻す）は押せる：読めないままでもフォルダは
  // 戻り、中の作品は読めたときにフォルダの中に出る。「再試行」で読めたら
  // 「完全削除」も押せるようになり、中の作品ごと戻せる。
  testWidgets('the trash row of a folder whose works are unread can be '
      'restored but not deleted, and says why', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final seeded = await tester.runAsync(() async {
      final trip = await _seedTrashedFolder('旅行', ['海', '山']);
      final work = await _seedTrashedFolder('出張', ['駅']);
      return (trip.$1, work.$1);
    });
    final (folder, early) = seeded!;
    storage.paths.blockListing(storage.projectsPath);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await _settleWithFiles(tester);
    final notice = find.byKey(const Key('trashProjectsLoadFailed'));
    expect(notice, findsOneWidget);
    final row = find.byKey(ValueKey('trashedFolder_${folder.id}'));
    expect(row, findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    final restore = find.byKey(ValueKey('trashedFolderRestore_${folder.id}'));
    final delete = find.byKey(ValueKey('trashedFolderDelete_${folder.id}'));
    final copy = find.byKey(ValueKey('trashCopyFolder_${folder.id}'));
    expect(tester.widget<TextButton>(delete).onPressed, isNull);
    expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
    expect(tester.widget<TextButton>(copy).onPressed, isNotNull);
    // 押せない「完全削除」は、押せるときの色（赤）のままにしない。
    Color? inkOf(Finder button) => tester
        .widget<RichText>(
          find.descendant(of: button, matching: find.byType(RichText)),
        )
        .text
        .style
        ?.color;
    final scheme = Theme.of(tester.element(row)).colorScheme;
    expect(inkOf(delete), isNot(scheme.error));
    expect(find.text('中身なし'), findsNothing);
    expect(
      find.descendant(of: row, matching: find.textContaining('プロジェクト2件')),
      findsOneWidget,
    );
    // 押せない理由は、その行の中にも出す。
    final reason = find.descendant(
      of: row,
      matching: find.textContaining('プロジェクトを読み込めませんでした'),
    );
    expect(reason, findsOneWidget, reason: 'the row does not say why');
    // 「完全削除」は押しても、確かめるダイアログは出ず、何も変わらない。
    await tester.tap(delete, warnIfMissed: false);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.byType(AlertDialog), findsNothing);
    final projects = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    expect(
      projects.trashedFolders.map((t) => t.folder.id),
      unorderedEquals([folder.id, early.id]),
    );
    expect(projects.folders, isEmpty);

    // 読めないままでも「復元」でフォルダは戻る（中の作品は読めたときに
    // フォルダの中に出る）。
    await tester.tap(find.byKey(ValueKey('trashedFolderRestore_${early.id}')));
    await _settleWithFiles(tester, rounds: 3);
    await tester.tap(find.byKey(const Key('homeTrashRestoreConfirmButton')));
    for (var i = 0; i < 40 && projects.trashedFolders.length > 1; i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    await _settleWithFiles(tester, rounds: 3);
    expect(find.byType(SnackBar), findsNothing, reason: 'the restore failed');
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);
    expect(projects.folders.map((f) => f.id), [early.id]);
    expect(find.byKey(ValueKey('trashedFolder_${early.id}')), findsNothing);

    // 読めるようになってから「再試行」：戻したフォルダの作品はフォルダの
    // 中に出て、残したフォルダは中の作品の名前が出て「完全削除」も押せる。
    storage.paths.clear();
    await tester.tap(find.descendant(of: notice, matching: find.text('再試行')));
    for (var i = 0; i < 40 && notice.evaluate().isNotEmpty; i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    expect(notice, findsNothing);
    expect(projects.projects.map((p) => (p.name, p.folderId)), [
      ('駅', early.id),
    ]);
    expect(projects.looseTrash, isEmpty);
    expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
    expect(tester.widget<TextButton>(delete).onPressed, isNotNull);
    expect(tester.widget<TextButton>(copy).onPressed, isNotNull);
    expect(inkOf(delete), scheme.error);
    expect(reason, findsNothing);
    expect(
      find.descendant(of: row, matching: find.textContaining('海')),
      findsOneWidget,
    );
    await tester.tap(restore);
    await _settleWithFiles(tester, rounds: 3);
    await tester.tap(find.byKey(const Key('homeTrashRestoreConfirmButton')));
    for (var i = 0; i < 40 && projects.trash.isNotEmpty; i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    expect(projects.trashedFolders, isEmpty);
    expect(
      projects.folders.map((f) => f.id),
      unorderedEquals([folder.id, early.id]),
    );
    expect(
      projects.projects.map((p) => (p.name, p.folderId)),
      unorderedEquals([('海', folder.id), ('山', folder.id), ('駅', early.id)]),
    );
    expect(projects.trash, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 小さい画面では、知らせ（一覧の先頭）はスクロールすると見えなくなる。
  // 押せないボタンだけが残ると理由が分からないので、行の中の理由が
  // 大きな文字・長い言語でもはみ出さずに出ること。
  testWidgets('a held folder row says why on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
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
    final l10n = lookupAppLocalizations(const Locale('fr'));
    final seeded = await tester.runAsync(() async {
      for (final name in ['Croquis', 'Essai']) {
        await _seed((service) async {
          final project = await _createWork(service, name);
          await service.deleteProject(project.id);
        });
      }
      return _seedTrashedFolder('Voyage', ['Mer', 'Montagne']);
    });
    final (folder, works) = seeded!;
    storage.paths.blockReading(
      '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
    );
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    final tab = find.byKey(const ValueKey('home_tab_3'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await _settleWithFiles(tester);
    final delete = find.byKey(
      ValueKey('trashedFolderDelete_${folder.id}'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      delete,
      80,
      scrollable: find.byType(Scrollable).last,
    );
    await _settleWithFiles(tester, rounds: 2);
    expect(tester.widget<TextButton>(delete).onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('trashedFolder_${folder.id}')),
        matching: find.textContaining(l10n.homeProjectsLoadFailed),
      ),
      findsOneWidget,
      reason: 'the row does not say why its button is disabled',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ホーム：作品を読めていない間にフォルダを選んでゴミ箱へ移そうとしても
  // 移さず、確かめるダイアログの中で、読み込めていないことを伝える。
  testWidgets('Home does not move a folder to Trash while the works could not '
      'be read, and the dialog says so', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final seeded = await tester.runAsync(
      () => _seed((service) async {
        final folder = await service.createFolder('旅行');
        for (final name in ['海', '山']) {
          final work = await _createWork(service, name);
          await service.moveToFolder(work.id, folder.id);
        }
        return folder;
      }),
    );
    final folder = seeded!;
    storage.paths.blockListing(storage.projectsPath);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    final projects = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    expect(find.byKey(const Key('homeProjectsLoadFailed')), findsOneWidget);
    await tester.longPress(find.text('旅行').first);
    await _settleWithFiles(tester, rounds: 3);
    await tester.tap(find.byTooltip('ゴミ箱へ移動').first);
    await _settleWithFiles(tester, rounds: 4);
    await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
    await _settleWithFiles(tester);
    expect(projects.trashedFolders, isEmpty, reason: 'trashed without works');
    expect(projects.folders.map((f) => f.id), [folder.id]);
    final error = find.byKey(const Key('trash-dialog-error'));
    expect(error, findsOneWidget);
    expect(tester.widget<Text>(error).data, 'プロジェクトを読み込めませんでした');
    await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
    await _settleWithFiles(tester, rounds: 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 容量削減の「ゴミ箱を空にする」：一部の作品だけ読めないとき、読めた
  // ものは消し、読めていない作品を含むフォルダは中の読めた作品ごと残して、
  // 残ったフォルダの名前と失敗の文をダイアログに出す（以前は記録だけが
  // 消え、フォルダの読めた作品も1件ずつ消えた）。
  testWidgets('Empty trash in storage keeps a folder that holds an unread '
      'work and says it could not finish', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final seeded = await tester.runAsync(() async {
      final held = await _seedTrashedFolder('旅行', ['海', '山']);
      final read = await _seedTrashedFolder('読めたフォルダ', ['川']);
      final loose = await _seed((service) async {
        final project = await _createWork(service, 'ばらの作品');
        await service.deleteProject(project.id);
        return project;
      });
      return (held, read, loose);
    });
    final ((folder, works), (_, readWorks), loose) = seeded!;
    bool onDisk(Project p) =>
        Directory('${storage.projectsPath}/${p.id}').existsSync();
    storage.paths.blockReading(
      '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
    );
    StorageInfoService().invalidate();
    addTearDown(StorageInfoService().invalidate);
    appRouter.go('/storage');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    final emptyTrash = find.widgetWithText(
      ListTile,
      'ゴミ箱を空にする',
      skipOffstage: false,
    );
    for (
      var i = 0;
      i < 60 &&
          (emptyTrash.evaluate().isEmpty ||
              !tester.widget<ListTile>(emptyTrash).enabled);
      i++
    ) {
      await _settleWithFiles(tester, rounds: 2);
    }
    expect(tester.widget<ListTile>(emptyTrash).enabled, isTrue);
    await tester.ensureVisible(emptyTrash);
    await tester.tap(emptyTrash);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('読めたフォルダ'), findsOneWidget);
    expect(find.text('ばらの作品'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
    final projects = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    for (var i = 0; i < 60 && onDisk(loose); i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    await _settleWithFiles(tester);

    // 読めたものは消えている。
    expect(onDisk(loose), isFalse);
    expect(onDisk(readWorks.single), isFalse);
    // 読めていない作品を含むフォルダは、記録も中の作品もそのまま。
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);
    expect(works.every(onDisk), isTrue);
    expect(projects.trash.map((p) => p.id), [works[0].id]);
    // ダイアログは残り、残ったフォルダの名前と失敗の文を出す。
    final error = find.byKey(const Key('trash-dialog-error'));
    expect(error, findsOneWidget);
    // 「保存先を確認して、もう一度」ではなく、読み込めていないことを伝える
    // （この画面からは、何度やり直しても消せない）。
    expect(tester.widget<Text>(error).data, 'プロジェクトを読み込めませんでした');
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('読めたフォルダ'), findsNothing);
    expect(find.text('ばらの作品'), findsNothing);
    await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
    await _settleWithFiles(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
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

  // 画面のフォーカスを渡していない所（引き継ぎ・単独で開いたゴミ箱と共有）
  // では、キーボードの「再試行」で読み直せて知らせが消えると、フォーカスが
  // 前に通った部品へ移り、続けて押したEnterでそれが動いた（引き継ぎでは
  // 最後のチェックが外れる・狭い画面では書き出しが始まる、ゴミ箱と共有では
  // 並びの向きが変わる）。
  for (final (route, noticeKey, size) in const [
    ('/settings/transfer', 'transferProjectsLoadFailed', Size(1280, 800)),
    ('/settings/transfer', 'transferProjectsLoadFailed', Size(320, 568)),
    ('/trash', 'trashProjectsLoadFailed', Size(1280, 800)),
    ('/shared', 'sharedProjectsLoadFailed', Size(1280, 800)),
  ]) {
    testWidgets('after a keyboard Retry on $route (${size.width.toInt()}px) '
        'the next Enter does nothing', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final shareCalls = <String>[];
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        shareCalls.add(call.method);
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
      final seeded = await tester.runAsync(
        () => _seedProjectWithSaves(name: '読み直す作品', comments: const []),
      );
      final (project, _) = seeded!;
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        if (route == '/trash')
          'trashed_projects': [
            '${project.id}|${DateTime.now().toIso8601String()}',
          ],
      });
      storage.paths.blockListing(storage.projectsPath);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await _settleWithFiles(tester);
      appRouter.push(route);
      await _settleWithFiles(tester);

      // Tabで知らせの「再試行」まで進む。
      final key = Key(noticeKey);
      for (var i = 0; i < 60 && !_focusInsideKey(key); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(_focusInsideKey(key), isTrue, reason: 'Tab never reached Retry');

      // 読めるようになってから、Enterで読み直す。
      storage.paths.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final notice = find.byKey(key, skipOffstage: false);
      for (var i = 0; i < 40 && notice.evaluate().isNotEmpty; i++) {
        await _settleWithFiles(tester, rounds: 2);
      }
      await _settleWithFiles(tester);
      expect(notice, findsNothing);
      expect(
        _focusedControl(),
        isNull,
        reason: 'the focus fell back to a control the user had passed',
      );

      // 続けて押したEnterで、何も動かない。
      final before = _controlStates(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settleWithFiles(tester, rounds: 20);
      expect(_controlStates(tester), before);
      expect(shareCalls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        storage.directory
            .listSync(recursive: true)
            .where((file) => file.path.endsWith('.niatra')),
        isEmpty,
        reason: 'the second Enter started an export',
      );
      expect(
        appRouter
            .routerDelegate
            .currentConfiguration
            .matches
            .last
            .matchedLocation,
        route,
        reason: 'the second Enter left the screen',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 作品を読み込めなかったとき、ホームのプロジェクトだけ、知らせのすぐ下に
  // 「プロジェクトがありません」「＋ ボタンから新規作成」が出ていた（読め
  // なかっただけなのに「無い」と読め、新しく作るよう促す。共有・ゴミ箱・
  // 引き継ぎは空の文を出さない）。読み込めなかった間は知らせだけを出し、
  // 読めて本当に作品が無いと分かったら、いつもの空の表示に戻る。
  for (final language in ['ja', 'en', 'fr', 'ko']) {
    testWidgets('Home does not say there are no projects, or invite creating '
        'one, while they could not be read ($language)', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': language,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final l10n = lookupAppLocalizations(Locale(language));
      Directory(storage.projectsPath).createSync(recursive: true);
      storage.paths.blockListing(storage.projectsPath);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await _settleWithFiles(tester);
      final notice = find.byKey(const Key('homeProjectsLoadFailed'));
      final projects = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>();
      expect(projects.projectsLoadFailed, isTrue);
      expect(projects.folders, isEmpty);

      final saidEmpty = <String>[];
      final invitedCreating = <String>[];
      for (final size in const [Size(320, 568), Size(1280, 800)]) {
        for (final scale in [1.0, 2.0]) {
          final where = '${size.width.toInt()}px x$scale';
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await _settleWithFiles(tester, rounds: 3);
          expect(notice, findsOneWidget, reason: where);
          expect(
            find.descendant(
              of: notice,
              matching: find.text(l10n.homeProjectsLoadFailed),
            ),
            findsOneWidget,
            reason: where,
          );
          if (find.text(l10n.projectListEmptyTitle).evaluate().isNotEmpty) {
            saidEmpty.add(where);
          }
          if (find.text(l10n.projectListEmptyHint).evaluate().isNotEmpty) {
            invitedCreating.add(where);
          }
          // 並び順などの見出しは、知らせと一緒に出たまま。
          expect(
            find.widgetWithText(FilterChip, l10n.homeFavoritesOnly),
            findsOneWidget,
            reason: where,
          );
          expect(tester.takeException(), isNull, reason: where);
        }
      }
      expect(saidEmpty, isEmpty, reason: 'said there are no projects');
      expect(invitedCreating, isEmpty, reason: 'invited creating a project');

      // 読めるようになって「再試行」：作品が1つも無いと分かったので、
      // いつもの空の表示と作成の案内が出る。
      tester.view.physicalSize = const Size(1280, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await _settleWithFiles(tester, rounds: 3);
      storage.paths.clear();
      await tester.tap(
        find.descendant(of: notice, matching: find.text(l10n.communityRetry)),
      );
      for (var i = 0; i < 40 && notice.evaluate().isNotEmpty; i++) {
        await _settleWithFiles(tester, rounds: 2);
      }
      expect(notice, findsNothing);
      expect(find.text(l10n.projectListEmptyTitle), findsOneWidget);
      expect(find.text(l10n.projectListEmptyHint), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 一部の作品だけ読めないときは、読めた作品をこれまでどおり並べる。
  // 絞り込んで何も残らないとき（お気に入りだけ等）も、読めていない
  // 作品があるうちは「プロジェクトがありません」とは言わない。
  testWidgets('Home lists the works that were read beside the notice, and a '
      'filter that leaves none does not say there are no projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final seeded = await tester.runAsync(() async {
      final read = await _seedProjectWithSaves(
        name: '読めた作品',
        comments: const [],
      );
      final unread = await _seedProjectWithSaves(
        name: '開けない作品',
        comments: const [],
      );
      return (read.$1, unread.$1);
    });
    final (_, unread) = seeded!;
    storage.paths.blockReading(
      '${storage.projectsPath}/${unread.id}/${unread.id}.niapro',
    );
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    final notice = find.byKey(const Key('homeProjectsLoadFailed'));
    expect(notice, findsOneWidget);
    expect(find.text('読めた作品'), findsOneWidget);
    expect(find.text('開けない作品'), findsNothing);
    expect(find.text('プロジェクトがありません'), findsNothing);

    // お気に入りだけに絞る（読めた作品はお気に入りではない）。
    final favoritesOnly = find.widgetWithText(FilterChip, 'お気に入り');
    await tester.tap(favoritesOnly);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.text('読めた作品'), findsNothing);
    expect(notice, findsOneWidget);
    expect(find.text('プロジェクトがありません'), findsNothing);
    expect(find.text('＋ ボタンから新規作成'), findsNothing);

    // 読めるようになって「再試行」：知らせが消え、お気に入りが無いことを
    // いつもの空の表示で伝える。絞り込みを外すと2作品とも並ぶ。
    storage.paths.clear();
    await tester.tap(find.descendant(of: notice, matching: find.text('再試行')));
    for (var i = 0; i < 40 && notice.evaluate().isNotEmpty; i++) {
      await _settleWithFiles(tester, rounds: 2);
    }
    expect(notice, findsNothing);
    expect(find.text('プロジェクトがありません'), findsOneWidget);
    await tester.tap(favoritesOnly);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.text('読めた作品'), findsOneWidget);
    expect(find.text('開けない作品'), findsOneWidget);
    expect(find.text('プロジェクトがありません'), findsNothing);
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

/// キーボードのフォーカスが、[key]の部品の中にあるか（一覧の描画範囲の
/// 外にある部品も数えるため、フォーカスの側からたどる）。
bool _focusInsideKey(Key key) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  var inside = focused.widget.key == key;
  focused.visitAncestorElements((element) {
    inside = inside || element.widget.key == key;
    return !inside;
  });
  return inside;
}

bool _isControl(Widget widget) =>
    widget is ButtonStyleButton ||
    widget is IconButton ||
    widget is CheckboxListTile ||
    widget is ListTile ||
    widget is InkResponse;

/// キーボードのフォーカスがある、Enterで動く部品（ボタン・チェックの行）。
/// フォーカスがどの部品にも無ければnull。
Widget? _focusedControl() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  Widget? control = _isControl(focused.widget) ? focused.widget : null;
  focused.visitAncestorElements((element) {
    if (control == null && _isControl(element.widget)) control = element.widget;
    return control == null;
  });
  return control;
}

/// 画面のチェックの入り切りと、出ているアイコン（並びの向き等）。
List<String> _controlStates(WidgetTester tester) => [
  for (final element
      in find.byType(CheckboxListTile, skipOffstage: false).evaluate())
    'check=${(element.widget as CheckboxListTile).value}',
  for (final element in find.byType(Icon, skipOffstage: false).evaluate())
    'icon=${(element.widget as Icon).icon?.codePoint.toRadixString(16)}',
];

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

/// 本物のProjectServiceで、作品・フォルダ・ゴミ箱の状態を保存先と設定へ
/// 作る（前に作った分は読み込んでから足す）。
Future<T> _seed<T>(Future<T> Function(ProjectService service) build) async {
  final service = ProjectService();
  _seedServices['seed#${_seedServices.length}'] = service;
  await service.init();
  return build(service);
}

Future<Project> _createWork(ProjectService service, String name) =>
    service.createProject(
      name: name,
      fps: 2,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 36,
    );

/// フォルダを作って[works]の名前の作品を入れ、中身ごとゴミ箱へ移す。
Future<(ProjectFolder, List<Project>)> _seedTrashedFolder(
  String name,
  List<String> works,
) => _seed((service) async {
  final folder = await service.createFolder(name);
  final projects = <Project>[];
  for (final work in works) {
    final project = await _createWork(service, work);
    await service.moveToFolder(project.id, folder.id);
    projects.add(project);
  }
  await service.moveFolderToTrash(folder.id);
  return (folder, projects);
});

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
