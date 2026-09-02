// セーブツリー一覧が行ウィジェットを遅延生成することを検証する。
//
// 以前は ListView(children: ...) に全ノード分の行を詰めていた。
// SliverChildListDelegateはElementの生成自体は遅延させるので画面外の行が
// 実際に描画されるわけではないが、**行のWidgetオブジェクトは毎回のbuildで
// ノード数ぶん作られる**（ListTile・Checkbox・三点メニュー・接続線の
// CustomPaint・Image.fileの記述子一式）。セーブが増えるほど、保存や
// チェックの付け外しのたびに捨てるだけのウィジェットを大量に作ることに
// なるため、ListView.builderへ移した。
//
// この差はElement数では観測できない（どちらも画面内ぶんしかmountしない）
// ので、ListViewのdelegate種別＝「builder方式であること」そのものを
// 不変条件として押さえる。併せて、親子インデックス化で表示順が変わって
// いないことも確認する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('niarim_savetree_lazy');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  testWidgets('ツリー方式のセーブ一覧は行をbuilderで遅延生成する',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final ctx = tester.element(find.byType(Navigator).first);
    final ps = ctx.read<ProjectService>();
    final sts = ctx.read<SaveTreeService>();
    sts.setTreeMode(true);

    final project = await tester.runAsync(() => ps.createProject(
          name: 'lazy',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 64,
        ));
    final pid = project!.id;

    // 1本の長い枝としてノードを積む（深い木ほど行数が増える構造）。
    const nodeCount = 40;
    await tester.runAsync(() async {
      String? parentId;
      for (var i = 0; i < nodeCount; i++) {
        final node = await sts.saveAsChild(
          projectId: pid,
          project: project,
          scenes: ps.scenesOf(pid),
          tileManager: ps.tileManagerOf(pid),
          parentId: parentId,
          comment: '保存$i',
        );
        parentId = node.id;
      }
    });
    expect(sts.getNodes(pid).length, nodeCount);

    appRouter.go('/save-tree/$pid');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 行の生成方式がbuilderであること。ListView(children:)へ戻すと
    // delegateがSliverChildListDelegateになり、ここで落ちる。
    final delegates = tester
        .widgetList<ListView>(find.byType(ListView, skipOffstage: false))
        .map((v) => v.childrenDelegate)
        .toList();
    expect(delegates, isNotEmpty, reason: 'セーブ一覧のListViewが見つからない');
    expect(
      delegates.whereType<SliverChildBuilderDelegate>().map((d) => d.childCount),
      contains(nodeCount),
      reason: '全ノードぶんの行ウィジェットを毎buildで作る実装に戻っている'
          '（builder方式で$nodeCount行を持つListViewが無い）',
    );

    // 実際に描画されるのは画面に入る分だけであること。
    final tiles = find.byType(ListTile, skipOffstage: false).evaluate().length;
    expect(tiles, greaterThan(0), reason: '1行も描画されていない');
    expect(tiles, lessThan(nodeCount), reason: '全件がmountされている');

    // 末尾（reverse:trueなので画面下＝最初の保存）が見えていること。
    expect(find.text('保存0'), findsOneWidget);
  });

  testWidgets('親子インデックスは表示順を変えない（rootが下・子孫が上）',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('niarim_savetree_order');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );

    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final ctx = tester.element(find.byType(Navigator).first);
    final ps = ctx.read<ProjectService>();
    final sts = ctx.read<SaveTreeService>();
    sts.setTreeMode(true);

    final project = await tester.runAsync(() => ps.createProject(
          name: 'order',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 64,
        ));
    final pid = project!.id;

    late SaveNode root;
    await tester.runAsync(() async {
      root = await sts.saveAsChild(
        projectId: pid,
        project: project,
        scenes: ps.scenesOf(pid),
        tileManager: ps.tileManagerOf(pid),
        comment: 'root',
      );
      await sts.saveAsChild(
        projectId: pid,
        project: project,
        scenes: ps.scenesOf(pid),
        tileManager: ps.tileManagerOf(pid),
        parentId: root.id,
        comment: 'childA',
      );
      await sts.saveAsChild(
        projectId: pid,
        project: project,
        scenes: ps.scenesOf(pid),
        tileManager: ps.tileManagerOf(pid),
        parentId: root.id,
        comment: 'childB',
      );
    });

    appRouter.go('/save-tree/$pid');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // reverse:true なので、DFS順の先頭（root）ほど画面下に来る。
    double top(String label) =>
        tester.getTopLeft(find.text(label).first).dy;
    expect(top('root'), greaterThan(top('childA')));
    expect(top('childA'), greaterThan(top('childB')));
  });
}
