// レイヤーの貼り付けの名前と、コマを替えたときに選ぶレイヤー（所有者の判断、
// 2026-11-27、全部入りの作品づくりの判断カードJ2・J3）。
//
// * 同じ名前のレイヤーがあるコマへ貼り付けると、同じ名前が2つ並んで見分け
//   られなかった。名前が重なるときだけ「（コピー）」を付ける。
// * 今のレイヤーの無いコマへ移ると、いつも一番上のレイヤーが選ばれ、上の
//   不透明なレイヤーの下へ描いていた。前のコマと同じ並びの位置のレイヤーを
//   選ぶ。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/layer_clipboard_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/duplicate_name.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  test(
    'a pasted layer is marked as a copy only when its name is taken',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ps = ProjectService();
      await ps.init();
      ps.setUndoManager(UndoManager());
      final p = await ps.createProject(
        name: 'paste names',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 32,
        exportHeight: 32,
      );
      final scene = ps.scenesOf(p.id).first.id;
      final ink = ps.addLayer(
        projectId: p.id,
        sceneId: scene,
        frameIndex: 0,
        type: LayerType.normal,
        name: 'Ink',
      );
      final clipboard = LayerClipboardService.instance;
      addTearDown(clipboard.clear);
      expect(
        await clipboard.copy(
          projectService: ps,
          projectId: p.id,
          sceneId: scene,
          frameIndex: 0,
          layerId: ink.id,
        ),
        isTrue,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
      String copyName(String name, Set<String> taken) =>
          numberedCopyName(l10n, name, taken);

      Layer paste(int frame) => clipboard.pasteBefore(
        projectService: ps,
        projectId: p.id,
        targetSceneId: scene,
        targetFrameIndex: frame,
        beforeLayerId: ps.layersOf(p.id, scene, frame).first.id,
        copyName: copyName,
      )!;

      // The other frame has no "Ink": the name stays.
      expect(paste(1).name, 'Ink');
      // This frame has: the copy is told apart, and the next one too.
      final first = paste(0).name;
      expect(first, numberedCopyName(l10n, 'Ink', {'Ink'}));
      final second = paste(0).name;
      expect(second, isNot(first));
      expect(second, isNot('Ink'));
      final names = [for (final l in ps.layersOf(p.id, scene, 0)) l.name];
      expect(names.toSet(), hasLength(names.length));
    },
  );

  testWidgets('a frame without the current layer picks the same place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
      'default_docked_panels': ['layer'],
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 350));
    final ps = tester.element(find.byType(MaterialApp)).read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'same place',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 48,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first.id;
    for (final frame in [0, 1]) {
      for (final name in ['Colour $frame', 'Line $frame']) {
        ps.addLayer(
          projectId: project.id,
          sceneId: scene,
          frameIndex: frame,
          type: LayerType.normal,
          name: name,
        );
      }
    }
    await tester.runAsync(() => ps.saveProject(project.id));

    appRouter.go('/canvas/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 450));
    CanvasArea area() => tester.widget<CanvasArea>(find.byType(CanvasArea));
    int place(int frame) => ps
        .layersOf(project.id, scene, frame)
        .indexWhere((l) => l.id == area().currentLayerId);

    // The second layer from the top ("Colour 0", under "Line 0").
    final colour = find.descendant(
      of: find.byType(LayerPanel),
      matching: find.text('Colour 0'),
    );
    await tester.tap(colour);
    await tester.pumpAndSettle();
    expect(place(0), 1);

    await tester.tap(find.byKey(const ValueKey('frameStripCell1')));
    await tester.pumpAndSettle();
    expect(area().currentFrame, 1);
    expect(place(1), 1);
    expect(
      ps.layersOf(project.id, scene, 1)[1].name,
      'Colour 1',
      reason: 'the layer at the same place, not the top one',
    );
    expect(tester.takeException(), isNull);
  });
}
