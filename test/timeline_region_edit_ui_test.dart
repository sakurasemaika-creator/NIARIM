import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_region_edit.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/widgets/material_gizmo.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

final _captureKey = GlobalKey();

/// Writes the screen to build/timeline-region-edit/[name].png for a look.
Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  final directory = Directory('build/timeline-region-edit')
    ..createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes!);
}

/// Selecting parts of a timeline image in the real screen (範囲選択): an
/// outline drawn on the preview, then moved and changed, copied or erased;
/// the moved part is dragged on the preview; each change is one Undo step;
/// edits are removed one by one or all at once.
void main() {
  testWidgets('the 範囲選択 section selects, moves, copies and erases parts '
      'of an image; Undo and removing put it back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-region-');
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
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
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
        name: 'region',
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
      final pixels = Uint8List(width * height * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels
          ..[i] = 200
          ..[i + 3] = 255;
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
    List<LayerRegionEdit> edits() => ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.id == imageId)
        .regionEdits;
    Future<void> settle() =>
        pumpRealAsync(tester, const Duration(milliseconds: 300));
    Future<void> tapKey(String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await settle();
    }

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final clip = find.byKey(ValueKey('timelineClip-$imageId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(60, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final regionChip = find.widgetWithIcon(ChoiceChip, Icons.highlight_alt);
    await tester.ensureVisible(regionChip);
    await tester.tap(regionChip);
    await settle();
    final gizmo = find.byType(MaterialRegionGizmo);
    expect(gizmo, findsOneWidget);
    expect(find.byType(MaterialTransformGizmo), findsNothing);
    expect(find.byType(MaterialCropGizmo), findsNothing);
    MaterialRegionGizmo handles() => tester.widget<MaterialRegionGizmo>(gizmo);

    // Nothing is selected: the edits cannot be chosen yet.
    expect(find.byKey(const ValueKey('regionNoSelection')), findsOneWidget);
    FilledButton moveButton() =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('regionMove')));
    expect(moveButton().onPressed, isNull);

    final box = tester.getRect(gizmo);
    final fit = [
      box.width / width,
      box.height / height,
    ].reduce((a, b) => a < b ? a : b);
    final origin = Offset(
      box.left + (box.width - width * fit) / 2,
      box.top + (box.height - height * fit) / 2,
    );
    Offset onPreview(double x, double y) => origin + Offset(x, y) * fit;

    Future<void> drag(Offset from, List<Offset> steps) async {
      final gesture = await tester.startGesture(from);
      await tester.pump();
      for (final step in steps) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await settle();
    }

    // ── Outline a rectangle: from (20, 10) to (60, 50) on the layer.
    final start = onPreview(20, 10);
    final end = onPreview(60, 50);
    await drag(start, [
      const Offset(0, 0),
      (end - start) / 2,
      (end - start) / 2,
    ]);
    final drawn = handles().selection!;
    expect(drawn.shape, RegionShape.rectangle);
    expect(drawn.bounds.left * width, closeTo(20, 0.6));
    expect(drawn.bounds.top * height, closeTo(10, 0.6));
    expect(drawn.bounds.right * width, closeTo(60, 0.6));
    expect(drawn.bounds.bottom * height, closeTo(50, 0.6));
    await _capture(tester, '1_rectangle_selected');
    // Selecting changes nothing of the material.
    expect(edits(), isEmpty);
    expect(moveButton().onPressed, isNotNull);

    // A tap outside clears the selection.
    await tester.tapAt(onPreview(120, 80));
    await settle();
    expect(handles().selection, isNull);
    await drag(start, [(end - start) / 2, (end - start) / 2]);
    expect(handles().selection, isNotNull);

    // ── Move/transform: the part becomes an edit and gets its handles.
    await tapKey('regionMove');
    expect(edits(), hasLength(1));
    final moved = edits().single;
    expect(moved.kind, RegionEditKind.move);
    expect(moved.region, handles().edit!.region);
    expect(handles().edit!.id, moved.id);
    expect(handles().selection, isNull);
    expect(find.byKey(const ValueKey('regionMoveX')), findsOneWidget);

    // Drag the part 50 preview pixels to the right (the whole way, from
    // where the finger came down): one Undo for the drag.
    await drag(onPreview(40, 30), [const Offset(25, 0), const Offset(25, 0)]);
    expect(edits().single.dx * width, closeTo(50 / fit, 1));
    expect(edits().single.dy, 0);
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(edits().single.dx, 0);
    await tester.tap(find.byIcon(Icons.redo).first);
    await settle();
    expect(edits().single.dx, isNot(0));
    await _capture(tester, '2_part_moved');

    // Flip it: one step.
    await tapKey('regionFlipHorizontal');
    expect(edits().single.scaleX, -1);
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(edits().single.scaleX, 1);

    // ── Done: back to selecting. An ellipse, copied.
    await tapKey('regionDone');
    expect(handles().edit, isNull);
    await tapKey('regionShape.ellipse');
    await drag(onPreview(80, 20), [const Offset(15, 10), const Offset(15, 10)]);
    expect(handles().selection!.shape, RegionShape.ellipse);
    await tapKey('regionDuplicate');
    expect(edits(), hasLength(2));
    final copy = edits()[1];
    expect(copy.kind, RegionEditKind.duplicate);
    expect(copy.region.shape, RegionShape.ellipse);
    // The copy is put a little away from its part, so it shows.
    expect(copy.dx, greaterThan(0));
    expect(handles().edit!.id, copy.id);
    await _capture(tester, '3_ellipse_copied');

    // ── Freehand, erased.
    await tapKey('regionDone');
    await tapKey('regionShape.freehand');
    await drag(onPreview(100, 60), [
      const Offset(20, 0),
      const Offset(0, 15),
      const Offset(-10, 5),
      const Offset(-10, -10),
    ]);
    final outline = handles().selection!;
    expect(outline.shape, RegionShape.freehand);
    expect(outline.points.length, greaterThanOrEqualTo(3));
    await _capture(tester, '4_freehand_selected');
    await tapKey('regionErase');
    expect(edits(), hasLength(3));
    expect(edits()[2].kind, RegionEditKind.erase);
    expect(handles().edit, isNull);
    expect(handles().selection, isNull);

    // Undo takes the erase back off.
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(edits(), hasLength(2));

    // Select all, erase.
    await tapKey('regionSelectAll');
    expect(handles().selection, isNotNull);
    await tapKey('regionErase');
    expect(edits(), hasLength(3));
    final list = find.byKey(ValueKey('regionEdit.${edits().first.id}'));
    await tester.ensureVisible(list);
    await settle();
    await _capture(tester, '5_edit_list');

    // ── Tapping a moved part in the list brings its handles back.
    await tapKey('regionEdit.${moved.id}');
    expect(handles().edit!.id, moved.id);

    // Removing it puts its part back; the others stay.
    await tapKey('regionEditRemove.${moved.id}');
    expect(edits().map((e) => e.id), isNot(contains(moved.id)));
    expect(edits(), hasLength(2));
    expect(handles().edit, isNull);

    await tapKey('regionRemoveAll');
    expect(edits(), isEmpty);
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(edits(), hasLength(2));

    // Leaving the section gives the preview the material's handles back.
    final transformChip = find.widgetWithIcon(ChoiceChip, Icons.open_with);
    await tester.ensureVisible(transformChip);
    await tester.tap(transformChip);
    await settle();
    expect(find.byType(MaterialRegionGizmo), findsNothing);
    expect(find.byType(MaterialTransformGizmo), findsOneWidget);
  });
}
