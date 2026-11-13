import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/screens/home/widgets/folder_delete_dialog.dart';
import 'package:niarim/screens/home/widgets/folder_save_feedback.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/utils/folder_persistence.dart';
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

    // 書き直す・新しく書く・書いてから消す。
    await saveTree.setSlotMemo(project.id, 0, '書き直した');
    await saveTree.setSlotMemo(project.id, 2, '新しいメモ');
    await saveTree.setSlotMemo(project.id, 3, '書いてから');
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

  // 保存の一覧だけを読めない起動（作品は開け、他に読めないものも無い）
  // では、ホームに知らせも「再試行」も出ない。その間に書いたメモは、
  // 「書けた」と返ってスロットに出たまま、次の起動で消えていた。書けて
  // いない間は書けたと返さず、読めるようになった後は、次にメモを書いた
  // ときに一覧を読んで、それまでのメモごと保存する。
  test('a slot memo typed while only the save list is unreadable is not '
      'reported as saved, and the next memo saves both once the list can '
      'be read', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final seeder = SaveTreeService()..setSlotMax(5);
    await seeder.init();
    await seeder.setSlotMemo(project.id, 3, '前のメモ');
    seeder.dispose();
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    final before = File(indexPath).readAsStringSync();
    Map<String, dynamic> memosOnDisk() =>
        (jsonDecode(File(indexPath).readAsStringSync()) as Map)['slotMemos']
            as Map<String, dynamic>;
    storage.paths.blockReading(indexPath);

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
    expect(projects.projectsLoadFailed, isFalse, reason: 'no Retry is shown');
    expect(saveTree.getNodes(project.id), isEmpty);

    expect(
      await saveTree.setSlotMemo(project.id, 0, '書き直した'),
      isFalse,
      reason: 'the memo was reported as saved',
    );
    // この起動の間は、書いたメモを出しておく。
    expect(saveTree.slotMemoOf(project.id, 0), '書き直した');

    // 読めるようになった。「再試行」は無いが、次のメモで読んで保存する。
    storage.paths.clear();
    expect(File(indexPath).readAsStringSync(), before);
    expect(await saveTree.setSlotMemo(project.id, 2, '新しいメモ'), isTrue);
    void expectMemos(SaveTreeService service) {
      expect(service.getNodes(project.id).map((n) => n.id), [
        saves[0].id,
        saves[1].id,
      ]);
      expect(service.slotMemoOf(project.id, 0), '書き直した');
      expect(service.slotMemoOf(project.id, 1), 'B');
      expect(service.slotMemoOf(project.id, 2), '新しいメモ');
      expect(service.slotMemoOf(project.id, 3), '前のメモ');
    }

    expectMemos(saveTree);
    expect(memosOnDisk(), {'0': '書き直した', '1': 'B', '2': '新しいメモ', '3': '前のメモ'});
    final again = SaveTreeService()..setSlotMax(5);
    addTearDown(again.dispose);
    await again.init();
    expectMemos(again);
  });

  // 一覧を読めていない間は、保存してあるメモが編集の欄に出ない（空で
  // 開く）。何も打たずに確定しただけで「消した」ことにすると、読めた
  // ときに、見えていなかったメモを空で上書きした。この起動で書いた
  // メモを消したときだけ、消したことにする。
  test('confirming an empty memo for a slot whose saved memo was not shown '
      '(unread list) does not erase it', () async {
    final (project, _) = await _seedProjectWithSaves(comments: ['A']);
    final seeder = SaveTreeService()..setSlotMax(5);
    await seeder.init();
    await seeder.setSlotMemo(project.id, 2, '大事なメモ');
    seeder.dispose();
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    storage.paths.blockReading(indexPath);

    final service = SaveTreeService()..setSlotMax(5);
    addTearDown(service.dispose);
    await service.init();
    expect(service.slotMemoOf(project.id, 2), isNull);
    // 空で開いた欄を、そのまま確定した。
    await service.setSlotMemo(project.id, 2, '');
    // この起動で書いたメモを、消した。
    await service.setSlotMemo(project.id, 0, '下書き');
    await service.setSlotMemo(project.id, 0, '');

    storage.paths.clear();
    await service.loadUnread();
    void expectMemos(SaveTreeService saves) {
      expect(saves.slotMemoOf(project.id, 2), '大事なメモ');
      expect(saves.slotMemoOf(project.id, 0), '');
    }

    expectMemos(service);
    final again = SaveTreeService()..setSlotMax(5);
    addTearDown(again.dispose);
    await again.init();
    expectMemos(again);

    // 読めるようになってから空のまま確定したとき（その場で読める）も同じ。
    storage.paths.blockReading(indexPath);
    final later = SaveTreeService()..setSlotMax(5);
    addTearDown(later.dispose);
    await later.init();
    storage.paths.clear();
    expect(await later.setSlotMemo(project.id, 2, ''), isTrue);
    expect(later.slotMemoOf(project.id, 2), '大事なメモ');
    expect(
      (jsonDecode(File(indexPath).readAsStringSync()) as Map)['slotMemos'],
      {'0': '', '2': '大事なメモ'},
    );
  });

  // 一覧を読めていない間に保存すると、読み直し（「再試行」）はその作品を
  // 飛ばし（この起動で保存した作品は読み直さない決まり）、前の保存は
  // 出ないままだった。次の起動では、新しい保存は一覧に無いファイルとして
  // 別のスロットへ入り、付けたメモも消えた。読めたときに、この起動の
  // 保存とメモを読んだ一覧へ重ねる：保存したスロットはそのまま、同じ
  // スロットにあった前の保存は消さずに空いているスロットへ移す。
  test(
    'saves made while the save list was unread keep their slots and '
    'memos when Retry reads it, and the saves that were there stay',
    () async {
      final (project, saves) = await _seedProjectWithSaves(
        name: '保存を読めない作品',
        comments: ['A', 'B'],
      );
      final seeder = SaveTreeService()..setSlotMax(5);
      await seeder.init();
      await seeder.setSlotMemo(project.id, 3, '消すメモ');
      seeder.dispose();
      final folder = '${storage.projectsPath}/${project.id}/SaveTree';
      final indexPath = '$folder/${SaveTreeService.indexFileName}';
      final before = File(indexPath).readAsStringSync();
      storage.paths.blockReading(indexPath);

      final service = SaveTreeService()..setSlotMax(5);
      addTearDown(service.dispose);
      await service.init();
      expect(service.getNodes(project.id), isEmpty);
      // 保存の画面と同じ順：保存してから、打ったコメントをスロットのメモに
      // する。
      Future<SaveNode> save(int slot, String comment) async {
        final node = await _saveToSlot(service, project, slot, comment);
        await service.setSlotMemo(project.id, slot, comment);
        return node;
      }

      final c = await save(3, 'セーブC');
      // 空に見えるスロット0（前の保存「A」がある）へも保存する。
      final d = await save(0, 'セーブD');

      storage.paths.clear();
      expect(File(indexPath).readAsStringSync(), before);
      await service.loadUnread();
      void expectMerged(SaveTreeService saveTree) {
        final bySlot = {
          for (final n in saveTree.getNodes(project.id)) n.slotIndex: n.id,
        };
        expect(bySlot, {
          0: d.id,
          1: saves[1].id,
          // 「A」は消さず、空いているスロットへ。
          2: saves[0].id,
          3: c.id,
        });
        expect(saveTree.getArchivedNodes(project.id), isEmpty);
        expect(
          [
            for (var i = 0; i < 4; i++)
              saveTree.slotDisplayMemoOf(project.id, i),
          ],
          ['セーブD', 'B', 'A', 'セーブC'],
        );
      }

      expectMerged(service);
      for (final id in [saves[0].id, saves[1].id, c.id, d.id]) {
        expect(File('$folder/$id.niapro').existsSync(), isTrue, reason: id);
      }
      // もう一度読み直しても変わらず、次の起動でも同じ。
      final written = File(indexPath).readAsStringSync();
      await service.loadUnread();
      expectMerged(service);
      expect(File(indexPath).readAsStringSync(), written);
      final again = SaveTreeService()..setSlotMax(5);
      addTearDown(again.dispose);
      await again.init();
      expectMerged(again);
    },
  );

  // 一覧を読めていない間に保存したスロットにあった前の保存は、空いている
  // スロットのうち、メモだけが付いたスロットを避けて移す（入るとそのメモの
  // 名前で呼ばれ、前の保存のメモは消えていた）。前の保存のメモは、移した
  // 先のスロットへ一緒に移す。コメントを空にして保存したときは、元の
  // スロットに前の保存のメモを残さない（新しい保存がそのメモで呼ばれ、
  // 2つのスロットが同じ名前になった）。保存はどれも消さない。
  for (final comment in ['セーブD', '']) {
    test('a save that gave its slot to a save made while the list was '
        'unread moves with its own memo to a slot without one '
        '(${comment.isEmpty ? 'blank comment' : 'with a comment'})', () async {
      final (project, saves) = await _seedProjectWithSaves(
        comments: ['A', 'B'],
      );
      // スロット0の保存「A」には、保存のコメントと違うメモを付けておく
      // （移した先で、どちらの名前で呼ばれるか分かるように）。スロット2は
      // メモだけ。
      final seeder = SaveTreeService()..setSlotMax(5);
      await seeder.init();
      await seeder.setSlotMemo(project.id, 0, 'Aのメモ');
      await seeder.setSlotMemo(project.id, 2, '次はここ');
      seeder.dispose();
      final folder = '${storage.projectsPath}/${project.id}/SaveTree';
      final indexPath = '$folder/${SaveTreeService.indexFileName}';
      Map<String, dynamic> memosOnDisk() =>
          (jsonDecode(File(indexPath).readAsStringSync()) as Map)['slotMemos']
              as Map<String, dynamic>;
      expect(memosOnDisk(), {'0': 'Aのメモ', '1': 'B', '2': '次はここ'});
      storage.paths.blockReading(indexPath);

      final service = SaveTreeService()..setSlotMax(5);
      addTearDown(service.dispose);
      await service.init();
      expect(service.getNodes(project.id), isEmpty);
      // 保存の画面と同じ順：空に見えるスロット0（前の保存「A」がある）へ
      // 保存してから、打ったコメントをスロットのメモにする。
      final projects = _seedServices[project.id]!;
      final d = await service.saveToSlot(
        projectId: project.id,
        slotIndex: 0,
        project: project,
        scenes: projects.scenesOf(project.id),
        tileManager: projects.tileManagerOf(project.id),
        comment: comment.isEmpty ? null : comment,
      );
      await service.setSlotMemo(project.id, 0, comment);

      storage.paths.clear();
      await service.loadUnread();
      void expectMoved(SaveTreeService saveTree) {
        final bySlot = {
          for (final n in saveTree.getNodes(project.id)) n.slotIndex: n.id,
        };
        expect(bySlot, {0: d.id, 1: saves[1].id, 3: saves[0].id});
        expect(saveTree.getArchivedNodes(project.id), isEmpty);
        expect(
          [
            for (var i = 0; i < 5; i++)
              saveTree.slotDisplayMemoOf(project.id, i),
          ],
          [comment, 'B', '次はここ', 'Aのメモ', null],
        );
      }

      expectMoved(service);
      expect(memosOnDisk(), {'0': comment, '1': 'B', '2': '次はここ', '3': 'Aのメモ'});
      for (final id in [saves[0].id, saves[1].id, d.id]) {
        expect(File('$folder/$id.niapro').existsSync(), isTrue, reason: id);
      }
      final again = SaveTreeService()..setSlotMax(5);
      addTearDown(again.dispose);
      await again.init();
      expectMoved(again);
    });
  }

  // 一覧を読めない間にスロットへ保存し（コメント「セーブE」）、読み直さずに
  // 終えて、次の起動で一覧を読めると、保存はファイルから拾い直されるが
  // コメントもスロットのメモも無く、空いた最初のスロットへ入った（メモ
  // だけのスロットなら、そのメモの名前で呼ばれた）。保存ごとに控えを
  // 残し、次に一覧を読めたときに、この起動の保存と同じく重ねる（保存した
  // スロットのまま、そこにあった前の保存は自分のメモごと空きスロットへ。
  // コメントを空にした保存の決まりも同じ）。どの保存も消さない。
  for (final (slot, comment) in [(2, 'セーブE'), (0, 'セーブE'), (0, '')]) {
    test('a save made while the save list was unread keeps its slot and '
        'comment after a restart (slot $slot, '
        '${comment.isEmpty ? 'blank comment' : 'with a comment'})', () async {
      final (project, saves) = await _seedProjectWithSaves(
        comments: ['A', 'B'],
      );
      final seeder = SaveTreeService()..setSlotMax(5);
      await seeder.init();
      await seeder.setSlotMemo(project.id, 0, 'Aのメモ');
      await seeder.setSlotMemo(project.id, 2, '次はここ');
      seeder.dispose();
      final folder = '${storage.projectsPath}/${project.id}/SaveTree';
      final indexPath = '$folder/${SaveTreeService.indexFileName}';
      storage.paths.blockReading(indexPath);

      final service = SaveTreeService()..setSlotMax(5);
      await service.init();
      expect(service.getNodes(project.id), isEmpty);
      // 保存の画面と同じ順：保存してから、打ったコメントをスロットのメモに。
      final projects = _seedServices[project.id]!;
      final e = await service.saveToSlot(
        projectId: project.id,
        slotIndex: slot,
        project: project,
        scenes: projects.scenesOf(project.id),
        tileManager: projects.tileManagerOf(project.id),
        comment: comment.isEmpty ? null : comment,
      );
      await service.setSlotMemo(project.id, slot, comment);
      // 読み直さずに終える。
      service.dispose();

      storage.paths.clear();
      void expectKept(SaveTreeService saveTree) {
        final bySlot = {
          for (final n in saveTree.getNodes(project.id)) n.slotIndex: n,
        };
        expect(
          bySlot.map((k, v) => MapEntry(k, v.id)),
          slot == 2
              ? {0: saves[0].id, 1: saves[1].id, 2: e.id}
              : {0: e.id, 1: saves[1].id, 3: saves[0].id},
          reason: 'the save lost its slot',
        );
        expect(bySlot[slot]!.comment, comment.isEmpty ? null : comment);
        expect(saveTree.getArchivedNodes(project.id), isEmpty);
        expect(
          [
            for (var i = 0; i < 5; i++)
              saveTree.slotDisplayMemoOf(project.id, i),
          ],
          slot == 2
              ? ['Aのメモ', 'B', 'セーブE', null, null]
              : [comment, 'B', '次はここ', 'Aのメモ', null],
        );
      }

      final again = SaveTreeService()..setSlotMax(5);
      addTearDown(again.dispose);
      await again.init();
      expectKept(again);
      for (final id in [saves[0].id, saves[1].id, e.id]) {
        expect(File('$folder/$id.niapro').existsSync(), isTrue, reason: id);
      }
      // 一覧に書けたので、控えは残さない。
      expect(
        Directory(folder).listSync().where(
          (f) => f.path.endsWith(SaveTreeService.pendingSuffix),
        ),
        isEmpty,
      );
      // 一覧に書いたので、次の起動でも同じ。
      final third = SaveTreeService()..setSlotMax(5);
      addTearDown(third.dispose);
      await third.init();
      expectKept(third);
    });
  }

  // 一覧を読めないまま2回起動して、2回とも同じスロットへ保存した：読めた
  // ときは新しい方がそのスロットに入り、前の方も、そこにあった一覧の保存も
  // 消さずに、自分のメモごと空きスロットへ移る。読めない間の起動では、
  // 前の起動の保存はまだ出ない（一覧を読めないので）が、消えもしない。
  test('saves made in two starts while the save list stayed unread are all '
      'kept, the newest in its slot', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final folder = '${storage.projectsPath}/${project.id}/SaveTree';
    final indexPath = '$folder/${SaveTreeService.indexFileName}';
    storage.paths.blockReading(indexPath);
    Future<SaveNode> saveIn(String comment) async {
      final service = SaveTreeService()..setSlotMax(5);
      await service.init();
      expect(service.getNodes(project.id), isEmpty);
      final node = await _saveToSlot(service, project, 0, comment);
      await service.setSlotMemo(project.id, 0, comment);
      service.dispose();
      return node;
    }

    final d = await saveIn('セーブD');
    // 同じミリ秒に保存すると、どちらが新しいか分からない。
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final f = await saveIn('セーブF');

    storage.paths.clear();
    final read = SaveTreeService()..setSlotMax(5);
    addTearDown(read.dispose);
    await read.init();
    final bySlot = {
      for (final n in read.getNodes(project.id)) n.slotIndex: n.id,
    };
    expect(bySlot, {0: f.id, 1: saves[1].id, 2: saves[0].id, 3: d.id});
    expect(
      [for (var i = 0; i < 5; i++) read.slotDisplayMemoOf(project.id, i)],
      ['セーブF', 'B', 'A', 'セーブD', null],
    );
    for (final id in [saves[0].id, saves[1].id, d.id, f.id]) {
      expect(File('$folder/$id.niapro').existsSync(), isTrue, reason: id);
    }
  });

  // 控えは、その後に一覧へ入った新しい保存をスロットから追い出さない：
  // 一覧を読めない間にスロット0へ保存（控え）→次の起動は一覧を読めたが
  // 保存のフォルダを一覧できず（控えを読めない）、スロット0へ上書き保存
  // （一覧に入る）→その次に読めたとき、新しい方がスロット0のまま、控えの
  // 保存は自分のメモごと空きスロットへ。
  test('a save kept only in its note does not push a newer listed save out '
      'of its slot', () async {
    final (project, saves) = await _seedProjectWithSaves(comments: ['A', 'B']);
    final folder = '${storage.projectsPath}/${project.id}/SaveTree';
    final indexPath = '$folder/${SaveTreeService.indexFileName}';
    storage.paths.blockReading(indexPath);
    final first = SaveTreeService()..setSlotMax(5);
    await first.init();
    final d = await _saveToSlot(first, project, 0, 'セーブD');
    await first.setSlotMemo(project.id, 0, 'セーブD');
    first.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    storage.paths
      ..clear()
      ..blockListing(folder);
    final second = SaveTreeService()..setSlotMax(5);
    await second.init();
    expect(second.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
    ]);
    final f = await _saveToSlot(second, project, 0, 'セーブF');
    await second.setSlotMemo(project.id, 0, 'セーブF');
    second.dispose();

    storage.paths.clear();
    final third = SaveTreeService()..setSlotMax(5);
    addTearDown(third.dispose);
    await third.init();
    final bySlot = {
      for (final n in third.getNodes(project.id)) n.slotIndex: n.id,
    };
    expect(bySlot, {0: f.id, 1: saves[1].id, 2: d.id});
    expect(
      [for (var i = 0; i < 3; i++) third.slotDisplayMemoOf(project.id, i)],
      ['セーブF', 'B', 'セーブD'],
    );
    expect(File('$folder/${d.id}.niapro').existsSync(), isTrue);
  });

  // セーブツリー：一覧を読めない間に枝分かれして保存した保存も、次の起動で
  // 親とコメントごと戻る（拾い直すと、根のコメント無しの保存になった）。
  test('a branch saved in the save tree while its list was unread keeps its '
      'parent and comment after a restart', () async {
    final (project, _) = await _seedProjectWithSaves(comments: const []);
    final seeder = SaveTreeService()..setTreeMode(true);
    await seeder.init();
    final projects = _seedServices[project.id]!;
    Future<SaveNode> branch(SaveTreeService s, String? parent, String c) =>
        s.saveAsChild(
          projectId: project.id,
          project: project,
          scenes: projects.scenesOf(project.id),
          tileManager: projects.tileManagerOf(project.id),
          parentId: parent,
          comment: c,
        );
    final root = await branch(seeder, null, '根');
    seeder.dispose();
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    storage.paths.blockReading(indexPath);

    final service = SaveTreeService()..setTreeMode(true);
    await service.init();
    final leaf = await branch(service, root.id, '枝');
    service.dispose();

    storage.paths.clear();
    final again = SaveTreeService()..setTreeMode(true);
    addTearDown(again.dispose);
    await again.init();
    final byId = {for (final n in again.getNodes(project.id)) n.id: n};
    expect(byId.keys, unorderedEquals([root.id, leaf.id]));
    expect(byId[leaf.id]!.comment, '枝');
    expect(byId[leaf.id]!.parentId, root.id);
    expect(byId[root.id]!.comment, '根');
  });

  // 保存の画面：一覧を読めていない間にメモを書いて「保存」を押すと、
  // 何も言わずにメモがスロットへ出ていた（保存できたように見える）。
  // 保存データを読み込めていないことを知らせる。読めるようになった後は、
  // メモを書くと前の保存が出て、それまでのメモも保存される。
  testWidgets('the slot memo editor says the save data could not be read '
      'instead of looking saved, and saves once it can be read', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final seeded = await tester.runAsync(
      () => _seedProjectWithSaves(name: '保存を読めない作品', comments: ['A', 'B']),
    );
    final (project, saves) = seeded!;
    final indexPath =
        '${storage.projectsPath}/${project.id}/SaveTree/'
        '${SaveTreeService.indexFileName}';
    final before = File(indexPath).readAsStringSync();
    storage.paths.blockReading(indexPath);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    expect(find.byKey(const Key('homeProjectsLoadFailed')), findsNothing);
    appRouter.push('/save-tree/${project.id}?entry=detail');
    await _settleWithFiles(tester, rounds: 6);
    final saveTree = tester
        .element(find.byType(Scaffold).first)
        .read<SaveTreeService>();
    expect(saveTree.getNodes(project.id), isEmpty);

    Future<void> typeMemo(int slot, String text) async {
      final pencil = find.byKey(Key('saveSlotMemo_${project.id}_$slot'));
      await tester.ensureVisible(pencil);
      await tester.tap(pencil);
      await _settleWithFiles(tester, rounds: 3);
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await _settleWithFiles(tester, rounds: 4);
    }

    const failed = '保存データの読み込みに失敗しました';
    await typeMemo(0, '書き直した');
    expect(find.text('書き直した'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text(failed)),
      findsOneWidget,
      reason: 'the memo looked saved',
    );
    storage.paths.clear();
    expect(File(indexPath).readAsStringSync(), before);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).removeCurrentSnackBar();
    await _settleWithFiles(tester, rounds: 3);
    expect(find.byType(SnackBar), findsNothing);

    // 読めるようになってから、別のスロットへ書く。
    await typeMemo(2, '新しいメモ');
    expect(find.byType(SnackBar), findsNothing);
    expect(saveTree.getNodes(project.id).map((n) => n.id), [
      saves[0].id,
      saves[1].id,
    ]);
    expect(find.text('書き直した'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('新しいメモ'), findsOneWidget);
    expect(
      (jsonDecode(File(indexPath).readAsStringSync()) as Map)['slotMemos'],
      {'0': '書き直した', '1': 'B', '2': '新しいメモ'},
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });

  // 保存の画面の「保存」（スロットへ保存→打ったコメントをメモに）：保存の
  // 一覧を読めていない間は、メモが次の起動に残らないかもしれないので、
  // メモの欄と同じく「保存データの読み込みに失敗しました」と知らせる
  // （何も言わずに閉じていた）。スロットの画面（保存の管理）と、セーブ
  // ツリーの画面のスロット表示の両方。
  for (final screen in ['save management', 'save tree']) {
    testWidgets('saving to a slot from the $screen screen while the save list '
        'is unread says the save data could not be read', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final seeded = await tester.runAsync(
        () => _seedProjectWithSaves(name: '保存を読めない作品', comments: ['A', 'B']),
      );
      final (project, _) = seeded!;
      final indexPath =
          '${storage.projectsPath}/${project.id}/SaveTree/'
          '${SaveTreeService.indexFileName}';
      final before = File(indexPath).readAsStringSync();
      storage.paths.blockReading(indexPath);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      if (screen == 'save management') {
        await tester.pumpWidget(
          MultiProvider(providers: providers!, child: const NiarimApp()),
        );
        await _settleWithFiles(tester);
        appRouter.push('/save-tree/${project.id}?entry=detail');
      } else {
        await tester.pumpWidget(
          MultiProvider(
            providers: providers!,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SaveTreeScreen(
                projectId: project.id,
                entryMode: SaveTreeEntryMode.projectDetail,
              ),
            ),
          ),
        );
      }
      await _settleWithFiles(tester, rounds: 6);
      final saveTree = tester
          .element(find.byType(Scaffold).first)
          .read<SaveTreeService>();
      expect(saveTree.isTreeMode, isFalse);
      expect(saveTree.getNodes(project.id), isEmpty);

      final write = find.byTooltip('このスロットへ保存').at(2);
      await tester.ensureVisible(write);
      await tester.tap(write);
      await _settleWithFiles(tester, rounds: 3);
      await tester.enterText(find.byType(TextField), '線画まで');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      // 保存（サムネイルの合成・書き込み・メモ）が終わってダイアログが
      // 閉じるまで待つ（保存中のボタンは「保存」の文字ではなく回る印に
      // なるので、文字が消えたことでは待てない。負荷の高い端末では
      // 120ms程度では終わらなかった）。失敗の文が出たら待たない。
      for (
        var i = 0;
        i < 200 &&
            (saveTree.getNodes(project.id).isEmpty ||
                find.byType(AlertDialog).evaluate().isNotEmpty) &&
            find.byKey(const Key('saveSlotDialogFailure')).evaluate().isEmpty;
        i++
      ) {
        await _settleWithFiles(tester, rounds: 1);
      }
      await _settleWithFiles(tester, rounds: 3);
      // 保存はできている（保存のファイルは残り、読めたときに出る）。
      expect(saveTree.getNodes(project.id), hasLength(1));
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('保存データの読み込みに失敗しました'),
        ),
        findsOneWidget,
        reason: 'the memo looked saved',
      );
      storage.paths.clear();
      expect(File(indexPath).readAsStringSync(), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }

  // 保存のダイアログ（スロットの画面〔保存の管理〕とセーブツリーの画面の
  // 「スロットNに保存」、セーブツリーの「保存」）：開いてもメモの欄に
  // フォーカスが無く、クリックする前に打った字はどこにも入らなかった
  // （メモだけのダイアログは欄にフォーカスがある）。開いたらすぐ打て、
  // Enterで保存する（続けてEnterを押しても二重に保存しない）。
  for (final screen in ['save management', 'save tree slots', 'save tree']) {
    testWidgets('the save dialog of the $screen screen takes typing at once '
        'and Enter saves once', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final seeded = await tester.runAsync(
        () => _seedProjectWithSaves(name: '保存する作品', comments: ['A']),
      );
      final (project, saves) = seeded!;
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      if (screen == 'save tree slots') {
        await tester.pumpWidget(
          MultiProvider(
            providers: providers!,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SaveTreeScreen(
                projectId: project.id,
                entryMode: SaveTreeEntryMode.projectDetail,
              ),
            ),
          ),
        );
      } else {
        await tester.pumpWidget(
          MultiProvider(providers: providers!, child: const NiarimApp()),
        );
        await _settleWithFiles(tester);
        if (screen == 'save tree') {
          tester
              .element(find.byType(Scaffold).first)
              .read<SaveTreeService>()
              .setTreeMode(true);
        }
        appRouter.push('/save-tree/${project.id}?entry=detail');
      }
      await _settleWithFiles(tester, rounds: 6);
      final saveTree = tester
          .element(find.byType(Scaffold).first)
          .read<SaveTreeService>();
      expect(saveTree.isTreeMode, screen == 'save tree');
      expect(saveTree.getNodes(project.id), hasLength(1));

      if (screen == 'save tree') {
        await tester.tap(find.byIcon(Icons.save));
      } else {
        final write = find.byTooltip('このスロットへ保存').at(1);
        await tester.ensureVisible(write);
        await tester.tap(write);
      }
      await _settleWithFiles(tester, rounds: 3);
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(EditableText),
      );
      expect(field, findsOneWidget);
      expect(
        tester.widget<EditableText>(field).focusNode.hasFocus,
        isTrue,
        reason: 'typing before a click goes nowhere',
      );
      // クリックせずに打って、Enterを2回。
      tester.testTextInput.enterText('線画まで');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (
        var i = 0;
        i < 200 &&
            (saveTree.getNodes(project.id).length < 2 ||
                find.byType(AlertDialog).evaluate().isNotEmpty);
        i++
      ) {
        await _settleWithFiles(tester, rounds: 1);
      }
      await _settleWithFiles(tester, rounds: 3);
      expect(find.byType(AlertDialog), findsNothing);
      final added = saveTree
          .getNodes(project.id)
          .where((n) => n.id != saves.single.id)
          .toList();
      expect(added, hasLength(1), reason: 'Enter saved twice');
      expect(added.single.comment, '線画まで');
      if (screen != 'save tree') {
        expect(added.single.slotIndex, 1);
        expect(saveTree.slotDisplayMemoOf(project.id, 1), '線画まで');
      }
      final saveFiles = Directory(
        '${storage.projectsPath}/${project.id}/SaveTree',
      ).listSync().where((f) => f.path.endsWith('.niapro'));
      expect(saveFiles, hasLength(2), reason: 'a second save was written');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }

  // 保存の一覧（SaveTree/index.json）を読めないと、保存の画面のどの
  // スロットも「保存データなし」と言った（保存のあるスロットも）。
  // ツリー表示は「保存データがありません」。読めなかったことと「再試行」を
  // 出し、空に見えるスロットに「保存データなし」と言わない。「再試行」は
  // 読めなければ知らせを残し、読めたら本当のスロット（ツリー）を出す。
  // スロットの画面（保存の管理）・セーブツリーの画面のスロット表示・
  // ツリー表示。
  for (final screen in ['save management', 'save tree slots', 'save tree']) {
    testWidgets('the $screen screen says the save list could not be read '
        'instead of no save data, and its Retry shows the saves', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final seeded = await tester.runAsync(
        () => _seedProjectWithSaves(name: '保存を読めない作品', comments: ['A', 'B']),
      );
      final (project, saves) = seeded!;
      final indexPath =
          '${storage.projectsPath}/${project.id}/SaveTree/'
          '${SaveTreeService.indexFileName}';
      final before = File(indexPath).readAsStringSync();
      storage.paths.blockReading(indexPath);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      if (screen == 'save tree slots') {
        await tester.pumpWidget(
          MultiProvider(
            providers: providers!,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SaveTreeScreen(
                projectId: project.id,
                entryMode: SaveTreeEntryMode.projectDetail,
              ),
            ),
          ),
        );
      } else {
        await tester.pumpWidget(
          MultiProvider(providers: providers!, child: const NiarimApp()),
        );
        await _settleWithFiles(tester);
        if (screen == 'save tree') {
          tester
              .element(find.byType(Scaffold).first)
              .read<SaveTreeService>()
              .setTreeMode(true);
        }
        appRouter.push('/save-tree/${project.id}?entry=detail');
      }
      await _settleWithFiles(tester, rounds: 6);
      final saveTree = tester
          .element(find.byType(Scaffold).first)
          .read<SaveTreeService>();
      expect(saveTree.isTreeMode, screen == 'save tree');
      expect(saveTree.getNodes(project.id), isEmpty);

      // 保存のあるスロット（スロット1・2）にも「保存データなし」と言わない。
      expect(find.text('保存データなし'), findsNothing, reason: 'says no data');
      expect(find.text('保存データがありません'), findsNothing);
      const failed = '保存データの読み込みに失敗しました';
      final notice = find.byKey(const Key('saveListLoadFailed'));
      expect(notice, findsOneWidget, reason: 'nothing says the list is unread');
      expect(
        find.descendant(of: notice, matching: find.text(failed)),
        findsOneWidget,
      );
      final retry = find.descendant(of: notice, matching: find.text('再試行'));

      // まだ読めないうちの「再試行」：知らせは残り、何も書き換えない。
      await tester.tap(retry);
      await _settleWithFiles(tester, rounds: 4);
      expect(notice, findsOneWidget);
      expect(find.text('保存データなし'), findsNothing);
      expect(saveTree.getNodes(project.id), isEmpty);

      // 読めるようになって「再試行」：本当のスロット（ツリー）が出る。
      storage.paths.clear();
      await tester.tap(retry);
      for (
        var i = 0;
        i < 200 &&
            (saveTree.getNodes(project.id).length < 2 ||
                notice.evaluate().isNotEmpty);
        i++
      ) {
        await _settleWithFiles(tester, rounds: 1);
      }
      await _settleWithFiles(tester, rounds: 2);
      expect(notice, findsNothing);
      expect(saveTree.getNodes(project.id).map((n) => n.id), [
        saves[0].id,
        saves[1].id,
      ]);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      if (screen != 'save tree') {
        expect(find.text('保存データなし'), findsWidgets);
      }
      expect(File(indexPath).readAsStringSync(), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
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

  // 作品を読めていない間も、フォルダはゴミ箱へ移せる（読めない作品が1つ
  // あるだけで、関係のないフォルダも空のフォルダも、読めるまでゴミ箱へ
  // 移せなかった）。そのとき読めていなかった中の作品は、読めたとき
  // （「再試行」・次の起動）に、フォルダをゴミ箱へ移した日時のまま、
  // ゴミ箱のそのフォルダへ入る（フォルダの外へ出ない）。フォルダごと
  // 戻すと一緒に戻る。
  for (final blocked in [
    'the projects folder',
    'a work in the folder',
    'an unrelated work',
  ]) {
    test('a folder moves to Trash while $blocked cannot be read, and the '
        'works read later join it there', () async {
      final (folder, sub, empty, works, unrelated) = await _seed((
        service,
      ) async {
        final folder = await service.createFolder('旅行');
        final sub = await service.createFolder('写真', parentFolderId: folder.id);
        final empty = await service.createFolder('空のフォルダ');
        final sea = await _createWork(service, '海');
        await service.moveToFolder(sea.id, folder.id);
        final mountain = await _createWork(service, '山');
        await service.moveToFolder(mountain.id, sub.id);
        final unrelated = await _createWork(service, '関係のない作品');
        return (folder, sub, empty, [sea, mountain], unrelated);
      });
      String archiveOf(Project p) =>
          '${storage.projectsPath}/${p.id}/${p.id}.niapro';
      switch (blocked) {
        case 'the projects folder':
          storage.paths.blockListing(storage.projectsPath);
        case 'a work in the folder':
          storage.paths.blockReading(archiveOf(works[1]));
        default:
          storage.paths.blockReading(archiveOf(unrelated));
      }

      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.projectsLoadFailed, isTrue);

      final emptyRecord = await service.moveFolderToTrash(empty.id);
      expect(emptyRecord?.projectIds, isEmpty);
      final record = await service.moveFolderToTrash(folder.id);
      expect(record, isNotNull);
      expect(service.folders, isEmpty);
      // 読めていなかった作品を記録に覚える（一覧できなかったときは印だけ）。
      expect(record!.unreadUnlisted, blocked == 'the projects folder');
      expect(record.unreadProjectIds, switch (blocked) {
        'the projects folder' => isEmpty,
        'a work in the folder' => [works[1].id],
        _ => [unrelated.id],
      });
      expect(
        service.trashedFolders.map((t) => t.folder.id),
        unorderedEquals([folder.id, empty.id]),
      );

      storage.paths.clear();
      await service.retryLoadProjects();
      expect(service.projectsLoadFailed, isFalse);
      void expectWhole(ProjectService projects) {
        expect(
          projects.trashedFolders.map((t) => t.folder.id),
          unorderedEquals([folder.id, empty.id]),
        );
        for (final work in works) {
          expect(
            projects.trashedFolderOf(work.id)?.folder.id,
            folder.id,
            reason: '${work.name} is not in its folder in Trash',
          );
          expect(projects.deletedAtOf(work.id), record.deletedAt);
        }
        expect(projects.trash.map((p) => p.name), unorderedEquals(['海', '山']));
        expect(projects.looseTrash, isEmpty);
        expect(projects.projects.map((p) => (p.name, p.folderId)), [
          ('関係のない作品', null),
        ]);
        // 読めた後は、読めていなかった作品を記録に残さない。
        for (final kept in projects.trashedFolders) {
          expect(kept.unreadProjectIds, isEmpty);
          expect(kept.unreadUnlisted, isFalse);
        }
      }

      expectWhole(service);
      // 次の起動でも同じ。フォルダごと戻すと、中の作品も元の場所へ戻る。
      final again = ProjectService();
      addTearDown(again.dispose);
      await again.init();
      expectWhole(again);
      await again.restoreTrashedFolder(folder.id);
      expect(
        again.folders.map((f) => f.id),
        unorderedEquals([folder.id, sub.id]),
      );
      expect(
        again.projects.map((p) => (p.name, p.folderId)),
        unorderedEquals([('海', folder.id), ('山', sub.id), ('関係のない作品', null)]),
      );
      expect(again.trash, isEmpty);
      expect(again.trashedFolders.map((t) => t.folder.id), [empty.id]);
    });
  }

  // フォルダをゴミ箱へ移したときに読めていなかった作品（記録の
  // unreadProjectIds・一覧できなかった印）は、読めたときにそのフォルダへ
  // 入るかもしれない。読めるまでは、中の作品が読めていないフォルダと
  // 同じく残す：完全に削除する・空にする・期限で片付けることをしない
  // （以前は記録の作品＝読めた作品しか見ず、読めた作品だけを完全に削除し、
  // 後で読めた作品はプロジェクトの一番上に1つだけ出た）。読めたら
  // （「再試行」・次の起動）フォルダへ入り（関係のない作品なら一番上）、
  // 残すのも終わる。
  for (final blocked in [
    'a work in the folder',
    'an unrelated work',
    'the projects folder',
  ]) {
    test('a folder moved to Trash while $blocked could not be read is kept '
        'until that is read, then cleaned up whole', () async {
      final (folder, works, unrelated) = await _seed((service) async {
        final folder = await service.createFolder('旅行');
        final sub = await service.createFolder('写真', parentFolderId: folder.id);
        final sea = await _createWork(service, '海');
        await service.moveToFolder(sea.id, folder.id);
        final flower = await _createWork(service, '花');
        await service.moveToFolder(flower.id, sub.id);
        final mountain = await _createWork(service, '山');
        await service.moveToFolder(mountain.id, folder.id);
        final unrelated = await _createWork(service, '関係のない作品');
        return (folder, [sea, flower, mountain], unrelated);
      });
      final mountain = works[2];
      String archiveOf(Project p) =>
          '${storage.projectsPath}/${p.id}/${p.id}.niapro';
      bool onDisk(Project p) =>
          Directory('${storage.projectsPath}/${p.id}').existsSync();
      switch (blocked) {
        case 'a work in the folder':
          storage.paths.blockReading(archiveOf(mountain));
        case 'an unrelated work':
          storage.paths.blockReading(archiveOf(unrelated));
        default:
          storage.paths.blockListing(storage.projectsPath);
      }

      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.projectsLoadFailed, isTrue);
      final record = (await service.moveFolderToTrash(folder.id))!;
      expect(
        service.trashedFolderHasUnreadWorks(record),
        isTrue,
        reason: 'the folder is not held while a work is unread',
      );
      await expectLater(
        service.permanentDeleteTrashedFolder(folder.id),
        throwsA(isA<TrashedFolderUnreadException>()),
      );
      await expectLater(
        service.emptyTrash(),
        throwsA(isA<TrashedFolderUnreadException>()),
      );
      expect(service.trashedFolders.map((t) => t.folder.id), [folder.id]);
      expect(works.every(onDisk), isTrue, reason: 'a read work was deleted');
      expect(onDisk(unrelated), isTrue);

      if (blocked == 'the projects folder') {
        // 保存先を一覧できるようになっても、山だけはまだ読めない：読めた
        // 作品はフォルダへ入り、覚えるのは山だけになり、まだ残す。
        storage.paths
          ..clear()
          ..blockReading(archiveOf(mountain));
        final listed = ProjectService();
        addTearDown(listed.dispose);
        await listed.init();
        final narrowed = listed.trashedFolders.single;
        expect(narrowed.unreadProjectIds, [mountain.id]);
        expect(listed.trashedFolderOf(works[0].id)?.folder.id, folder.id);
        expect(listed.trashedFolderHasUnreadWorks(narrowed), isTrue);
      }
      // 期限が過ぎて起動しても（まだ読めない）、片付けない。
      await _ageTrash(const Duration(days: 40));
      final later = ProjectService();
      addTearDown(later.dispose);
      await later.init();
      expect(
        later.trashedFolderHasUnreadWorks(later.trashedFolders.single),
        isTrue,
      );
      await later.sweepExpiredTrash(30);
      expect(later.trashedFolders.map((t) => t.folder.id), [folder.id]);
      expect(works.every(onDisk), isTrue, reason: 'swept while unread');

      // 読めるようになって起動すると、山はフォルダへ入り（関係のない作品は
      // 一番上）、残すのは終わって、期限の片付けでフォルダごと消える。
      storage.paths.clear();
      final read = ProjectService();
      addTearDown(read.dispose);
      await read.init();
      expect(read.projectsLoadFailed, isFalse);
      final kept = read.trashedFolders.single;
      expect(read.trashedFolderHasUnreadWorks(kept), isFalse);
      expect(kept.unreadProjectIds, isEmpty);
      expect(read.trashedFolderOf(mountain.id)?.folder.id, folder.id);
      expect(read.projects.map((p) => p.name), ['関係のない作品']);
      await read.sweepExpiredTrash(30);
      expect(read.trashedFolders, isEmpty);
      expect(works.any(onDisk), isFalse);
      expect(onDisk(unrelated), isTrue);
    });
  }

  // 1件ずつゴミ箱へ移してあった作品は、読めていなくても、後からゴミ箱へ
  // 移したフォルダへは入らない（読めたら1件ずつのまま）。それだけでは
  // フォルダを残さない。
  test('a work already in Trash on its own that cannot be read does not '
      'hold a folder moved to Trash later', () async {
    final (folder, loose) = await _seed((service) async {
      final folder = await service.createFolder('旅行');
      final sea = await _createWork(service, '海');
      await service.moveToFolder(sea.id, folder.id);
      final loose = await _createWork(service, '下書き');
      await service.deleteProject(loose.id);
      return (folder, loose);
    });
    storage.paths.blockReading(
      '${storage.projectsPath}/${loose.id}/${loose.id}.niapro',
    );
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.projectsLoadFailed, isTrue);
    final record = (await service.moveFolderToTrash(folder.id))!;
    expect(record.unreadProjectIds, [loose.id]);
    expect(service.trashedFolderHasUnreadWorks(record), isFalse);
    await service.permanentDeleteTrashedFolder(folder.id);
    expect(service.trashedFolders, isEmpty);

    storage.paths.clear();
    await service.retryLoadProjects();
    expect(service.looseTrash.map((p) => p.id), [loose.id]);
  });

  // 共有（受け取ったもの）のフォルダも同じ：読めていない作品があっても
  // ゴミ箱へ移せ、読めた作品はゴミ箱のそのフォルダへ入る。
  test('a received folder moves to Trash while one of its works cannot be '
      'read, and the work joins it there once read', () async {
    final (folder, works) = await _seed((service) async {
      final folder = await service.createSharedFolder('もらった絵');
      final works = <Project>[];
      for (final name in ['花', '鳥']) {
        final source = await _createWork(service, name);
        await service.saveProject(source.id);
        final data = await NiaproSerializer.load(
          '${storage.projectsPath}/${source.id}/${source.id}.niapro',
        );
        final received = await service.importSharedProject(data);
        await service.saveProject(received.id);
        await service.moveToSharedFolder(received.id, folder.id);
        await service.deleteProject(source.id);
        await service.permanentDelete(source.id);
        works.add(received);
      }
      return (folder, works);
    });
    storage.paths.blockReading(
      '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
    );
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.projectsLoadFailed, isTrue);
    final record = await service.moveFolderToTrash(folder.id, shared: true);
    expect(record?.projectIds, [works[0].id]);
    expect(service.sharedFolders, isEmpty);

    storage.paths.clear();
    await service.retryLoadProjects();
    void expectWhole(ProjectService projects) {
      for (final work in works) {
        expect(projects.trashedFolderOf(work.id)?.folder.id, folder.id);
        expect(projects.deletedAtOf(work.id), record!.deletedAt);
      }
      expect(projects.shared, isEmpty);
      expect(projects.looseTrash, isEmpty);
    }

    expectWhole(service);
    final again = ProjectService();
    addTearDown(again.dispose);
    await again.init();
    expectWhole(again);
    await again.restoreTrashedFolder(folder.id);
    expect(again.sharedFolders.map((f) => f.id), [folder.id]);
    expect(
      again.shared.map((p) => (p.name, p.sharedFolderId)),
      unorderedEquals([('花', folder.id), ('鳥', folder.id)]),
    );
  });

  // お気に入りの作品は、フォルダごとでもゴミ箱へ移さない決まり。読めて
  // いない間に移したフォルダの中にあったときは、読めたときにゴミ箱へは
  // 入れず、プロジェクトの一番上に出す（次の起動でも同じ）。
  test('a favorite work unread when its folder went to Trash stays out of '
      'Trash at the top once read', () async {
    final (folder, works) = await _seed((service) async {
      final folder = await service.createFolder('旅行');
      final works = <Project>[];
      for (final name in ['海', '星']) {
        final work = await _createWork(service, name);
        await service.moveToFolder(work.id, folder.id);
        works.add(work);
      }
      await service.setFavorite(works[1].id, true);
      return (folder, works);
    });
    storage.paths.blockReading(
      '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
    );
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    await service.moveFolderToTrash(folder.id);

    storage.paths.clear();
    await service.retryLoadProjects();
    void expectAtTop(ProjectService projects) {
      expect(projects.trashedFolderOf(works[0].id)?.folder.id, folder.id);
      expect(projects.trash.map((p) => p.name), ['海']);
      expect(projects.projects.map((p) => (p.name, p.folderId)), [('星', null)]);
      expect(projects.projects.single.isFavorite, isTrue);
    }

    expectAtTop(service);
    // 一番上へ出したことは、作品の保存にも書く（書き終わるのを待つ）。
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(
      (await NiaproSerializer.load(
        '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
      )).project.folderId,
      isNull,
    );
    final again = ProjectService();
    addTearDown(again.dispose);
    await again.init();
    expectAtTop(again);
    // フォルダを戻しても、星は一番上のまま（この起動でも、次の起動でも）。
    await again.restoreTrashedFolder(folder.id);
    void expectRestored(ProjectService projects) {
      expect(
        projects.projects.map((p) => (p.name, p.folderId)),
        unorderedEquals([('海', folder.id), ('星', null)]),
      );
    }

    expectRestored(again);
    final third = ProjectService();
    addTearDown(third.dispose);
    await third.init();
    expectRestored(third);
  });

  // フォルダをゴミ箱へ移したときに読めていなかった作品は、フォルダの記録に
  // 入っていない。読める前にフォルダを戻した・完全に削除した・期限で
  // 片付いたときは、読めたときに見える所に出ること（戻したフォルダの中、
  // または、プロジェクトの一番上。消えたフォルダを指したまま、どこにも
  // 出ないことはない）。読めていなかった作品を覚えた記録は読めるまで
  // 消さないので、完全に削除・期限で片付くのは、覚える前の版で移した
  // フォルダの記録。
  for (final early in ['restored', 'deleted', 'expired']) {
    test('a work unread when its folder went to Trash is in sight once read '
        'after the folder was $early', () async {
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
      bool onDisk(Project p) =>
          Directory('${storage.projectsPath}/${p.id}').existsSync();
      storage.paths.blockReading(
        '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
      );
      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      final record = await service.moveFolderToTrash(folder.id);
      expect(record?.projectIds, [works[0].id]);
      var current = service;
      switch (early) {
        case 'restored':
          await current.restoreTrashedFolder(folder.id);
        default:
          // この版の記録は山を覚えているので、読めるまで消さない。
          await expectLater(
            current.permanentDeleteTrashedFolder(folder.id),
            throwsA(isA<TrashedFolderUnreadException>()),
          );
          // 覚える前の版で移した記録の起動（期限は90日たった起動）。
          final prefs = await SharedPreferences.getInstance();
          final when = early == 'expired'
              ? DateTime.now().subtract(const Duration(days: 90))
              : record!.deletedAt;
          await prefs.setString(
            'trashed_project_folders',
            jsonEncode([
              TrashedFolder(
                folder: record!.folder,
                subfolders: record.subfolders,
                projectIds: record.projectIds,
                deletedAt: when,
              ).toJson(),
            ]),
          );
          await prefs.setStringList('trashed_projects', [
            '${works[0].id}|${when.toIso8601String()}',
          ]);
          current = ProjectService();
          addTearDown(current.dispose);
          await current.init();
          if (early == 'deleted') {
            await current.permanentDeleteTrashedFolder(folder.id);
          } else {
            await current.sweepExpiredTrash(30);
          }
      }
      expect(current.trashedFolders, isEmpty);
      expect(onDisk(works[0]), early == 'restored');
      expect(onDisk(works[1]), isTrue);

      storage.paths.clear();
      await current.retryLoadProjects();
      expect(current.projectsLoadFailed, isFalse);
      void expectInSight(ProjectService projects) {
        expect(projects.trash, isEmpty);
        expect(projects.trashedFolders, isEmpty);
        expect(
          projects.projects.map((p) => p.name),
          unorderedEquals(early == 'restored' ? ['海', '山'] : ['山']),
        );
        final visible = ProjectListWidget.visibleIds(
          source: projects.projects,
          allFolders: projects.folders,
          currentFolderId: early == 'restored' ? folder.id : null,
          showFavoritesOnly: false,
          searchQuery: '',
          searchByTag: false,
        );
        expect(visible, contains(works[1].id), reason: '山 is out of sight');
      }

      expectInSight(current);
      final again = ProjectService();
      addTearDown(again.dispose);
      await again.init();
      expectInSight(again);
    });
  }

  // ゴミ箱のフォルダへ後から入るのは、フォルダを移したときに読めていな
  // かった作品だけ。フォルダを移したときに読めていた作品が、後でそのフォルダを
  // 指すようになっても（古い手動の保存を読み込んだ・引き継ぎや受け取った
  // 作品を開き直した・その複製）、次の起動でゴミ箱へ入れない（入れると、
  // ゴミ箱で見たことの無い作品が、フォルダの期限で手動の保存ごと消えた）。
  String archiveOf(String id) => '${storage.projectsPath}/$id/$id.niapro';
  bool workOnDisk(String id) =>
      Directory('${storage.projectsPath}/$id').existsSync();
  for (final expired in [false, true]) {
    test('loading a save taken in a folder now in Trash leaves the work where '
        'it is${expired ? ', and the sweep keeps it' : ''}', () async {
      final (folder, work, node) = await _seed((service) async {
        final folder = await service.createFolder('下書き');
        final work = await _createWork(service, '漫画');
        await service.moveToFolder(work.id, folder.id);
        await service.setProjectTags(work.id, ['古いタグ']);
        final saves = SaveTreeService()..setSlotMax(5);
        final node = await saves.saveToSlot(
          projectId: work.id,
          slotIndex: 0,
          project: service.projects.firstWhere((p) => p.id == work.id),
          scenes: service.scenesOf(work.id),
          tileManager: service.tileManagerOf(work.id),
          comment: '線画まで',
        );
        saves.dispose();
        // 整理：作品をフォルダから出して、空になったフォルダを捨てる。
        await service.moveToFolder(work.id, null);
        await service.setProjectTags(work.id, ['新しいタグ']);
        await service.setFavorite(work.id, true);
        await service.moveFolderToTrash(folder.id);
        return (folder, work, node);
      });
      if (expired) await _ageTrash(const Duration(days: 29));
      final service = ProjectService();
      addTearDown(service.dispose);
      await service.init();
      await service.sweepExpiredTrash(30);
      final saves = SaveTreeService()..setSlotMax(5);
      addTearDown(saves.dispose);
      await saves.init();
      final data = await saves.loadNode(work.id, node.id);
      service.restoreFromAutosave(work.id, data!);
      await service.saveProject(work.id);
      // 保存から戻すのは絵の中身。フォルダ・お気に入り・タグは今のまま。
      final loaded = service.projects.single;
      expect(loaded.folderId, isNull);
      expect(loaded.isFavorite, isTrue);
      expect(loaded.tags, ['新しいタグ']);
      expect(
        (await NiaproSerializer.load(archiveOf(work.id))).project.folderId,
        isNull,
      );
      // 以前の作りで、フォルダを指し直したまま保存した作品でも同じ。
      await service.setFavorite(work.id, false);
      await NiaproSerializer.saveFolderMembership(
        projectId: work.id,
        folderId: folder.id,
      );

      if (expired) await _ageTrash(const Duration(days: 31));
      final again = ProjectService();
      addTearDown(again.dispose);
      await again.init();
      await again.sweepExpiredTrash(30);
      expect(again.trash, isEmpty);
      expect(again.projects.map((p) => p.name), ['漫画']);
      expect(workOnDisk(work.id), isTrue);
      expect(
        Directory('${storage.projectsPath}/${work.id}/SaveTree').existsSync(),
        isTrue,
      );
      expect(
        again.trashedFolders.map((t) => t.folder.id),
        expired ? isEmpty : [folder.id],
      );
    });
  }

  for (final expired in [false, true]) {
    test(
      'a work restored from a transfer backup into a folder now in Trash, '
      'and its copy, stay out of Trash${expired ? ' and the sweep' : ''}',
      () async {
        final backupDir = Directory.systemTemp.createTempSync('niarim_backup_');
        addTearDown(() => backupDir.deleteSync(recursive: true));
        final (folder, backup) = await _seed((service) async {
          final folder = await service.createFolder('旅行');
          final sea = await _createWork(service, '海');
          await service.moveToFolder(sea.id, folder.id);
          await service.saveProject(sea.id);
          final share = await NiaproSerializer.saveShare(
            project: service.projects.firstWhere((p) => p.id == sea.id),
            scenes: service.scenesOf(sea.id),
            tileManager: service.tileManagerOf(sea.id),
            outputDir: backupDir.path,
          );
          await service.moveFolderToTrash(folder.id);
          return (folder, share.path);
        });
        if (expired) await _ageTrash(const Duration(days: 29));
        final service = ProjectService();
        addTearDown(service.dispose);
        await service.init();
        await service.sweepExpiredTrash(30);
        final imported = await service.importSharedProject(
          await NiaproSerializer.loadShare(backup),
          isSharedImport: false,
        );
        await service.saveProject(imported.id);
        expect(
          await service.duplicateProject(imported.id, name: '海 (コピー)'),
          isTrue,
        );
        final copy = service.projects.firstWhere((p) => p.name == '海 (コピー)');
        await service.saveProject(copy.id);

        if (expired) await _ageTrash(const Duration(days: 31));
        final again = ProjectService();
        addTearDown(again.dispose);
        await again.init();
        await again.sweepExpiredTrash(30);
        expect(
          again.projects.map((p) => p.id),
          unorderedEquals([imported.id, copy.id]),
        );
        expect(again.trash.map((p) => p.name), expired ? isEmpty : ['海']);
        expect(workOnDisk(imported.id), isTrue);
        expect(workOnDisk(copy.id), isTrue);
        expect(
          again.trashedFolderOf(imported.id),
          isNull,
          reason: 'the imported work joined ${folder.name} in Trash',
        );
      },
    );
  }

  test('a received work opened again after its folder went to Trash stays '
      'in the received tab', () async {
    final outDir = Directory.systemTemp.createTempSync('niarim_share_');
    addTearDown(() => outDir.deleteSync(recursive: true));
    final sharePath = await _seed((service) async {
      final folder = await service.createSharedFolder('もらった絵');
      final source = await _createWork(service, '花');
      await service.saveProject(source.id);
      final received = await service.importSharedProject(
        await NiaproSerializer.load(archiveOf(source.id)),
      );
      await service.saveProject(received.id);
      await service.moveToSharedFolder(received.id, folder.id);
      await service.deleteProject(source.id);
      await service.permanentDelete(source.id);
      final share = await NiaproSerializer.saveShare(
        project: service.projects.firstWhere((p) => p.id == received.id),
        scenes: service.scenesOf(received.id),
        tileManager: service.tileManagerOf(received.id),
        outputDir: outDir.path,
      );
      await service.moveFolderToTrash(folder.id, shared: true);
      return share.path;
    });
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    final again = await service.importSharedProject(
      await NiaproSerializer.loadShare(sharePath),
    );
    await service.saveProject(again.id);

    final next = ProjectService();
    addTearDown(next.dispose);
    await next.init();
    expect(next.shared.map((p) => p.id), [again.id]);
    expect(next.trashedFolderOf(again.id), isNull);
    expect(next.trash.map((p) => p.name), ['花']);
  });

  // ゴミ箱から1件ずつ戻した作品は、ゴミ箱の記録を変える前に、作品の保存の
  // フォルダの所属を外しておく（後で書くと、書き終わる前にアプリが終わった
  // とき、次の起動でゴミ箱のフォルダへ入った）。
  test('a work restored on its own leaves its trashed folder on disk before '
      'Trash forgets it', () async {
    final (folder, sea) = await _seed((service) async {
      final folder = await service.createFolder('旅行');
      final sea = await _createWork(service, '海');
      await service.moveToFolder(sea.id, folder.id);
      await service.deleteProject(sea.id);
      await service.moveFolderToTrash(folder.id);
      return (folder, sea);
    });
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    await service.restoreProject(sea.id);
    // restoreProjectから戻った時点でアプリが終わった。
    final snapshot = File(archiveOf(sea.id)).readAsBytesSync();
    expect(
      (await NiaproSerializer.load(archiveOf(sea.id))).project.folderId,
      isNull,
    );
    await service.saveProject(sea.id);
    File(archiveOf(sea.id)).writeAsBytesSync(snapshot);

    final again = ProjectService();
    addTearDown(again.dispose);
    await again.init();
    expect(again.trash, isEmpty);
    expect(again.projects.map((p) => (p.name, p.folderId)), [('海', null)]);
    expect(again.trashedFolders.single.folder.id, folder.id);
    expect(again.trashedFolders.single.projectIds, isEmpty);
  });

  // 「再試行」とフォルダをゴミ箱へ移すことが重なっても、読めた作品は
  // この起動のうちからゴミ箱のそのフォルダに入る（一番上に出て、次の起動で
  // ゴミ箱へ移っていた）。
  test('Retry racing a folder move to Trash puts the work read late in the '
      'folder in Trash in this session', () async {
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
    storage.paths.blockReading(archiveOf(works[1].id));
    final service = ProjectService();
    addTearDown(service.dispose);
    await service.init();
    storage.paths.clear();
    final retry = service.retryLoadProjects();
    final move = service.moveFolderToTrash(folder.id);
    await Future.wait([retry, move]);
    void expectInTrash(ProjectService projects) {
      expect(projects.projects, isEmpty);
      for (final work in works) {
        expect(projects.trashedFolderOf(work.id)?.folder.id, folder.id);
      }
    }

    expectInTrash(service);
    final again = ProjectService();
    addTearDown(again.dispose);
    await again.init();
    expectInTrash(again);
  });

  // 容量削減の「ゴミ箱を空にする」：ゴミ箱に読めていない作品を含むフォルダ
  // しか無いときは、何も並ばない確かめるダイアログを出さず（「削除」を
  // 押しても黙って閉じ、何も消えなかった）、読み込めていないことを知らせる。
  testWidgets('Empty trash in storage says the works could not be read when '
      'only held folders are in Trash', (tester) async {
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
      () => _seedTrashedFolder('旅行', ['海', '山']),
    );
    final (folder, works) = seeded!;
    storage.paths.blockReading(archiveOf(works[1].id));
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
    await tester.ensureVisible(emptyTrash);
    await tester.tap(emptyTrash);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.byKey(const Key('trash-dialog-confirm')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('プロジェクトを読み込めませんでした'),
      ),
      findsOneWidget,
    );
    final projects = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);
    expect(works.every((w) => workOnDisk(w.id)), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });

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

  // ホーム：作品を読めていない間も、フォルダを選んで（︙のメニュー
  // からも）ゴミ箱へ移せる（以前は「プロジェクトを読み込めません
  // でした」で断った）。「再試行」で読めた中の作品は、プロジェクトの
  // 一番上ではなく、ゴミ箱のそのフォルダに入る。
  testWidgets('Home moves folders to Trash while a work could not be read, '
      'and Retry puts the work in its folder in Trash', (tester) async {
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
        final empty = await service.createFolder('空のフォルダ');
        final works = <Project>[];
        for (final name in ['海', '山']) {
          final work = await _createWork(service, name);
          await service.moveToFolder(work.id, folder.id);
          works.add(work);
        }
        await _createWork(service, '関係のない作品');
        return (folder, empty, works);
      }),
    );
    final (folder, empty, works) = seeded!;
    storage.paths.blockReading(
      '${storage.projectsPath}/${works[1].id}/${works[1].id}.niapro',
    );
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    final projects = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    final notice = find.byKey(const Key('homeProjectsLoadFailed'));
    expect(notice, findsOneWidget);

    // 選んでゴミ箱へ移す（確かめるダイアログ）。
    await tester.longPress(find.text('旅行').first);
    await _settleWithFiles(tester, rounds: 3);
    await tester.tap(find.byTooltip('ゴミ箱へ移動').first);
    await _settleWithFiles(tester, rounds: 4);
    // フォルダの中の件数は、読めた作品の分しか数えられない。読み込めて
    // いないことを、確かめるダイアログの中でも伝える。
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('プロジェクトを読み込めませんでした'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('trash-dialog-confirm')));
    await _settleWithFiles(tester);
    expect(find.byKey(const Key('trash-dialog-error')), findsNothing);
    expect(find.byKey(const Key('trash-dialog-confirm')), findsNothing);
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);

    // フォルダの︙のメニューからゴミ箱へ移す（フォルダのダイアログ）。
    final emptyCard = find
        .ancestor(
          of: find.text('空のフォルダ').first,
          matching: find.byWidgetPredicate((w) => w is Card || w is ListTile),
        )
        .first;
    await tester.tap(
      find.descendant(of: emptyCard, matching: find.byIcon(Icons.more_vert)),
    );
    await _settleWithFiles(tester, rounds: 6);
    await tester.tap(find.text('ゴミ箱へ移動').last);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.byType(FolderDeleteDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(FolderDeleteDialog),
        matching: find.widgetWithText(FilledButton, 'ゴミ箱へ移動'),
      ),
    );
    await _settleWithFiles(tester);
    expect(find.byType(FolderDeleteDialog), findsNothing);
    expect(
      projects.trashedFolders.map((t) => t.folder.id),
      unorderedEquals([folder.id, empty.id]),
    );
    expect(projects.folders, isEmpty);

    // 読めるようになって「再試行」：「山」は一番上ではなく、ゴミ箱の
    // 「旅行」に入る。
    storage.paths.clear();
    await tester.tap(find.descendant(of: notice, matching: find.text('再試行')));
    for (var i = 0; i < 40 && projects.projectsLoadFailed; i++) {
      await _settleWithFiles(tester, rounds: 1);
    }
    await _settleWithFiles(tester, rounds: 3);
    expect(projects.projectsLoadFailed, isFalse);
    expect(notice, findsNothing);
    expect(find.text('関係のない作品'), findsOneWidget);
    expect(find.text('山'), findsNothing, reason: '山 left its folder');
    expect(projects.trashedFolderOf(works[1].id)?.folder.id, folder.id);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await _settleWithFiles(tester);
    // ゴミ箱の「旅行」の行に、2つとも出る。
    final row = find.byKey(ValueKey('trashedFolder_${folder.id}'));
    expect(
      find.descendant(of: row, matching: find.text('海、山')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 作品を読めていない間にゴミ箱へ移したフォルダの行は、読めた作品の名前
  // （「海、花」）だけを出して理由を言わず、「完全削除」を押せ、容量削減の
  // 「ゴミ箱を空にする」も消すものに並べた。押すと読めた作品だけが完全に
  // 削除され、読めていなかった作品は後でプロジェクトの一番上に1つだけ
  // 出た。読めるまで、中の作品が読めていないフォルダと同じく残す：行は
  // 記録の件数と理由を出し、「完全削除」は押せず、「復元」「コピー」は
  // 押せる。容量削減では消すものに並べない。「再試行」で読めたら作品は
  // フォルダへ入り、「完全削除」も押せる。
  testWidgets('a folder moved to Trash while a work was unread is held on its '
      'trash row and in Empty trash until Retry reads the work', (
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
    final seeded = await tester.runAsync(
      () => _seed((service) async {
        final folder = await service.createFolder('旅行');
        final sub = await service.createFolder('写真', parentFolderId: folder.id);
        final sea = await _createWork(service, '海');
        await service.moveToFolder(sea.id, folder.id);
        final flower = await _createWork(service, '花');
        await service.moveToFolder(flower.id, sub.id);
        final mountain = await _createWork(service, '山');
        await service.moveToFolder(mountain.id, folder.id);
        return (folder, [sea, flower, mountain]);
      }),
    );
    final (folder, works) = seeded!;
    final mountain = works[2];
    bool onDisk(Project p) =>
        Directory('${storage.projectsPath}/${p.id}').existsSync();
    storage.paths.blockReading(
      '${storage.projectsPath}/${mountain.id}/${mountain.id}.niapro',
    );
    StorageInfoService().invalidate();
    addTearDown(StorageInfoService().invalidate);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    final projects = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    await tester.runAsync(() => projects.moveFolderToTrash(folder.id));
    await _settleWithFiles(tester, rounds: 3);
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);
    await tester.tap(find.byKey(const ValueKey('home_tab_3')));
    await _settleWithFiles(tester);

    final row = find.byKey(ValueKey('trashedFolder_${folder.id}'));
    final restore = find.byKey(ValueKey('trashedFolderRestore_${folder.id}'));
    final delete = find.byKey(ValueKey('trashedFolderDelete_${folder.id}'));
    final copy = find.byKey(ValueKey('trashCopyFolder_${folder.id}'));
    expect(row, findsOneWidget);
    expect(
      tester.widget<TextButton>(delete).onPressed,
      isNull,
      reason: 'the read works can be deleted while 山 is unread',
    );
    expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
    expect(tester.widget<TextButton>(copy).onPressed, isNotNull);
    // 中身は読めた作品の名前ではなく記録の件数で、押せない理由も行の中に。
    expect(
      find.descendant(of: row, matching: find.textContaining('海')),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('プロジェクト2件')),
      findsOneWidget,
    );
    final reason = find.descendant(
      of: row,
      matching: find.textContaining('プロジェクトを読み込めませんでした'),
    );
    expect(reason, findsOneWidget, reason: 'the row does not say why');
    await tester.tap(delete, warnIfMissed: false);
    await _settleWithFiles(tester, rounds: 3);
    expect(find.byType(AlertDialog), findsNothing);
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);

    // 容量削減の「ゴミ箱を空にする」：残すフォルダしか無いので、確かめる
    // ダイアログを出さずに読み込めていないことを知らせ、何も消さない。
    appRouter.push('/storage');
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
    await tester.ensureVisible(emptyTrash);
    await tester.tap(emptyTrash);
    await _settleWithFiles(tester, rounds: 3);
    expect(
      find.byKey(const Key('trash-dialog-confirm')),
      findsNothing,
      reason: 'Empty trash lists the held folder as deleted',
    );
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('プロジェクトを読み込めませんでした'),
      ),
      findsOneWidget,
    );
    expect(projects.trashedFolders.map((t) => t.folder.id), [folder.id]);
    expect(works.every(onDisk), isTrue);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).last),
    ).removeCurrentSnackBar();
    appRouter.pop();
    await _settleWithFiles(tester, rounds: 4);

    // 読めるようになって「再試行」：山はゴミ箱の「旅行」に入り（一番上には
    // 出ない）、残すのは終わる。
    storage.paths.clear();
    final notice = find.byKey(const Key('trashProjectsLoadFailed'));
    await tester.tap(find.descendant(of: notice, matching: find.text('再試行')));
    for (var i = 0; i < 40 && projects.projectsLoadFailed; i++) {
      await _settleWithFiles(tester, rounds: 1);
    }
    await _settleWithFiles(tester, rounds: 3);
    expect(projects.projectsLoadFailed, isFalse);
    expect(projects.trashedFolderOf(mountain.id)?.folder.id, folder.id);
    expect(projects.projects, isEmpty, reason: '山 came out at the top');
    expect(tester.widget<TextButton>(delete).onPressed, isNotNull);
    expect(reason, findsNothing);
    // 中の作品の名前が並ぶ（並び順は保存先の一覧の順）。
    final names = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('、') ?? false),
      ),
    );
    expect(
      tester.widget<Text>(names).data!.split('、'),
      unorderedEquals(['海', '花', '山']),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });

  // フォルダのダイアログ（右クリック・︙のメニュー）・貼り付けの失敗の文：
  // 読めていない作品のために断ったときは、「保存できませんでした。もう
  // 一度」ではなく、読み込めていないことを伝える。
  test('folder failures say the works could not be read when that is the '
      'reason', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(
      folderSaveFailureText(l10n, const TrashedFolderUnreadException()),
      'プロジェクトを読み込めませんでした',
    );
    expect(
      folderSaveFailureText(
        l10n,
        const FolderSaveException(partiallySaved: false),
      ),
      l10n.folderChangesSaveFailed,
    );
  });

  // 容量削減の「ゴミ箱を空にする」：一部の作品だけ読めないとき、読めた
  // ものは消し、読めていない作品を含むフォルダは中の読めた作品ごと残す
  // （以前は記録だけが消え、フォルダの読めた作品も1件ずつ消えた）。残す
  // フォルダは、消すものとして確かめるダイアログに並べない（並べてから
  // 「読み込めませんでした」で失敗していた）。
  testWidgets('Empty trash in storage keeps a folder that holds an unread '
      'work and does not list it as deleted', (tester) async {
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
    expect(
      find.text('旅行'),
      findsNothing,
      reason: 'a folder that is kept is listed as deleted',
    );
    expect(find.text('読めたフォルダ'), findsOneWidget);
    expect(find.text('ばらの作品'), findsOneWidget);
    // 残すフォルダがあることを、ダイアログの中で伝える。
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('プロジェクトを読み込めませんでした'),
      ),
      findsOneWidget,
    );
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
    // 並べたものは消し終えたので、ダイアログは失敗と言わずに閉じる。
    expect(find.byKey(const Key('trash-dialog-error')), findsNothing);
    expect(find.byKey(const Key('trash-dialog-confirm')), findsNothing);
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

  // 起動画面ウィジェットの作品選び（設定）も、作品を読み込めなかった間に
  // 「まだ作品がありません。作品を作るとここで選べるようになります。」だけを
  // 出していた（ホームのプロジェクトと同じ。知らせも「再試行」も無い）。
  // 読み込めなかったことを知らせて読み直せるようにし、一部だけ読めたときは
  // 読めた作品を知らせと一緒に並べる。
  for (final partial in [false, true]) {
    testWidgets('the widget artwork picker does not say there are no works '
        'while they could not be read, and Retry lists them '
        '(${partial ? 'one work unreadable' : 'folder unlistable'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final l10n = lookupAppLocalizations(const Locale('ja'));
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
      if (partial) {
        storage.paths.blockReading(
          '${storage.projectsPath}/${unread.id}/${unread.id}.niapro',
        );
      } else {
        storage.paths.blockListing(storage.projectsPath);
      }
      appRouter.go('/settings/widget/artwork');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await _settleWithFiles(tester);
      final projects = tester
          .element(find.byType(Scaffold).first)
          .read<ProjectService>();
      expect(projects.projectsLoadFailed, isTrue);
      final notice = find.byKey(const Key('widgetArtworkProjectsLoadFailed'));
      final retry = find.descendant(
        of: notice,
        matching: find.text(l10n.communityRetry),
      );
      for (final size in const [Size(320, 568), Size(1280, 800)]) {
        for (final scale in [1.0, 2.0]) {
          final where = '${size.width.toInt()}px x$scale';
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await _settleWithFiles(tester, rounds: 3);
          expect(
            find.text(l10n.widgetNoProjects),
            findsNothing,
            reason: '$where: said there are no works',
          );
          expect(notice, findsOneWidget, reason: where);
          expect(
            find.descendant(
              of: notice,
              matching: find.text(l10n.homeProjectsLoadFailed),
            ),
            findsOneWidget,
            reason: where,
          );
          expect(find.text('読めた作品'), partial ? findsOneWidget : findsNothing);
          expect(find.text('開けない作品'), findsNothing, reason: where);
          expect(tester.takeException(), isNull, reason: where);
        }
      }

      // 読めるようになって「再試行」：知らせが消え、2作品とも選べる。
      tester.view.physicalSize = const Size(1280, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await _settleWithFiles(tester, rounds: 3);
      storage.paths.clear();
      await tester.tap(retry);
      for (var i = 0; i < 40 && notice.evaluate().isNotEmpty; i++) {
        await _settleWithFiles(tester, rounds: 2);
      }
      expect(notice, findsNothing);
      expect(find.text('読めた作品'), findsOneWidget);
      expect(find.text('開けない作品'), findsOneWidget);
      expect(find.text(l10n.widgetNoProjects), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 作品が本当に1つも無いときは、これまでどおり作品が無いと伝える。
  testWidgets('the widget artwork picker still says there are no works when '
      'the folder was read and is empty', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final l10n = lookupAppLocalizations(const Locale('ja'));
    Directory(storage.projectsPath).createSync(recursive: true);
    appRouter.go('/settings/widget/artwork');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await _settleWithFiles(tester);
    expect(find.text(l10n.widgetNoProjects), findsOneWidget);
    expect(
      find.byKey(const Key('widgetArtworkProjectsLoadFailed')),
      findsNothing,
    );
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

/// ゴミ箱へ移した日時（フォルダの記録と作品）をすべて[age]前にする
/// （起動と起動の間に日がたった）。
Future<void> _ageTrash(Duration age) async {
  final prefs = await SharedPreferences.getInstance();
  final when = DateTime.now().subtract(age).toIso8601String();
  final folders = prefs.getString('trashed_project_folders');
  if (folders != null) {
    await prefs.setString(
      'trashed_project_folders',
      jsonEncode([
        for (final record in jsonDecode(folders) as List<dynamic>)
          {...record as Map<String, dynamic>, 'deletedAt': when},
      ]),
    );
  }
  await prefs.setStringList('trashed_projects', [
    for (final entry in prefs.getStringList('trashed_projects') ?? const [])
      '${entry.substring(0, entry.indexOf('|'))}|$when',
  ]);
}

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
