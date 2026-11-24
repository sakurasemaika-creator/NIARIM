import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/crop_frame.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/widgets/material_gizmo.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// Cropping a timeline image in the real screen: the panel's cuts are of
/// the picture's drawn part, the preview's handles move the crop's edges,
/// and each change is one Undo step.
void main() {
  testWidgets('the crop panel and the preview handles crop an image; Undo '
      'and reset put it back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-crop-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();

    late String sceneId;
    late String imageId;
    late int width;
    late int height;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'crop',
        fps: 10,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      final tiles = ps.tileManagerOf(project.id);
      width = tiles.canvasWidth;
      height = tiles.canvasHeight;
      final layer = ps.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.timelineImage,
        name: 'picture',
      );
      imageId = layer.id;
      // A square picture fitted into the middle of the layer.
      final pixels = Uint8List(width * height * 4);
      final side = height;
      final left = (width - side) ~/ 2;
      for (var y = 0; y < height; y++) {
        for (var x = left; x < left + side; x++) {
          final i = (y * width + x) * 4;
          pixels
            ..[i] = 200
            ..[i + 3] = 255;
        }
      }
      tiles.replaceLayerPixels(
        ps.tileKeyFor(project.id, sceneId, 0, layer.id),
        pixels,
      );
      ps.updateLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 20,
        ),
      );
      return project.id;
    });
    final projectId = created!;
    Layer picture() => ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.id == imageId);
    final frame = Rect.fromLTWH(
      (width - height) / 2,
      0,
      height.toDouble(),
      height.toDouble(),
    );

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final clip = find.byKey(ValueKey('timelineClip-$imageId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(60, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final cropChip = find.widgetWithIcon(ChoiceChip, Icons.crop);
    await tester.ensureVisible(cropChip);
    await tester.tap(cropChip);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.byType(MaterialCropGizmo), findsOneWidget);
    expect(find.byType(MaterialTransformGizmo), findsNothing);

    // ── Panel: cut from the left. The cut is of the square, not the layer.
    final leftSlider = find.descendant(
      of: find.byKey(const ValueKey('cropLeft')),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(leftSlider);
    await tester.pump();
    await tester.drag(leftSlider, const Offset(80, 0));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final afterSlider = picture().crop;
    expect(afterSlider, isNotNull);
    final cuts = cropCutsIn(
      afterSlider,
      frame,
      width.toDouble(),
      height.toDouble(),
    );
    expect(cuts.left, greaterThan(5));
    expect([cuts.top, cuts.right, cuts.bottom], [0, 0, 0]);
    // The crop starts inside the picture, not at the layer's edge.
    expect(afterSlider!.left * width, greaterThan(frame.left));

    // One Undo for the whole drag of the slider.
    await tester.tap(find.byIcon(Icons.undo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(picture().crop, isNull);

    // ── Preview: drag the right edge's handle 20 px to the left.
    final gizmo = find.byType(MaterialCropGizmo);
    final box = tester.getRect(gizmo);
    final fit = [
      box.width / width,
      box.height / height,
    ].reduce((a, b) => a < b ? a : b);
    final origin = Offset(
      box.left + (box.width - width * fit) / 2,
      box.top + (box.height - height * fit) / 2,
    );
    final rightHandle = origin + Offset(frame.right, frame.center.dy) * fit;
    final gesture = await tester.startGesture(rightHandle);
    await tester.pump();
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final dragged = picture().crop!;
    expect(dragged.right * width, closeTo(frame.right - 20 / fit, 0.5));
    expect(dragged.left * width, closeTo(frame.left, 0.5));
    expect([dragged.top, dragged.bottom], [0, 1]);

    // One Undo for the whole drag of the handle.
    await tester.tap(find.byIcon(Icons.undo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(picture().crop, isNull);

    // Reset clears a crop.
    await tester.tap(find.byIcon(Icons.redo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(picture().crop, isNotNull);
    final reset = find.byKey(const ValueKey('cropReset'));
    await tester.ensureVisible(reset);
    await tester.pump();
    await tester.tap(reset);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(picture().crop, isNull);

    // Leaving the crop section gives the preview its move handles back.
    final transformChip = find.widgetWithIcon(ChoiceChip, Icons.open_with);
    await tester.ensureVisible(transformChip);
    await tester.tap(transformChip);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.byType(MaterialCropGizmo), findsNothing);
    expect(find.byType(MaterialTransformGizmo), findsOneWidget);
  });
}
