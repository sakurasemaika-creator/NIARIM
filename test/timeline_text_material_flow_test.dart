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
      await tester.pump();
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
    appRouter.go('/timeline/${project.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
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
      final button = find.byTooltip(l10n.timelineAddTextTooltip);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonAdd));
      // Drawing the letters is real async work (Picture.toImage).
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
    }

    // ── Adding a text opens it for editing, centred on the canvas ──
    await addText('タイトル');
    expect(texts(), hasLength(1));
    final title = texts().single;
    expect(title.textObject?.text, 'タイトル');
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
    await tester.tap(
      find.descendant(
        of: frameRow,
        matching: find.byTooltip(l10n.timelineStackMoveUp),
      ),
    );
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
    await capture('07_frame_mask');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 180)));
}
