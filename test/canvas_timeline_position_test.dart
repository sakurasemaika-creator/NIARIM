import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  testWidgets('canvas and timeline retain the active scene and frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final projects = tester
        .element(find.byType(MaterialApp))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'Scene navigation',
        fps: 6,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 48,
      ),
    ))!;
    final first = projects.scenesOf(project.id).first.id;
    const secondName = 'Second scene';
    final second = (await tester.runAsync(() async {
      final second = projects.addScene(project.id);
      projects.renameScene(project.id, second.id, secondName);
      for (var i = 0; i < 4; i++) {
        projects.addFrame(project.id, second.id);
      }
      for (final (sceneId, clipId) in [
        (first, 'first'),
        (second.id, 'second'),
      ]) {
        projects.addAudioClip(
          project.id,
          sceneId,
          AudioClip(id: clipId, label: clipId, startFrame: 0, lengthFrames: 2),
        );
      }
      await projects.saveProject(project.id);
      return second.id;
    }))!;

    appRouter.go('/canvas/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 450));
    final canvas = find.byType(CanvasArea);
    CanvasArea area() => tester.widget<CanvasArea>(canvas);
    final palette = find.byType(LayerPanel);
    void expectPaletteCurrent() {
      final panel = tester.widget<LayerPanel>(palette);
      expect(panel.sceneId, area().sceneId);
      expect(panel.frameIndex, area().currentFrame);
      expect(panel.currentLayerId, area().currentLayerId);
    }

    final l10n = AppLocalizations.of(tester.element(canvas))!;
    expect(area().sceneId, first);
    expect(area().currentFrame, 0);
    expectPaletteCurrent();

    final fourth = find.byKey(const ValueKey('frameStripCell3'));
    await tester.tap(fourth);
    await tester.pumpAndSettle();
    expect(area().currentFrame, 3);
    expectPaletteCurrent();
    await tester.tap(find.byTooltip(l10n.canvasTimelineModeTooltip));
    await pumpRealAsync(tester, const Duration(milliseconds: 450));

    final counter = find.byKey(const Key('timelinePreviewFrameCount'));
    expect(tester.widget<Text>(counter).data, '4/6');
    final firstAudio = find.byKey(const Key('timelineClip-first'));
    final secondAudio = find.byKey(const Key('timelineClip-second'));
    expect(firstAudio, findsOneWidget);
    expect(secondAudio, findsNothing);
    // PCのシーン一覧にも同じ名前があるため、タイムライン上の
    // 選択チップだけを押す（文言だけでは2件見つかる）。
    final secondScene = find.descendant(
      of: find.byType(ChoiceChip),
      matching: find.text(secondName),
    );
    expect(secondScene, findsOneWidget);
    await tester.tap(secondScene);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(secondScene);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(counter).data, '1/5');
    expect(firstAudio, findsNothing);
    expect(secondAudio, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timelineFrameCell1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(counter).data, '2/5');

    await tester.tap(find.byTooltip(l10n.timelineBackToCanvasTooltip));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(area().sceneId, second);
    expect(area().currentFrame, 1);
    expectPaletteCurrent();
    final outline = find.byKey(const Key('canvasCurrentFrameOutline'));
    final secondFrame = find.byKey(const Key('frameStripCell1'));
    expect(
      tester.getCenter(secondFrame).dx,
      closeTo(tester.getCenter(outline).dx, .5),
    );
    expect(
      area().currentLayerId,
      projects.layersOf(project.id, second, 1).first.id,
    );

    final strip = find.byType(FrameStripWidget);
    final drag = await tester.startGesture(tester.getCenter(strip));
    await drag.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(area().currentFrame, 3);
    expectPaletteCurrent();
    expect(
      tester
          .getRect(find.byKey(const Key('frameStripCell3')))
          .contains(tester.getCenter(outline)),
      isTrue,
    );
    await drag.up();
    await tester.pumpAndSettle();
    final frameAfterDrag = area().currentFrame;
    expect(frameAfterDrag, greaterThanOrEqualTo(3));

    await tester.tap(find.byTooltip(l10n.canvasTimelineModeTooltip));
    await pumpRealAsync(tester, const Duration(milliseconds: 450));
    expect(tester.widget<Text>(counter).data, '${frameAfterDrag + 1}/5');
    expect(firstAudio, findsNothing);
    expect(secondAudio, findsOneWidget);
    final timelineOutline = find.byKey(
      const Key('timelineCurrentFrameOutline'),
    );
    expect(
      tester
          .getCenter(find.byKey(ValueKey('timelineFrameCell$frameAfterDrag')))
          .dx,
      closeTo(tester.getCenter(timelineOutline).dx, .5),
    );

    appRouter.go('/canvas/${project.id}?scene=missing&frame=999');
    await pumpRealAsync(tester, const Duration(milliseconds: 450));
    expect(area().sceneId, first);
    expect(area().currentFrame, 0);
    expect(find.byType(TimelineScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
