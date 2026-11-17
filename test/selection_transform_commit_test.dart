import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/selection_transform_sliders.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/editable_slider_value.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  testWidgets(
    'selection reuses source pixels, tracks undo and cancels slider and handle transforms',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final providers = (await tester.runAsync(buildAppProviders))!;
      final open = ValueNotifier<String?>(null);
      addTearDown(open.dispose);
      late ProjectService projects;
      late UndoManager history;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                projects = context.read<ProjectService>();
                history = context.read<UndoManager>();
                return ValueListenableBuilder(
                  valueListenable: open,
                  builder: (_, id, _) => id == null
                      ? const SizedBox.expand()
                      : CanvasScreen(projectId: id),
                );
              },
            ),
          ),
        ),
      );
      const width = 96;
      const height = 96;
      final project = (await tester.runAsync(
        () => projects.createProject(
          name: 'selection transform',
          exportWidth: width,
          exportHeight: height,
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        ),
      ))!;
      final scene = projects.scenesOf(project.id).first;
      final layer = scene.frames.first.layers.first;
      final key = projects.tileKeyFor(project.id, scene.id, 0, layer.id);
      final tiles = projects.tileManagerOf(project.id);
      final pixels = Uint8List(width * height * 4);
      void mark(int x, int y) =>
          pixels.setAll((y * width + x) * 4, [255, 0, 0, 255]);
      for (var y = 30; y <= 38; y++) {
        mark(27, y);
      }
      for (var x = 27; x <= 33; x++) {
        mark(x, 38);
      }
      mark(80, 70);
      tiles.replaceLayerPixels(key, pixels);
      open.value = project.id;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      int alpha(int x, int y) =>
          tiles.getTile(key, 0, 0)?[((y * TileManager.tileSize + x) * 4) + 3] ??
          0;
      Offset at(double x, double y) {
        final area = tester.getRect(find.byType(CanvasArea));
        final drawing = canvasDrawingRectFor(area.size, project);
        return area.topLeft +
            drawing.topLeft +
            Offset(x / width * drawing.width, y / height * drawing.height);
      }

      final l10n = lookupAppLocalizations(const Locale('ja'));
      await tester.tap(find.byIcon(Icons.highlight_alt).hitTestable().first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      Future<void> selectLasso() async {
        final lasso = await tester.startGesture(
          at(20, 24),
          kind: PointerDeviceKind.mouse,
        );
        for (final point in [at(40, 24), at(40, 44), at(20, 44), at(20, 24)]) {
          await lasso.moveTo(point);
          await tester.pump();
        }
        await lasso.up();
        await tester.pumpAndSettle();
      }

      var unrelatedUndone = false;
      history.push(
        ProjectEditUndoAction(
          'Earlier edit',
          () => unrelatedUndone = true,
          () => unrelatedUndone = false,
        ),
        projectId: project.id,
      );
      await selectLasso();
      final panel = find.byType(SelectionTransformSliders);
      expect(panel, findsOneWidget);
      final slider = find
          .descendant(of: panel, matching: find.byType(Slider))
          .first;

      // onChanged and onChangeEnd can arrive before the next build.
      Future<void> moveX(double dx) async {
        final control = tester.widget<Slider>(slider);
        control.onChanged!(dx);
        control.onChangeEnd!(dx);
        await tester.pumpAndSettle();
      }

      await moveX(38);
      expect(alpha(27, 30), 0);
      expect(alpha(65, 30), 255);
      await moveX(38);
      expect(alpha(65, 30), 0);
      expect(alpha(80, 70), 255);
      history.undo(projectId: project.id);
      await tester.pumpAndSettle();
      expect(alpha(65, 30), 255);
      history.redo(projectId: project.id);
      await tester.pumpAndSettle();
      expect(alpha(65, 30), 0);

      await moveX(-38);
      expect(
        alpha(65, 30),
        255,
        reason: 'fully off-canvas source remains recoverable',
      );
      await moveX(-38);
      expect(alpha(27, 30), 255);
      expect(alpha(33, 38), 255);

      final control = find
          .descendant(of: panel, matching: find.byType(EditableSliderValue))
          .first;
      await tester.tap(control);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(alpha(47, 30), 255);
      final handle = await tester.startGesture(
        at(50, 34),
        kind: PointerDeviceKind.mouse,
      );
      await handle.moveTo(at(50, 46));
      await tester.pump();
      await handle.up();
      await tester.pumpAndSettle();
      expect(alpha(47, 42), 255);
      history.undo(projectId: project.id);
      await tester.pumpAndSettle();
      expect(alpha(47, 30), 255);
      final handleAfterUndo = await tester.startGesture(
        at(50, 34),
        kind: PointerDeviceKind.mouse,
      );
      await handleAfterUndo.moveTo(at(50, 46));
      await tester.pump();
      await handleAfterUndo.up();
      await tester.pumpAndSettle();
      expect(
        alpha(47, 42),
        255,
        reason: 'the hit target follows the restored mask',
      );

      await tester.tap(
        find.text(l10n.canvasSelectionRevertButton).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(alpha(47, 42), 0);
      expect(alpha(27, 30), 255);
      expect(alpha(33, 38), 255);
      expect(alpha(80, 70), 255);
      expect(history.undoCount, 1);
      history.undo(projectId: project.id);
      expect(unrelatedUndone, isTrue);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.highlight_alt).hitTestable().first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await selectLasso();
      await tester.tap(
        find.text(l10n.canvasSelectionFreeTransform).hitTestable(),
      );
      await tester.pumpAndSettle();
      Future<void> waitForRaster() async {
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 12)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      await waitForRaster();
      final dynamic areaState = tester.state(find.byType(CanvasArea));
      final points = (areaState.meshControlPoints as List<Offset>);
      expect(points.length, 4);
      expect(points.first.dx, closeTo(20, 1));
      expect(points.first.dy, closeTo(24, 1));
      final corner = points[1];
      final warp = await tester.startGesture(
        at(corner.dx, corner.dy),
        kind: PointerDeviceKind.mouse,
      );
      await warp.moveTo(at(corner.dx - 12, corner.dy + 7));
      await tester.pump();
      await warp.up();
      await tester.pumpAndSettle();
      expect(
        alpha(27, 30),
        255,
        reason: 'mesh preview leaves original pixels intact',
      );
      final apply = find.descendant(
        of: find.byKey(const ValueKey('mesh-transform-action-bar')),
        matching: find.text(l10n.meshTransformApplyButton),
      );
      await tester.tap(apply);
      await tester.pumpAndSettle();
      await waitForRaster();
      expect(alpha(80, 70), 255, reason: 'unselected artwork is kept');
      final warped = tiles.getTile(key, 0, 0)!;
      final expected = pixels[(30 * width + 27) * 4 + 3];
      expect(
        warped[(30 * TileManager.tileSize + 27) * 4 + 3],
        lessThan(expected),
      );
      expect(history.canUndoFor(project.id), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
