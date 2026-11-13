import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 手動の保存（セーブスロット・セーブツリー）の一覧は、起動し直しても
/// 残ること。以前は一覧をメモリにしか持たず、保存のファイルは残るのに
/// 起動し直すとどのスロットも「保存データなし」になり、戻せなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('niarim_save_tree_persist_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<(ProjectService, Project)> project() async {
    final ps = ProjectService();
    await ps.init();
    final p = await ps.createProject(
      name: 'persist',
      fps: 2,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 36,
    );
    return (ps, p);
  }

  Future<SaveNode> slot(
    SaveTreeService service,
    ProjectService ps,
    Project p,
    int index, {
    String? comment,
  }) => service.saveToSlot(
    projectId: p.id,
    slotIndex: index,
    project: p,
    scenes: ps.scenesOf(p.id),
    tileManager: ps.tileManagerOf(p.id),
    comment: comment,
  );

  // 起動し直したときと同じく、新しいサービスで読み込む。
  Future<SaveTreeService> restart({bool tree = false, int slots = 5}) async {
    final service = SaveTreeService()
      ..setSlotMax(slots)
      ..setTreeMode(tree);
    await service.init();
    return service;
  }

  File index(Project p) =>
      File('${tempDir.path}/niarim/projects/${p.id}/SaveTree/index.json');

  test('slot saves, comments and deletions survive a restart', () async {
    final (ps, p) = await project();
    final service = SaveTreeService()..setSlotMax(5);
    final kept = await slot(service, ps, p, 2, comment: '線画まで');
    final removed = await slot(service, ps, p, 0, comment: '消す');
    await service.deleteNode(p.id, removed.id);

    final again = await restart();
    final nodes = again.getNodes(p.id);
    expect(nodes.map((n) => n.id), [kept.id]);
    expect(nodes.single.comment, '線画まで');
    expect(nodes.single.slotIndex, 2);
    expect(nodes.single.savedAt, kept.savedAt);
    expect(await again.loadNode(p.id, kept.id), isNotNull);
  });

  test(
    'empty slot memos persist without save files and survive overwrite/delete',
    () async {
      final (ps, p) = await project();
      final service = SaveTreeService()..setSlotMax(5);
      expect(service.getNodes(p.id), isEmpty);
      expect(await service.setSlotMemo(p.id, 1, 'ラフ用'), isTrue);
      expect(await service.setSlotMemo(p.id, 3, '塗り前'), isTrue);
      expect(service.slotMemoOf(p.id, 1), 'ラフ用');
      expect(index(p).existsSync(), isTrue);

      // A metadata-only index must be loaded even when no .niapro exists.
      final restartedEmpty = await restart();
      expect(restartedEmpty.getNodes(p.id), isEmpty);
      expect(restartedEmpty.slotDisplayMemoOf(p.id, 1), 'ラフ用');
      expect(restartedEmpty.slotDisplayMemoOf(p.id, 3), '塗り前');

      final first = await slot(service, ps, p, 1, comment: '保存1');
      expect(service.slotMemoOf(p.id, 1), 'ラフ用');
      final second = await slot(service, ps, p, 1, comment: '保存2');
      expect(second.id, isNot(first.id));
      expect(service.slotMemoOf(p.id, 1), 'ラフ用');
      await service.deleteNode(p.id, second.id);
      expect(service.getNodes(p.id), isEmpty);
      expect(service.slotMemoOf(p.id, 1), 'ラフ用');

      final reloaded = await restart();
      expect(reloaded.getNodes(p.id), isEmpty);
      expect(reloaded.slotMemoOf(p.id, 1), 'ラフ用');
      expect(reloaded.slotMemoOf(p.id, 3), '塗り前');
      expect(await reloaded.setSlotMemo(p.id, 1, ''), isTrue);
      final cleared = await restart();
      expect(cleared.slotMemoOf(p.id, 1), '');
      expect(cleared.slotMemoOf(p.id, 3), '塗り前');
    },
  );

  test('tree saves keep their parent after a restart', () async {
    final (ps, p) = await project();
    final service = SaveTreeService()..setTreeMode(true);
    final root = await service.saveAsChild(
      projectId: p.id,
      project: p,
      scenes: ps.scenesOf(p.id),
      tileManager: ps.tileManagerOf(p.id),
      comment: '下書き',
    );
    final child = await service.saveAsChild(
      projectId: p.id,
      project: p,
      scenes: ps.scenesOf(p.id),
      tileManager: ps.tileManagerOf(p.id),
      parentId: root.id,
    );

    final again = await restart(tree: true);
    expect(again.getChildren(p.id, null).map((n) => n.id), [root.id]);
    expect(again.getChildren(p.id, root.id).map((n) => n.id), [child.id]);
    expect(
      again.getNodes(p.id).firstWhere((n) => n.id == root.id).comment,
      '下書き',
    );
  });

  test(
    'saves without a list come back into free slots, oldest first',
    () async {
      final (ps, p) = await project();
      final service = SaveTreeService()..setSlotMax(2);
      final listed = await slot(service, ps, p, 0, comment: '一覧あり');
      final older = await slot(service, ps, p, 1);
      // 以前の版の保存：一覧に載っていないファイルだけがある。
      final orphanA = File(
        '${tempDir.path}/niarim/projects/${p.id}/SaveTree/save_1000_0.niapro',
      );
      final orphanB = File(
        '${tempDir.path}/niarim/projects/${p.id}/SaveTree/save_2000_0.niapro',
      );
      final data = File(
        '${tempDir.path}/niarim/projects/${p.id}/SaveTree/${older.id}.niapro',
      );
      data.copySync(orphanA.path);
      data.copySync(orphanB.path);
      // 一覧には slot 0 だけが載っている状態にする。
      await service.deleteNode(p.id, older.id);

      final again = await restart(slots: 2);
      final nodes = again.getNodes(p.id);
      expect(
        {for (final n in nodes) n.slotIndex: n.id},
        {0: listed.id, 1: 'save_1000_0'},
      );
      expect(
        nodes.firstWhere((n) => n.id == 'save_1000_0').savedAt,
        DateTime.fromMillisecondsSinceEpoch(1000),
      );
      // 入りきらない分は消さずに退避する（ツリー方式にすると出る）。
      expect(again.getArchivedNodes(p.id).map((n) => n.id), ['save_2000_0']);
      // 拾い直した結果は一覧へ書かれる。
      expect(index(p).readAsStringSync(), contains('save_2000_0'));
    },
  );

  test(
    'a broken list does not stop the start and the saves come back',
    () async {
      final (ps, p) = await project();
      final service = SaveTreeService()..setSlotMax(5);
      final saved = await slot(service, ps, p, 3, comment: 'こわれる前');
      index(p).writeAsStringSync('{not json');

      final again = await restart();
      expect(again.getNodes(p.id).map((n) => n.id), [saved.id]);
    },
  );

  test('list entries whose data is gone are not shown', () async {
    final (ps, p) = await project();
    final service = SaveTreeService()..setSlotMax(5);
    final saved = await slot(service, ps, p, 1);
    File('${tempDir.path}/niarim/projects/${p.id}/SaveTree/${saved.id}.niapro')
        .deleteSync();

    final again = await restart();
    expect(again.getNodes(p.id), isEmpty);
  });
}
