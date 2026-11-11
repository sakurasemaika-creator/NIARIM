import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('More than 200 nodes across long chains, siblings and roots '
      'remain scrollable on a narrow phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('niarim_tree_stress_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1)))!;
      final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png)))!;
      image.dispose();
      final output = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      await tester.runAsync(() async =>
          File('${output.path}/$name.png')
              .writeAsBytes(data.buffer.asUint8List()));
    }

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(
          providers: providers!,
          child: const NiarimApp(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final saves = context.read<SaveTreeService>();
    saves.setTreeMode(true);
    final project = await tester.runAsync(() => ps.createProject(
      name: 'Tree stress test',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 64,
      exportHeight: 64,
    ));
    expect(project, isNotNull);
    final pid = project!.id;
    final base = await tester.runAsync(NiaproSerializer.projectsBasePath);
    final folder = Directory('$base/$pid/SaveTree')
      ..createSync(recursive: true);
    final allNodes = <SaveNode>[];
    final now = DateTime.utc(2026, 11, 11);

    void addNode(String id, String? parentId) {
      allNodes.add(SaveNode(
        id: id,
        projectId: pid,
        savedAt: now.add(Duration(seconds: allNodes.length)),
        parentId: parentId,
        comment: id,
      ));
    }

    // Deep chain exceeds a phone's logical width when each level has 24px
    // indentation. Broad side branches stress connector continuation.
    String? parent;
    for (var i = 0; i < 64; i++) {
      final id = 'chain_$i';
      addNode(id, parent);
      parent = id;
      for (var j = 0; j < 3; j++) {
        if (i.isEven) addNode('side_${i}_$j', id);
      }
    }
    for (var root = 0; root < 16; root++) {
      final rootId = 'root_$root';
      addNode(rootId, null);
      for (var child = 0; child < 6; child++) {
        addNode('branch_${root}_$child', rootId);
      }
    }
    expect(allNodes.length, greaterThan(200));

    // Metadata is sufficient for rendering; the archive loader checks only
    // file presence and never decodes these placeholder blobs.
    await tester.runAsync(() async {
      for (final node in allNodes) {
        File('${folder.path}/${node.id}.niapro')
            .writeAsBytesSync([0], flush: false);
      }
      File('${folder.path}/index.json').writeAsStringSync(jsonEncode({
        'nodes': allNodes.map((n) => n.toJson()).toList(),
        'archived': <Object>[],
        'slotMemos': <String, String>{},
      }), flush: true);
      await saves.loadUnread();
    });
    expect(saves.getNodes(pid).length, allNodes.length);

    appRouter.go('/save-tree/$pid');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    final scrolling = find.byKey(const Key('saveTreeHorizontalScroll'));
    expect(scrolling, findsOneWidget);
    expect(tester.widget<SingleChildScrollView>(scrolling).scrollDirection,
        Axis.horizontal);
    final lazy = tester.widgetList<ListView>(
        find.byType(ListView, skipOffstage: false)).where(
            (list) => list.childrenDelegate is SliverChildBuilderDelegate);
    expect(
      lazy.map((list) => list.childrenDelegate.estimatedChildCount),
      contains(allNodes.length),
    );
    expect(find.text('chain_0'), findsOneWidget);
    await capture('tree_01_256_nodes_root_and_siblings');
    await tester.drag(scrolling, const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // Scroll several pages upward in the 256-node history.
    for (var i = 0; i < 6; i++) {
      // The wide tree ListView's center is off-screen horizontally. Start
      // the gesture from an actual visible point inside the viewport.
      await tester.dragFrom(
        const Offset(180, 400),
        const Offset(0, 300),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    await capture('tree_02_256_nodes_vertical_and_horizontal_scroll');
  });
}
