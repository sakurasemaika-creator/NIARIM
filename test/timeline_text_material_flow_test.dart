// タイムラインのテキスト素材を実際の画面で操作する（ユーザー指定「テキストも
// 複数タイムラインの列を追加できる」「テキスト1とテキスト2の間にフレームの
// イラストを表示させる」「X軸Y軸Z軸回転などをスライダーやドラッグで手軽に
// 調整できる」「フレーム、テキスト、画像、動画それぞれマスクできる」）：
// ＋テキストで追加すると編集パネルが開き、同じ時間に重なる2つ目は別の列へ
// 置かれ、重なり順パネルでフレームを2つのテキストの間へ動かせ、配置の
// スライダー・プレビュー上のドラッグ・マスクの形がレイヤーへ記録される。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/bundled_fonts.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/scene_stack.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/widgets/material_edit_panel.dart';
import 'package:niarim/screens/timeline/widgets/material_gizmo.dart';
import 'package:niarim/screens/timeline/widgets/stack_order_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('texts are added on rows, stacked around the drawing, turned '
      'and masked from the timeline', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    FilePicker.platform = _FakeFilePicker();
    final tempDir = Directory.systemTemp.createTempSync('niarim_tl_text_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await loadAppFonts(tester);
    final shots = Directory('build/timeline-text-walkthrough')
      ..createSync(recursive: true);
    final rootKey = GlobalKey();
    Future<void> capture(String name) async {
      // The preview composes the frame with real async work.
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${shots.path}/$name.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'timeline-text-flow',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    // A sky-blue band on the drawing of F1 and F8, across the left 62% of
    // the middle, so the preview shows which texts are in front of it.
    final drawingScene = ps.scenesOf(project.id).first.id;
    final canvas = ps.tileManagerOf(project.id);
    final band = Uint8List(canvas.canvasWidth * canvas.canvasHeight * 4);
    for (
      var y = canvas.canvasHeight * 35 ~/ 100;
      y < canvas.canvasHeight * 65 ~/ 100;
      y++
    ) {
      for (var x = 0; x < canvas.canvasWidth * 62 ~/ 100; x++) {
        final i = (y * canvas.canvasWidth + x) * 4;
        band
          ..[i] = 0x7E
          ..[i + 1] = 0xC8
          ..[i + 2] = 0xE3
          ..[i + 3] = 0xFF;
      }
    }
    for (final frame in [0, 7]) {
      final drawingLayer = ps
          .layersOf(project.id, drawingScene, frame)
          .firstWhere((l) => l.type == LayerType.normal);
      canvas.replaceLayerPixels(
        ps.tileKeyFor(project.id, drawingScene, frame, drawingLayer.id),
        band,
      );
    }
    appRouter.go('/timeline/${project.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    // Let the preview finish its first picture (the drawing's tiles decode
    // with real async work; until then a progress spinner keeps
    // pumpAndSettle from settling).
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;
    final sceneId = ps.scenesOf(project.id).first.id;

    List<Layer> texts() => [
      for (final scene in ps.scenesOf(project.id))
        for (final frame in scene.frames)
          for (final layer in frame.layers)
            if (layer.type == LayerType.timelineText) layer,
    ];

    Future<void> addText(String text) async {
      // 素材を追加 → ＋テキスト.
      final button = find.byTooltip(l10n.timelineAddMaterialTooltip);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.timelineAddTextTooltip));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonAdd));
      // Drawing the letters is real async work (Picture.toImage).
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
      // The edit panel opens on the text: choose the bundled 源ノ明朝 (the
      // test has no system fonts, so the captures show the letters).
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kBundledFonts.first.displayName).last);
      await tester.pumpAndSettle();
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
    }

    // ── Adding a text opens it for editing, centred on the canvas ──
    await addText('タイトル');
    expect(texts(), hasLength(1));
    final title = texts().single;
    expect(title.textObject?.text, 'タイトル');
    expect(title.textObject?.fontFamily, kBundledFonts.first.family);
    expect(title.trackRow, 0);
    expect(title.rangeMode, LayerRangeMode.frameRange);
    expect(find.byType(TimelineMaterialEditPanel), findsOneWidget);
    expect(find.byType(MaterialTransformGizmo), findsOneWidget);
    await capture('01_text_added_edit_panel');
    final tm = ps.tileManagerOf(project.id);
    final home = ps.homeOf(project.id, title.id)!;
    final bounds = tm.contentBounds(
      ps.tileKeyFor(project.id, home.sceneId, home.frameIndex, title.id),
    );
    expect(bounds, isNotNull);
    expect(bounds!.center.dx, closeTo(tm.canvasWidth / 2, 3));
    expect(bounds.center.dy, closeTo(tm.canvasHeight / 2, 3));

    // ── Position: the Y turn slider and a drag on the preview ──
    await tester.tap(
      find.widgetWithText(ChoiceChip, l10n.timelineEditSectionTransform),
    );
    await tester.pump();
    final turnY = find.widgetWithText(
      LabeledSlider,
      l10n.timelineTransformRotationY,
    );
    await tester.ensureVisible(turnY);
    tester.widget<LabeledSlider>(turnY).onChanged!(40);
    await tester.pump();
    expect(texts().single.keyframes.single.rotationY, 40);

    final gizmo = find.byType(MaterialTransformGizmo);
    await tester.ensureVisible(gizmo);
    final start = tester.getCenter(gizmo) + const Offset(0, 6);
    final drag = await tester.startGesture(start);
    await tester.pump();
    await drag.moveBy(const Offset(10, 0));
    await tester.pump();
    await drag.moveBy(const Offset(50, 0));
    await tester.pump();
    await drag.up();
    await tester.pump();
    final moved = texts().single.keyframes.single;
    expect(moved.x, greaterThan(20));
    expect(moved.y.abs(), lessThan(3));
    // The turn set with the slider is kept by the drag.
    expect(moved.rotationY, 40);

    // ── Mask: an ellipse ──
    await capture('02_position_dragged');
    await tester.tap(
      find.widgetWithText(ChoiceChip, l10n.timelineEditSectionMask),
    );
    await tester.pump();
    await capture('03_mask_section');
    await tester.tap(find.text(l10n.timelineMaskEllipse));
    await tester.pump();
    expect(texts().single.mask?.shape, LayerMaskShape.ellipse);

    // ── A second text at the same time goes on a row of its own ──
    await tester.tap(find.byTooltip(l10n.commonClose).first);
    await tester.pumpAndSettle();
    expect(find.byType(TimelineMaterialEditPanel), findsNothing);
    await addText('サブ');
    final sub = texts().firstWhere((l) => l.textObject?.text == 'サブ');
    expect(sub.trackRow, 1);
    await capture('04_second_text_own_row');
    await tester.tap(find.byTooltip(l10n.commonClose).first);
    await tester.pumpAndSettle();

    // ── 重なり順: the drawing between the two texts ──
    final stackButton = find.byTooltip(l10n.timelineStackOrderTitle);
    await tester.ensureVisible(stackButton);
    await tester.tap(stackButton);
    await tester.pumpAndSettle();
    expect(find.byType(TimelineStackOrderPanel), findsOneWidget);
    await capture('05_stack_order_default');
    expect(find.text(l10n.timelineStackFrameUnit), findsOneWidget);
    // Default: text 1, text 2, then the drawing. Bring the drawing forward.
    final frameRow = find.ancestor(
      of: find.text(l10n.timelineStackFrameUnit),
      matching: find.byType(ListTile),
    );
    final frameUp = find.descendant(
      of: frameRow,
      matching: find.byTooltip(l10n.timelineStackMoveUp),
    );
    await tester.ensureVisible(frameUp);
    await tester.tap(frameUp);
    await tester.pump();
    await capture('06_drawing_between_texts');
    final scene = ps.sceneOf(project.id, sceneId)!;
    expect(scene.stack.order, [
      stackTrackKey(StackTrackKind.text, 0),
      kStackFrame,
      stackTrackKey(StackTrackKind.text, 1),
    ]);
    final stacked = ps.stackedLayersOf(project.id, sceneId, 0).layers;
    final drawing = stacked.indexWhere((l) => l.type == LayerType.normal);
    expect(stacked.indexWhere((l) => l.id == title.id), lessThan(drawing));
    expect(stacked.indexWhere((l) => l.id == sub.id), greaterThan(drawing));

    // ── フレーム範囲: F1〜F6 typed by hand, text 2 in front of everything ──
    final rangeRadio = find.text(l10n.timelineStackScopeRange);
    await tester.ensureVisible(rangeRadio);
    await tester.tap(rangeRadio);
    await tester.pump();
    expect(find.text(l10n.timelineStackRangeEmpty), findsOneWidget);
    final addRange = find.text(l10n.timelineStackRangeAdd(1));
    await tester.ensureVisible(addRange);
    await tester.tap(addRange);
    await tester.pump();
    final endField = find.widgetWithText(
      TextField,
      l10n.layerPanelRangeEndFrameLabel,
    );
    await tester.ensureVisible(endField);
    await tester.enterText(endField, '6');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Back to F1, where the range starts (typing the end showed F6).
    final rangeChip = find.widgetWithText(
      ChoiceChip,
      l10n.timelineStackRangeLabel(1, 6),
    );
    await tester.ensureVisible(rangeChip);
    await tester.tap(rangeChip);
    await tester.pump();
    final subRow = find.ancestor(
      of: find.text('${l10n.timelineMaterialText}2'),
      matching: find.byType(ListTile),
    );
    for (var i = 0; i < 2; i++) {
      final up = find.descendant(
        of: subRow,
        matching: find.byTooltip(l10n.timelineStackMoveUp),
      );
      await tester.ensureVisible(up);
      await tester.tap(up);
      await tester.pump();
    }
    final range = ps.sceneOf(project.id, sceneId)!.stack.ranges.single;
    expect([range.start, range.end], [0, 5]);
    expect(range.order, [
      stackTrackKey(StackTrackKind.text, 1),
      stackTrackKey(StackTrackKind.text, 0),
      kStackFrame,
    ]);
    expect(find.text(l10n.timelineStackRangeLabel(1, 6)), findsOneWidget);
    // In the range text 2 is in front; after it (F8) the scene's order again.
    List<String> idsAt(int frame) => [
      for (final l in ps.stackedLayersOf(project.id, sceneId, frame).layers)
        l.id,
    ];
    expect(idsAt(0).first, sub.id);
    expect(idsAt(5).first, sub.id);
    expect(idsAt(7).first, title.id);
    // The range's chip and its start and end in view.
    await tester.ensureVisible(find.text(l10n.timelineStackRangeLabel(1, 6)));
    await tester.pump();
    await capture('07_frame_range');

    // ── 全てのフレーム: every scene gets the order (the drawing in front) ──
    final second = ps.addScene(project.id);
    await tester.pump();
    final allRadio = find.text(l10n.timelineStackTargetAllFrames);
    await tester.ensureVisible(allRadio);
    await tester.tap(allRadio);
    await tester.pump();
    // The range set above still wins in its frames.
    expect(find.text(l10n.timelineStackRangesTakePriority), findsOneWidget);
    Future<void> raise(String label) async {
      final up = find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(ListTile),
        ),
        matching: find.byTooltip(l10n.timelineStackMoveUp),
      );
      await tester.ensureVisible(up);
      await tester.tap(up);
      await tester.pump();
    }

    await raise(l10n.timelineStackFrameUnit);
    for (final id in [sceneId, second.id]) {
      expect(ps.sceneOf(project.id, id)!.stack.order.first, kStackFrame);
    }
    // F8, after the range: the drawing in front of both texts there.
    tester
        .widget<TimelineStackOrderPanel>(find.byType(TimelineStackOrderPanel))
        .onSeek(7);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.ensureVisible(allRadio);
    await tester.pump();
    await capture('08_all_frames');

    // ── シーン複数選択: this scene and the new one, text 1 back in front ──
    final scenesRadio = find.text(l10n.timelineStackTargetScenes);
    await tester.ensureVisible(scenesRadio);
    await tester.tap(scenesRadio);
    await tester.pump();
    final secondChip = find.widgetWithText(FilterChip, second.displayName);
    expect(tester.widget<FilterChip>(secondChip).selected, isFalse);
    await tester.tap(secondChip);
    await tester.pump();
    await raise('${l10n.timelineMaterialText}1');
    for (final id in [sceneId, second.id]) {
      expect(ps.sceneOf(project.id, id)!.stack.order.first, 'text:0');
    }
    await tester.ensureVisible(secondChip);
    await tester.pump();
    await capture('09_choose_scenes');

    // The drawing can be masked too (the frame mask).
    final frameEllipse = find.text(l10n.timelineMaskEllipse);
    await tester.ensureVisible(frameEllipse);
    await tester.tap(frameEllipse);
    await tester.pump();
    expect(
      ps.sceneOf(project.id, sceneId)!.stack.frameMask?.shape,
      LayerMaskShape.ellipse,
    );
    expect(ps.stackedLayersOf(project.id, sceneId, 0).maskGroups, hasLength(1));
    await capture('10_frame_mask');
    expect(tester.takeException(), isNull);

    // ── 複数選択: long-press text 1, add text 2, send both to the back ──
    final sceneRadio = find.text(l10n.timelineStackScopeScene);
    await tester.ensureVisible(sceneRadio);
    await tester.tap(sceneRadio);
    await tester.pump();
    List<String> sceneOrder() =>
        ps.sceneOf(project.id, sceneId)!.stack.order.toList();
    expect(sceneOrder(), [
      stackTrackKey(StackTrackKind.text, 0),
      kStackFrame,
      stackTrackKey(StackTrackKind.text, 1),
    ]);
    Finder rowOf(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(ListTile));
    final text1Row = rowOf('${l10n.timelineMaterialText}1');
    final text2Row = rowOf('${l10n.timelineMaterialText}2');
    expect(find.byType(Checkbox), findsNothing);
    await tester.ensureVisible(text1Row);
    await tester.longPress(text1Row);
    await tester.pump();
    // Selection mode: a box on every item, the bar under the panel.
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text(l10n.timelineStackSelectedCount(1)), findsOneWidget);
    await tester.ensureVisible(text2Row);
    await tester.tap(text2Row);
    await tester.pump();
    expect(find.text(l10n.timelineStackSelectedCount(2)), findsOneWidget);
    // The whole list in view, from its first item.
    Future<void> showListTop() async {
      final top = find.byKey(ValueKey('stack-${sceneOrder().first}'));
      await tester.runAsync(
        () => Scrollable.ensureVisible(tester.element(top), alignment: 0.02),
      );
      await tester.pump();
    }

    await showListTop();
    await capture('11_multi_select');
    await tester.tap(
      find.widgetWithText(TextButton, l10n.timelineStackSendToBack),
    );
    await tester.pump();
    expect(sceneOrder(), [
      kStackFrame,
      stackTrackKey(StackTrackKind.text, 0),
      stackTrackKey(StackTrackKind.text, 1),
    ]);
    await showListTop();
    await capture('12_multi_sent_back');
    // A picked item's arrow moves both: up one place past the drawing.
    final text2Up = find.descendant(
      of: text2Row,
      matching: find.byTooltip(l10n.timelineStackMoveUp),
    );
    await tester.ensureVisible(text2Up);
    await tester.tap(text2Up);
    await tester.pump();
    expect(sceneOrder(), [
      stackTrackKey(StackTrackKind.text, 0),
      stackTrackKey(StackTrackKind.text, 1),
      kStackFrame,
    ]);
    // 全解除 leaves selection mode.
    await tester.tap(
      find.widgetWithText(TextButton, l10n.timelineStackDeselectAll),
    );
    await tester.pump();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text(l10n.timelineStackSelectedCount(2)), findsNothing);
    expect(tester.takeException(), isNull);

    // A range left past the last frame (frames deleted after it was set)
    // shows clamped to the scene and can still be edited.
    final frames = ps.frameCount(project.id, sceneId);
    final stack = ps.sceneOf(project.id, sceneId)!.stack;
    ps.updateSceneStack(
      project.id,
      sceneId,
      stack.copyWith(
        ranges: [
          ...stack.ranges,
          StackRange(start: frames + 4, end: frames + 9, order: const []),
        ],
      ),
    );
    final rangeAgain = find.text(l10n.timelineStackScopeRange);
    await tester.ensureVisible(rangeAgain);
    await tester.tap(rangeAgain);
    await tester.pump();
    final pastEnd = find.widgetWithText(
      ChoiceChip,
      l10n.timelineStackRangeLabel(frames, frames),
    );
    await tester.ensureVisible(pastEnd);
    await tester.tap(pastEnd);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final startField = find.widgetWithText(
      TextField,
      l10n.layerPanelRangeStartFrameLabel,
    );
    await tester.ensureVisible(startField);
    await tester.enterText(startField, '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Kept clear of the F1〜F6 range before it.
    final pulled = ps.sceneOf(project.id, sceneId)!.stack.ranges.last;
    expect(pulled.start, 6);
    expect(pulled.end, frames - 1);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 180)));
}
