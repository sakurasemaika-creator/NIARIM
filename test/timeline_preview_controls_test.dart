import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/timeline_marker.dart';
import 'package:niarim/widgets/keyframe_preview.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/canvas_preview_navigator.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:niarim/widgets/progress_dialog.dart';
import 'package:niarim/widgets/stepped_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

class _FailingAutofillPresets extends AutofillPresetService {
  @override
  AutofillPart? findPart(String partId) {
    if (partId == 'unreadable') throw const FileSystemException('test');
    return super.findPart(partId);
  }
}

/// Controls use the header/preview-band and resize-handle edges as anchors.
/// They need not avoid artwork and must never reserve space around the image.
void main() {
  const projects = {
    'portrait': Size(1080, 1920),
    'landscape': Size(1920, 1080),
    'square': Size(1080, 1080),
  };
  const screens = [
    (size: Size(390, 844), pc: false),
    (size: Size(320, 640), pc: false),
    (size: Size(1280, 800), pc: true),
  ];
  const controls = [
    'timelinePreviewFrameCount',
    'timelinePreviewFullscreenButton',
  ];

  Future<String> openTimeline(
    WidgetTester tester, {
    required Size project,
    required Size screen,
    required bool pc,
    required double fraction,
    void Function(ProjectService, String)? setUpProject,
    AutofillPresetService? presets,
    bool showNavigator = false,
    String language = 'ja',
    int durationSeconds = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      'timeline_preview_height_fraction': fraction,
      if (showNavigator) 'default_docked_panels': ['canvasPreview'],
      if (showNavigator) 'desktop_dock_auto_collapse_enabled': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-controls-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          if (presets != null)
            ChangeNotifierProvider<AutofillPresetService>.value(value: presets),
        ],
        child: const NiarimApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final created = await tester.runAsync(
      () => ps.createProject(
        name: 'preview-controls',
        fps: 12,
        durationSeconds: durationSeconds,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: project.width.toInt(),
        exportHeight: project.height.toInt(),
      ),
    );
    if (setUpProject != null) {
      await tester.runAsync(() async => setUpProject(ps, created!.id));
    }
    appRouter.go('/timeline/${created!.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return created.id;
  }

  for (final (screen, kind) in [
    (const Size(1280, 800), PointerDeviceKind.mouse),
    (const Size(390, 844), PointerDeviceKind.touch),
  ]) {
    testWidgets(
      'first timeline press after opening from details works with ${kind.name}',
      (tester) async {
        final id = await openTimeline(
          tester,
          project: const Size(160, 90),
          screen: screen,
          pc: kind == PointerDeviceKind.mouse,
          fraction: .4,
        );
        appRouter.go('/project/$id');
        await pumpRealAsync(tester, const Duration(milliseconds: 400));
        final l10n = lookupAppLocalizations(const Locale('ja'));
        final edit = find.text(l10n.projectDetailStartEditButton);
        await tester.ensureVisible(edit);
        final cursor = kind == PointerDeviceKind.mouse
            ? await tester.createGesture(kind: kind)
            : null;
        if (cursor == null) {
          await tester.tap(edit, kind: kind);
        } else {
          final position = tester.getCenter(edit);
          await cursor.addPointer(location: position);
          await cursor.down(position);
          await cursor.up();
        }
        await pumpRealAsync(tester, const Duration(milliseconds: 450));
        expect(find.byType(CanvasArea), findsOneWidget);

        final timeline = find.byKey(const Key('canvasTimelineModeButton'));
        expect(timeline.hitTestable(), findsOneWidget);
        if (cursor != null) {
          final target = tester.getCenter(timeline);
          await cursor.moveTo(target);
          await tester.pump(const Duration(seconds: 1));
          await cursor.down(target);
          await cursor.up();
          await cursor.removePointer();
        } else {
          await tester.tap(timeline, kind: kind);
        }
        await pumpRealAsync(tester, const Duration(milliseconds: 500));
        expect(find.byType(TimelineScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('320px timeline opens export without scrolling the toolbar', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTimeline(
      tester,
      project: const Size(16, 16),
      screen: const Size(320, 640),
      pc: false,
      fraction: .4,
      language: 'fr',
    );
    final export = find.byKey(const Key('timelineExportButton'));
    expect(export.hitTestable(), findsOneWidget);
    expect(tester.getSize(export), const Size(48, 48));
    await tester.tap(export);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ExportScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in ['success', 'unreadable frame', 'cancel']) {
    testWidgets('timeline batch auto-fill: $scenario', (tester) async {
      final presets = _FailingAutofillPresets();
      addTearDown(presets.dispose);
      String partFor(int frame) => scenario == 'unreadable frame' && frame == 1
          ? 'unreadable'
          : 'test-part';
      final id = await openTimeline(
        tester,
        project: const Size(16, 16),
        screen: const Size(1280, 900),
        pc: true,
        fraction: .4,
        presets: presets,
        setUpProject: (projects, id) {
          final scene = projects.scenesOf(id).single.id;
          final lineart = Uint8List(16 * 16 * 4);
          for (var y = 2; y <= 13; y++) {
            for (var x = 2; x <= 13; x++) {
              if (x == 2 || x == 13 || y == 2 || y == 13) {
                lineart[(y * 16 + x) * 4 + 3] = 255;
              }
            }
          }
          for (var frame = 0; frame < 3; frame++) {
            final layer = projects.addLayer(
              projectId: id,
              sceneId: scene,
              frameIndex: frame,
              type: LayerType.autoFillLineart,
              name: 'Line art',
            );
            projects.assignAutofillPart(
              projectId: id,
              sceneId: scene,
              frameIndex: frame,
              lineartLayerId: layer.id,
              partId: partFor(frame),
              partName: 'Fill',
            );
            projects
                .tileManagerOf(id)
                .replaceLayerPixels(
                  frameLayerKey(scene, frame, layer.id),
                  lineart,
                );
          }
        },
      );
      await tester.runAsync(() async {
        await presets.init();
        await presets.addPreset(
          const AutofillPreset(
            id: 'test-preset',
            name: 'Test preset',
            parts: [
              AutofillPart(id: 'test-part', name: 'Fill', color: 0xFF12AB34),
            ],
          ),
        );
      });
      final context = tester.element(find.byType(TimelineScreen));
      final l10n = AppLocalizations.of(context)!;
      final projects = context.read<ProjectService>();
      final history = context.read<UndoManager>();
      final scene = projects.scenesOf(id).single.id;
      List<bool> filledFrames() => [
        for (var frame = 0; frame < 3; frame++)
          projects
              .layersOf(id, scene, frame)
              .any((l) => l.type == LayerType.autoFill),
      ];
      expect(filledFrames(), [false, false, false]);
      final before = history.undoCount;

      await tester.tap(find.byIcon(Icons.more_vert).hitTestable().first);
      await pumpRealAsync(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.layerPanelMenuRunAutofill).hitTestable());
      await pumpRealAsync(tester, const Duration(milliseconds: 400));
      final currentScene = find.text(l10n.timelineAutofillScopeCurrentScene);
      await tester.ensureVisible(currentScene);
      await tester.tap(currentScene);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.layerPanelExecuteButton),
      );
      await tester.pump();
      final progress = find.byType(ProgressDialog);
      if (scenario == 'cancel') {
        await tester.pump(const Duration(milliseconds: 400));
        expect(progress, findsOneWidget);
        final cancel = find.descendant(
          of: progress,
          matching: find.text(l10n.commonCancel),
        );
        await tester.tap(cancel.hitTestable());
        await tester.pump();
      }
      final expected = switch (scenario) {
        'success' => l10n.timelineAutofillCompleteSnackbar(3),
        'unreadable frame' =>
          '${l10n.timelineAutofillFailedFrames(1)} ${l10n.timelineAutofillFileError}',
        _ => l10n.timelineAutofillBatchCancelled,
      };
      final notice = find.text(expected);
      for (var i = 0; notice.evaluate().isEmpty && i < 120; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 50));
      }
      expect(notice, findsOneWidget);
      expect(progress, findsNothing);
      if (scenario == 'cancel') {
        expect(filledFrames().skip(1), [false, false]);
      } else {
        expect(filledFrames(), [true, scenario == 'success', true]);
        expect(history.undoCount, before + 1);
        history.undo(projectId: id);
        await tester.pump();
        expect(filledFrames(), [false, false, false]);
      }
      expect(tester.takeException(), isNull);
    });
  }

  Future<bool> frameCountSaved(
    WidgetTester tester,
    String projectId,
    int frames,
  ) async {
    for (var attempt = 0; attempt < 120; attempt++) {
      final persisted = (await tester.runAsync(() async {
        final base = await NiaproSerializer.projectsBasePath();
        final path = '$base/$projectId/$projectId.niapro';
        await Future<void>.delayed(const Duration(milliseconds: 25));
        final saved = await NiaproSerializer.load(path);
        return saved.scenes.single.frames.length == frames;
      }))!;
      await tester.pump(const Duration(milliseconds: 25));
      if (persisted) return true;
    }
    return false;
  }

  void expectBandAnchors(
    WidgetTester tester,
    String label,
    Size screen,
    List<String> keys,
  ) {
    expect(tester.takeException(), isNull, reason: label);
    final picture = tester.getRect(
      find.byKey(const Key('timelinePreviewPicture')),
    );
    final band = tester.getRect(find.byKey(const Key('timelinePreviewArea')));
    expect(picture.width, greaterThan(0), reason: label);
    for (final key in keys) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(
        rect.left >= 0 && rect.right <= screen.width + 1,
        isTrue,
        reason: '$label $key $rect',
      );
      if (key == 'timelinePreviewFullscreenButton') {
        expect(
          (rect.top - band.top).abs(),
          lessThanOrEqualTo(12),
          reason: '$label header edge',
        );
        expect(
          (rect.right - band.right).abs(),
          lessThanOrEqualTo(12),
          reason: '$label right edge',
        );
      } else {
        expect(
          (rect.left - band.left).abs(),
          lessThanOrEqualTo(12),
          reason: '$label frame count left',
        );
        expect(
          (rect.bottom - band.bottom).abs(),
          lessThanOrEqualTo(12),
          reason: '$label resize handle edge',
        );
      }
    }
    expect(find.byKey(const Key('timelinePreviewLoopButton')), findsNothing);
  }

  testWidgets('edited timeline dialogs finish closing with live controllers', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: 0.4,
    );
    final timeline = find.byType(TimelineScreen);
    final service = tester.element(timeline).read<ProjectService>();
    final sceneId = service.scenesOf(id).single.id;
    final l10n = AppLocalizations.of(tester.element(timeline))!;
    final more = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuButton<String> &&
          widget.icon is Icon &&
          (widget.icon! as Icon).icon == Icons.more_vert,
    );
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, l10n.commonOk),
    );

    await tester.tap(more.first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text(l10n.timelineDurationChangeMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, l10n.timelineDurationFramesLabel),
      '8',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(timeline, findsOneWidget);
    expect(service.frameCount(id, sceneId), 8);
    expect(await frameCountSaved(tester, id, 8), isTrue);

    final layer = service.addLayer(
      projectId: id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.common,
      name: 'Range fixture',
    );
    await tester.pumpAndSettle();
    final bar = find.text(layer.name).hitTestable().last;
    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(find.text(l10n.layerPanelRangeDialogTitle), findsOneWidget);
    await tester.tap(find.text(l10n.layerPanelRangeFrameRangeLabel));
    await tester.enterText(
      find.widgetWithText(TextField, l10n.layerPanelRangeStartFrameLabel),
      '7',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.layerPanelRangeEndFrameLabel),
      '3',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.text(l10n.layerPanelRangeOrderError), findsOneWidget);
    expect(
      service
          .scenesOf(id)
          .single
          .frames
          .first
          .layers
          .singleWhere((item) => item.id == layer.id)
          .rangeMode,
      LayerRangeMode.allFrames,
    );
    await tester.tap(find.text(l10n.layerPanelRangeUseCurrentButton));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    expect(find.text(l10n.layerPanelRangeOrderError), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.layerPanelRangeStartFrameLabel),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.layerPanelRangeEndFrameLabel),
      '5',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(timeline, findsOneWidget);

    await tester.runAsync(() => service.saveProject(id));
    final reopened = ProjectService();
    addTearDown(reopened.dispose);
    await tester.runAsync(reopened.init);
    expect(reopened.frameCount(id, sceneId), 8);
    final reloadedLayer = reopened
        .scenesOf(id)
        .single
        .frames
        .first
        .layers
        .singleWhere((item) => item.id == layer.id);
    expect((reloadedLayer.rangeStart, reloadedLayer.rangeEnd), (2, 5));
  });

  testWidgets(
    'scene rename rejects blank input and saves a trimmed name on Enter',
    (tester) async {
      final id = await openTimeline(
        tester,
        project: const Size(160, 90),
        screen: const Size(1280, 800),
        pc: true,
        fraction: .4,
      );
      final context = tester.element(find.byType(TimelineScreen));
      final ps = context.read<ProjectService>();
      final l10n = AppLocalizations.of(context)!;
      final original = ps.scenesOf(id).single.displayName;
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.icon == Icons.more_vert &&
              widget.size == 14,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.timelineSceneRenameTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      final change = find.widgetWithText(FilledButton, l10n.commonChange);
      for (final name in ['', '   ']) {
        await tester.enterText(field, name);
        await tester.pump();
        expect(tester.widget<FilledButton>(change).onPressed, isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(field, findsOneWidget);
        expect(ps.scenesOf(id).single.displayName, original);
      }
      await tester.enterText(field, '  Cut 2  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(field, findsNothing);
      expect(ps.scenesOf(id).single.displayName, 'Cut 2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one tap on a scene chip switches the timeline', (tester) async {
    await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(390, 844),
      pc: false,
      fraction: .4,
      setUpProject: (projects, id) {
        final scene = projects.addScene(id);
        projects.renameScene(id, scene.id, 'Second cut');
      },
    );
    final chip = find.widgetWithText(ChoiceChip, 'Second cut');
    expect(tester.widget<ChoiceChip>(chip).selected, isFalse);
    await tester.tap(chip);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
  });

  testWidgets('scene copies number old and new names in the scene menu', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      setUpProject: (ps, id) {
        final original = ps.scenesOf(id).single;
        ps.renameScene(id, original.id, 'Cut');
        ps.duplicateScene(id, original.id, name: 'Cutのコピー');
      },
    );
    final context = tester.element(find.byType(TimelineScreen));
    final ps = context.read<ProjectService>();
    final l10n = AppLocalizations.of(context)!;

    Future<void> duplicate(String name) async {
      final source = ps.scenesOf(id).singleWhere((s) => s.displayName == name);
      await tester.tap(find.byKey(ValueKey('timelineSceneMenu_${source.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l10n.themeDuplicateAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await duplicate('Cutのコピー');
    await duplicate('Cut (コピー 2)');
    expect(ps.scenesOf(id).map((scene) => scene.displayName), [
      'Cut',
      'Cutのコピー',
      'Cut (コピー 2)',
      'Cut (コピー 3)',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeline tools stay above the tracks during selection and paste',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const widths = [Size(320, 680), Size(1280, 800)];
      const selectionMenu = Key('timelineSelectionMenu');
      const selectionActions = Key('timelineSelectionActions');
      const paste = Key('timelinePasteButton');
      const tools = Key('timelineContextToolbar');
      for (final screen in widths) {
        final id = await openTimeline(
          tester,
          project: projects['portrait']!,
          screen: screen,
          pc: screen.width > 600,
          fraction: .36,
          setUpProject: (ps, id) {
            ps.addAudioClip(
              id,
              ps.scenesOf(id).first.id,
              const AudioClip(
                id: 'tone',
                label: 'tone',
                startFrame: 2,
                lengthFrames: 5,
              ),
            );
          },
        );
        final ps = tester
            .element(find.byType(TimelineScreen))
            .read<ProjectService>();
        final scene = ps.scenesOf(id).first.id;

        Future<void> choose(String label) async {
          await tester.tap(find.byKey(selectionMenu));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }

        Future<void> selectAll() async {
          await tester.tap(find.byKey(selectionActions));
          await tester.pumpAndSettle();
          await tester.tap(find.text('全選択'));
          await tester.pumpAndSettle();
        }

        expect(find.byKey(selectionMenu), findsOneWidget);
        expect(find.byKey(paste), findsNothing);
        await choose('素材クリップ');
        final toolbar = find.byKey(tools);
        expect(
          find.descendant(of: toolbar, matching: find.text('素材クリップ')),
          findsOneWidget,
        );
        expect(find.text('0件選択中'), findsOneWidget);
        await selectAll();
        expect(find.text('1件選択中'), findsOneWidget);
        await tester.tap(find.byKey(const Key('timelineSelectionDone')));
        await tester.pumpAndSettle();
        await choose('フレーム');
        await selectAll();
        expect(find.text('12件選択中'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.content_copy));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(paste));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: toolbar, matching: find.text('貼り付け')),
          findsOneWidget,
        );
        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();
        expect(ps.frameCount(id, scene), 12);
        await tester.tap(find.byKey(paste));
        await tester.pumpAndSettle();
        await tester.tap(find.text('決定'));
        await tester.pumpAndSettle();
        expect(ps.frameCount(id, scene), 24);
        expect(tester.takeException(), isNull);
        expect(await frameCountSaved(tester, id, 24), isTrue);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('camera sheet commits one move and keeps an occupied keyframe', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      setUpProject: (ps, id) {
        final sceneId = ps.scenesOf(id).single.id;
        ps.addCameraKeyframe(id, sceneId, const CameraKeyframe(frameIndex: 0));
        ps.addCameraKeyframe(
          id,
          sceneId,
          const CameraKeyframe(frameIndex: 4, zoom: 2),
        );
      },
    );
    final context = tester.element(find.byType(TimelineScreen));
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final history = context.read<UndoManager>();
    final sceneId = ps.scenesOf(id).single.id;
    final baseline = history.undoCount;
    final first = find.byKey(const ValueKey('cameraKfMarker_0'));
    final moving = find.byKey(const ValueKey('cameraKfMarker_4'));
    await tester.tap(moving);
    await tester.pumpAndSettle();
    final slider = find.byWidgetPredicate(
      (w) => w is LabeledSlider && w.label == l10n.timelineFrameTrackLabel,
    );
    final apply = find.widgetWithText(FilledButton, l10n.commonApply);
    expect(apply, findsOneWidget);
    final sheetList = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListView),
    );
    await tester.drag(sheetList, const Offset(0, -400));
    await tester.pumpAndSettle();
    tester.widget<LabeledSlider>(slider).onChanged!(1);
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    expect(history.undoCount, baseline);
    tester.widget<LabeledSlider>(slider).onChanged!(3);
    await tester.pump();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(ps.cameraKeyframesOf(id, sceneId).map((key) => key.frameIndex), [
      0,
      2,
    ]);
    expect(history.undoCount, baseline + 1);
    history.undo(projectId: id);
    await tester.pumpAndSettle();
    expect(ps.cameraKeyframesOf(id, sceneId).map((key) => key.frameIndex), [
      0,
      4,
    ]);

    final distance = tester.getCenter(first).dx - tester.getCenter(moving).dx;
    final drag = await tester.startGesture(tester.getCenter(moving));
    await drag.moveBy(const Offset(-30, 0));
    await drag.moveBy(Offset(distance, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(ps.cameraKeyframesOf(id, sceneId).map((key) => key.frameIndex), [
      0,
      4,
    ]);
    expect(
      find.text(l10n.timelineCameraFrameAlreadyHasKeyframe),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging artwork registers a camera keyframe only on save', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(390, 844),
      pc: false,
      fraction: .4,
    );
    final ctx = tester.element(find.byType(TimelineScreen));
    final l10n = AppLocalizations.of(ctx)!;
    final ps = ctx.read<ProjectService>();
    final sceneId = ps.scenesOf(id).single.id;
    await tester.tap(find.byTooltip(l10n.timelineAddCameraKfTooltip).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 500));

    final surface = find.byKey(const ValueKey('keyframeTransformPreview'));
    expect(surface.hitTestable(), findsOneWidget);
    final start = tester
        .widget<KeyframePreview>(find.byType(KeyframePreview))
        .camera!;
    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveBy(const Offset(48, 18));
    await gesture.up();
    await tester.pump();

    expect(ps.cameraKeyframesOf(id, sceneId), isEmpty);
    final draft = tester
        .widget<KeyframePreview>(find.byType(KeyframePreview))
        .camera!;
    expect(draft.x, lessThan(start.x));
    expect(draft.y, lessThan(start.y));
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonAdd));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final saved = ps.cameraKeyframesOf(id, sceneId).single;
    expect(saved.frameIndex, 0);
    expect(saved.x, draft.x);
    expect(saved.y, draft.y);
    expect(tester.takeException(), isNull);
  });

  for (final pc in [false, true]) {
    testWidgets('timestamp name seeks and centers its frame (PC: $pc)', (
      tester,
    ) async {
      await openTimeline(
        tester,
        project: const Size(160, 90),
        screen: pc ? const Size(1280, 800) : const Size(390, 844),
        pc: pc,
        fraction: .4,
        durationSeconds: 4,
        setUpProject: (ps, id) {
          final scene = ps.scenesOf(id).single;
          ps.addTimelineMarker(id, scene.id, 36, 'Cut at three seconds');
        },
      );

      final row = find.byKey(const Key('timelineTimestampRow'));
      final name = find.descendant(
        of: row,
        matching: find.text('Cut at three seconds'),
      );
      final outline = find.byKey(const Key('timelineCurrentFrameOutline'));
      expect(
        find.descendant(of: row, matching: find.text('3.00s')),
        findsOneWidget,
      );
      expect(tester.getRect(row).bottom, lessThan(tester.getRect(outline).top));
      await tester.tap(name);
      await pumpRealAsync(tester, const Duration(milliseconds: 250));

      final frame = find.byKey(const Key('timelineFrameCell36'));
      expect(
        tester.getCenter(frame).dx,
        closeTo(tester.getCenter(outline).dx, .5),
      );
      final pin = find.byKey(const Key('timelineTimestamp-36'));
      expect(pin, findsOneWidget);
      expect(
        tester.getRect(pin).bottom,
        closeTo(tester.getRect(frame).top, .5),
      );
      expect(tester.getSize(frame).height, 40);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
      if (!pc) {
        expect(
          tester
              .widget<Text>(find.byKey(const Key('timelineCurrentSeconds')))
              .data,
          '3.0s',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'markers sharing a frame can be edited and deleted individually',
    (tester) async {
      final id = await openTimeline(
        tester,
        project: const Size(160, 90),
        screen: const Size(1280, 800),
        pc: true,
        fraction: .4,
        setUpProject: (ps, id) {
          final sceneId = ps.scenesOf(id).single.id;
          ps.addTimelineMarker(id, sceneId, 1, 'First marker');
          ps.addTimelineMarker(id, sceneId, 1, 'Second marker');
        },
      );
      final context = tester.element(find.byType(TimelineScreen));
      final l10n = AppLocalizations.of(context)!;
      final ps = context.read<ProjectService>();
      final sceneId = ps.scenesOf(id).single.id;
      final stamp = find.byKey(const ValueKey('timelineTimestamp-1'));
      expect(
        tester.getRect(stamp).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('timelineFrameCell1'))).top,
        ),
      );
      await tester.tap(stamp);
      await tester.pumpAndSettle();
      expect(find.text('First marker'), findsNWidgets(2));
      expect(find.text('Second marker'), findsNWidgets(2));
      await tester.tap(find.widgetWithText(MenuItemButton, 'F2'));
      await tester.pumpAndSettle();
      final first = ps
          .timelineMarkersOf(id, sceneId)
          .singleWhere((m) => m.comment == 'First marker');
      await tester.tap(
        find.byKey(ValueKey('timelineTimestampName-${first.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('timelineTimestampEdit-${first.id}')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Edited marker');
      const blue = 0xFF387AC4;
      await tester.tap(
        find.byKey(const ValueKey('timelineTimestampColor-$blue')),
      );
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
      await tester.pumpAndSettle();
      final markers = ps.timelineMarkersOf(id, sceneId);
      expect(markers.map((m) => m.comment).toSet(), {
        'Edited marker',
        'Second marker',
      });

      final second = markers.singleWhere((m) => m.comment == 'Second marker');
      await tester.tap(
        find.byKey(ValueKey('timelineTimestampName-${second.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('timelineTimestampDelete-${second.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
      await tester.pumpAndSettle();
      final remaining = ps.timelineMarkersOf(id, sceneId).single;
      expect(remaining.comment, 'Edited marker');
      expect(remaining.color, blue);
      expect(TimelineMarker.fromJson(remaining.toJson()).color, blue);
      expect(
        TimelineMarker.fromJson({
          'id': 'old',
          'frameIndex': 1,
          'comment': 'Old',
        }).color,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one effect slider drag creates one undo entry', (tester) async {
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      setUpProject: (ps, id) => ps.addEffectFilter(
        id,
        ps.scenesOf(id).single.id,
        const EffectFilterInstance(
          id: 'blur-effect',
          type: EffectFilterType.gaussianBlur,
          startFrame: 0,
          endFrame: 11,
          param1: 5,
        ),
      ),
    );
    final context = tester.element(find.byType(TimelineScreen));
    final l10n = AppLocalizations.of(context)!;
    final ps = context.read<ProjectService>();
    final history = context.read<UndoManager>();
    final sceneId = ps.scenesOf(id).single.id;
    final baseline = history.undoCount;
    double strength() => ps.effectFiltersOf(id, sceneId).single.param1;
    Future<void> animate() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.tap(find.byTooltip(l10n.timelineEffectFilterLabel));
    await animate();
    final tile = find.widgetWithText(
      ExpansionTile,
      l10n.timelineEffectTypeGaussianBlur,
    );
    await tester.tap(tile);
    await animate();
    final row = find.byWidgetPredicate(
      (w) => w is LabeledSlider && w.label == l10n.timelineEffectStrengthLabel,
    );
    await tester.ensureVisible(row);
    await animate();
    final slider = find.descendant(of: row, matching: find.byType(Slider));
    final rect = tester.getRect(slider);
    final drag = await tester.startGesture(
      rect.centerLeft + Offset(rect.width * .27, 0),
    );
    for (var step = 0; step < 4; step++) {
      await drag.moveBy(Offset(rect.width * .07, 0));
      await tester.pump();
    }
    expect(history.undoCount, baseline);
    expect(strength(), 5);
    await drag.up();
    await animate();
    expect(strength(), greaterThan(5));
    expect(history.undoCount, baseline + 1);
    history.undo(projectId: id);
    expect(strength(), 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one common layer handle drag creates one undo entry', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      setUpProject: (ps, id) {
        final sceneId = ps.scenesOf(id).single.id;
        final layer = ps.addLayer(
          projectId: id,
          sceneId: sceneId,
          frameIndex: 0,
          type: LayerType.common,
          name: 'Shared pencil',
        );
        ps.updateLayer(
          projectId: id,
          sceneId: sceneId,
          frameIndex: 0,
          layer: layer.copyWith(
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: 1,
            rangeEnd: 4,
          ),
        );
      },
    );
    final context = tester.element(find.byType(TimelineScreen));
    final ps = context.read<ProjectService>();
    final history = context.read<UndoManager>();
    final baseline = history.undoCount;
    (int?, int?) range() {
      final layer = ps.commonLayersOf(id).single.layer;
      return (layer.rangeStart, layer.rangeEnd);
    }

    final bar = find
        .ancestor(
          of: find.text('Shared pencil').last,
          matching: find.byType(Positioned),
        )
        .first;
    final handles = find.descendant(
      of: bar,
      matching: find.byIcon(Icons.drag_indicator),
    );
    expect(handles, findsNWidgets(2));
    final start = tester.getCenter(handles.last);
    final frameWidth = tester.getSize(bar).width / 4;
    final drag = await tester.startGesture(start);
    await drag.moveBy(const Offset(22, 0));
    for (var frame = 0; frame < 3; frame++) {
      await drag.moveBy(Offset(frameWidth, 0));
      await tester.pump();
    }
    expect(tester.getCenter(handles.last).dx, greaterThan(start.dx));
    expect(history.undoCount, baseline);
    expect(range(), (1, 4));
    await drag.up();
    await tester.pumpAndSettle();
    expect(range(), (1, 7));
    expect(history.undoCount, baseline + 1);

    history.undo(projectId: id);
    await tester.pumpAndSettle();
    expect(range(), (1, 4));
    final cancelled = await tester.startGesture(start);
    await cancelled.moveBy(const Offset(22, 0));
    await cancelled.moveBy(Offset(frameWidth, 0));
    await tester.pump();
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(range(), (1, 4));
    expect(tester.getCenter(handles.last).dx, start.dx);
    expect(history.undoCount, baseline);
    history.redo(projectId: id);
    expect(range(), (1, 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'canvas retargets drawing after deleting a layer or leaving a common range',
    (tester) async {
      late String scene;
      late Layer deleted, folder, common;
      final id = await openTimeline(
        tester,
        project: const Size(640, 360),
        screen: const Size(1280, 800),
        pc: true,
        fraction: .4,
        setUpProject: (ps, id) {
          scene = ps.scenesOf(id).single.id;
          common = ps
              .addLayer(
                projectId: id,
                sceneId: scene,
                frameIndex: 0,
                type: LayerType.common,
                name: 'First frame only',
              )
              .copyWith(
                rangeMode: LayerRangeMode.frameRange,
                rangeStart: 1,
                rangeEnd: 1,
              );
          ps.updateLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: 0,
            layer: common,
          );
          deleted = ps.addLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: 0,
            type: LayerType.normal,
            name: 'Remove this layer',
          );
          folder = ps.addLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: 0,
            type: LayerType.folder,
            name: 'Folder above the drawing',
          );
          ps.addLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: 1,
            type: LayerType.folder,
            name: 'Second frame folder',
          );
        },
      );
      final ps = tester
          .element(find.byType(TimelineScreen))
          .read<ProjectService>();
      appRouter.go('/canvas/$id');
      await pumpRealAsync(tester, const Duration(milliseconds: 250));
      final canvas = find.byType(CanvasArea);
      CanvasArea area() => tester.widget<CanvasArea>(canvas);
      final tm = ps.tileManagerOf(id);
      String tileKey(int frame, String layer) =>
          ps.tileKeyFor(id, scene, frame, layer);
      bool hasInk(String key) =>
          tm.exportAll()[key]?.values.any(
            (bytes) => bytes.indexWhere((byte) => byte != 0) >= 0,
          ) ??
          false;
      Future<void> stroke() async {
        final center = tester.getCenter(canvas);
        final gesture = await tester.startGesture(
          center - const Offset(35, 0),
          kind: ui.PointerDeviceKind.mouse,
        );
        await gesture.moveTo(center + const Offset(40, 12));
        await gesture.up();
        await pumpRealAsync(tester, const Duration(milliseconds: 150));
      }

      expect(area().currentLayerId, deleted.id);
      final oldKey = tileKey(0, deleted.id);
      await stroke();
      expect(hasInk(oldKey), isTrue);
      final deletedPixels = tm
          .exportAll()[oldKey]!
          .values
          .expand((bytes) => bytes)
          .toList();
      ps.removeLayer(
        projectId: id,
        sceneId: scene,
        frameIndex: 0,
        layerId: deleted.id,
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 250));
      expect(
        ps.layersOf(id, scene, 0).any((layer) => layer.id == deleted.id),
        isFalse,
      );
      expect(
        tm.exportAll()[oldKey]?.values.expand((bytes) => bytes).toList(),
        deletedPixels,
      );
      expect(
        area().currentLayerId,
        isNot(anyOf(deleted.id, folder.id, isNull)),
      );
      final current = tileKey(0, area().currentLayerId!);
      await stroke();
      expect(hasInk(current), isTrue);
      expect(hasInk(tileKey(0, folder.id)), isFalse);
      expect(
        tm.exportAll()[oldKey]?.values.expand((bytes) => bytes).toList(),
        deletedPixels,
      );

      final commonRow = find.descendant(
        of: find.byType(LayerPanel),
        matching: find.text(common.name),
      );
      await tester.ensureVisible(commonRow);
      await tester.tap(commonRow);
      await tester.pump();
      expect(area().currentLayerId, common.id);
      final originalCommonPixels = tm
          .exportAll()[tileKey(0, common.id)]
          ?.values
          .expand((bytes) => bytes)
          .toList();
      expect(
        ModalRoute.of(tester.element(canvas))?.isCurrent,
        isTrue,
        reason: tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.bySubtype<Text>(),
              ),
            )
            .map((text) => text.data ?? text.semanticsLabel)
            .join(' / '),
      );
      ps.updateLayer(
        projectId: id,
        sceneId: scene,
        frameIndex: 0,
        layer: common.copyWith(rangeStart: 2, rangeEnd: 2),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(area().currentFrame, 0);
      expect(area().currentLayerId, isNot(common.id));
      expect(commonRow, findsNothing);
      await stroke();
      expect(
        tm
            .exportAll()[tileKey(0, common.id)]
            ?.values
            .expand((bytes) => bytes)
            .toList(),
        originalCommonPixels,
      );

      ps.updateLayer(
        projectId: id,
        sceneId: scene,
        frameIndex: 0,
        layer: common,
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      await tester.tap(commonRow);
      await tester.pump();
      expect(area().currentLayerId, common.id);

      final center = tester.getCenter(canvas);
      final left = await tester.startGesture(center - const Offset(40, 0));
      final right = await tester.startGesture(center + const Offset(40, 0));
      await left.moveBy(const Offset(-70, 0));
      await right.moveBy(const Offset(-70, 0));
      await left.up();
      await right.up();
      await pumpRealAsync(tester, const Duration(milliseconds: 200));
      expect(area().currentFrame, 1);
      expect(area().currentLayerId, isNot(common.id));
      final nextLayer = ps
          .layersOf(id, scene, 1)
          .singleWhere((layer) => layer.id == area().currentLayerId);
      expect(nextLayer.type, LayerType.normal);
      await stroke();
      expect(hasInk(tileKey(1, nextLayer.id)), isTrue);
      expect(
        tm
            .exportAll()[tileKey(0, common.id)]
            ?.values
            .expand((bytes) => bytes)
            .toList(),
        originalCommonPixels,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('frame paste scroll speed follows the distance from the grab', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(64, 64),
      screen: const Size(390, 844),
      pc: false,
      fraction: .36,
      durationSeconds: 3,
      setUpProject: (ps, id) {
        final scene = ps.scenesOf(id).single;
        final tiles = ps.tileManagerOf(id);
        for (final (i, frame) in scene.frames.indexed) {
          final key = ps.tileKeyFor(id, scene.id, i, frame.layers.first.id);
          tiles.setPixel(
            tiles.getOrCreateTile(key, 0, 0),
            0,
            0,
            i + 50,
            0,
            0,
            255,
          );
        }
      },
    );
    final outline = find.byKey(const Key('timelineCurrentFrameOutline'));
    final previewCount = find.byKey(const Key('timelinePreviewFrameCount'));
    final screen = tester.element(find.byType(TimelineScreen));
    final ps = screen.read<ProjectService>();
    final l10n = AppLocalizations.of(screen)!;
    final initial = ps.scenesOf(id).single.frames;
    int currentIndex() =>
        int.parse(tester.widget<Text>(previewCount).data!.split('/').first) - 1;

    await tester.longPress(find.byKey(const Key('timelineFrameCell0')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timelinePasteButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 240));

    final cursorX = tester.getCenter(outline).dx;
    final handle = find.byKey(const Key('timelineFramePlacementHandle'));
    final origin = tester.getCenter(handle);
    expect(origin.dx, cursorX);
    final drag = await tester.startGesture(origin);
    await tester.pump(kLongPressTimeout);
    final start = currentIndex();
    expect(start, initial.length - 1);
    expect(
      tester.getCenter(find.byKey(ValueKey('timelineFrameCell$start'))).dx,
      closeTo(cursorX, .5),
    );

    const interval = Duration(milliseconds: 192);
    await drag.moveTo(origin - const Offset(68, 0));
    await tester.pump(interval);
    final slow = currentIndex();
    expect(slow, lessThan(start));
    await drag.moveTo(origin - const Offset(140, 0));
    await tester.pump(interval);
    final fast = currentIndex();
    expect(slow - fast, greaterThan(start - slow));

    await drag.moveTo(origin + const Offset(80, 0));
    await tester.pump(interval);
    final target = currentIndex();
    expect(target, greaterThan(fast));
    await drag.moveTo(origin);
    await pumpRealAsync(tester, const Duration(milliseconds: 240));
    expect(currentIndex(), target);
    expect(tester.getCenter(outline).dx, cursorX);
    final centered = find.byKey(ValueKey('timelineFrameCell$target'));
    expect(
      tester.getRect(centered).contains(tester.getCenter(outline)),
      isTrue,
    );
    final picture = tester.widget<RawImage>(
      find.byKey(const Key('timelinePreviewPicture')),
    );
    final pixels = await tester.runAsync(
      () => picture.image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(pixels!.getUint8(0), target + 50);

    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(centered).dx, closeTo(cursorX, .5));
    await tester.tap(find.text(l10n.timelineConfirmButton));
    await tester.pumpAndSettle();
    final pasted = ps.scenesOf(id).single.frames;
    expect(pasted.length, initial.length + 1);
    expect(pasted[target + 1].layers.first.id, initial[target].layers.first.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('material drags move the clip and the preview on DeX', (
    tester,
  ) async {
    final clips = <String>[];
    final id = await openTimeline(
      tester,
      project: const Size(64, 64),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .36,
      durationSeconds: 3,
      setUpProject: (ps, id) {
        final scene = ps.scenesOf(id).single.id;
        for (final type in [
          LayerType.timelineText,
          LayerType.timelineImage,
          LayerType.timelineVideo,
        ]) {
          final layer = ps.addLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: 2,
            type: type,
            name: type.name,
          );
          clips.add(layer.id);
          ps.updateLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: 2,
            layer: layer.copyWith(
              rangeMode: LayerRangeMode.frameRange,
              rangeStart: 3,
              rangeEnd: 5,
            ),
          );
        }
        clips.add('drag-audio');
        ps.addAudioClip(
          id,
          scene,
          const AudioClip(
            id: 'drag-audio',
            label: 'Audio',
            startFrame: 2,
            lengthFrames: 3,
          ),
        );
      },
    );
    final ps = tester
        .element(find.byType(TimelineScreen))
        .read<ProjectService>();
    final scene = ps.scenesOf(id).single.id;
    final initialFrame = find.byKey(const Key('timelineFrameCell0'));
    final outline = find.byKey(const Key('timelineCurrentFrameOutline'));
    final previewCount = find.byKey(const Key('timelinePreviewFrameCount'));
    final seek = find.byType(SteppedSlider);
    final trackLists = find.byWidgetPredicate(
      (w) =>
          w is ListView &&
          w.scrollDirection == Axis.horizontal &&
          w.controller != null,
    );
    int currentFrame() =>
        int.parse(tester.widget<Text>(previewCount).data!.split('/').first);
    int savedStart(String clip) => clip == 'drag-audio'
        ? ps.audioClipsOf(id, scene).single.startFrame
        : ps
                  .storedLayersOf(id, scene, 2)
                  .singleWhere((l) => l.id == clip)
                  .rangeStart! -
              1;

    void expectTracksFollow() {
      final offsets = tester
          .widgetList<ListView>(trackLists)
          .map((track) => track.controller!.offset)
          .toList();
      expect(offsets, hasLength(5));
      expect(offsets.first, greaterThan(0));
      expect(offsets, everyElement(closeTo(offsets.first, .5)));
      expect(tester.widget<SteppedSlider>(seek).value, currentFrame() - 1);
    }

    for (final clip in clips) {
      await tester.tap(initialFrame);
      await tester.pumpAndSettle();
      final origin = tester.getCenter(
        find.byKey(ValueKey('timelineClip-$clip')),
      );
      final cursor = tester.getCenter(outline);
      final drag = await tester.startGesture(
        origin,
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pump(kLongPressTimeout);
      await drag.moveTo(origin + const Offset(120, 0));
      await tester.pump(const Duration(milliseconds: 256));
      expect(currentFrame(), greaterThan(2));
      expect(tester.getCenter(outline), cursor);
      expectTracksFollow();
      expect(savedStart(clip), 2);
      if (clip == clips.first) {
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(savedStart(clip), 2);
      } else {
        await drag.up();
        await tester.pumpAndSettle();
        // Pointer displacement alone would move the clip by only 3 frames.
        expect(savedStart(clip), greaterThan(5));
      }
    }

    await tester.tap(initialFrame);
    await tester.pumpAndSettle();
    final row = trackLists.at(1);
    final swipe = await tester.startGesture(tester.getCenter(row));
    await swipe.moveBy(const Offset(-60, 0));
    await swipe.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(currentFrame(), greaterThan(1));
    expectTracksFollow();
    await swipe.up();
    await tester.pumpAndSettle();
    expectTracksFollow();

    tester.widget<SteppedSlider>(seek).onChanged!(17);
    await tester.pump();
    expect(currentFrame(), 18);
    expectTracksFollow();
    final seekTarget = find.byKey(const Key('timelineFrameCell17'));
    expect(tester.getCenter(seekTarget).dx, tester.getCenter(outline).dx);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('material clip starts line up while the frame row scrolls', (
    tester,
  ) async {
    late String imageId;
    await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      setUpProject: (ps, id) {
        final scene = ps.scenesOf(id).single.id;
        final image = ps.addLayer(
          projectId: id,
          sceneId: scene,
          frameIndex: 2,
          type: LayerType.timelineImage,
          name: 'Image alignment sample',
        );
        imageId = image.id;
        ps.updateLayer(
          projectId: id,
          sceneId: scene,
          frameIndex: 2,
          layer: image.copyWith(
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: 3,
            rangeEnd: 7,
          ),
        );
        ps.addAudioClip(
          id,
          scene,
          const AudioClip(
            id: 'alignment',
            label: 'Alignment sample',
            startFrame: 2,
            lengthFrames: 5,
          ),
        );
      },
    );
    final clips = [
      find.byKey(const ValueKey('timelineClip-alignment')),
      find.byKey(ValueKey('timelineClip-$imageId')),
    ];
    final start = find.byKey(const ValueKey('timelineFrameCell2'));
    final target = find.byKey(const ValueKey('timelineFrameCell6'));
    await tester.pumpAndSettle();
    final initialX = tester.getTopLeft(start).dx;
    for (final clip in clips) {
      expect(tester.getTopLeft(clip).dx, closeTo(initialX, .5));
    }

    await tester.tap(target);
    await tester.pumpAndSettle();
    final movedX = tester.getTopLeft(start).dx;
    expect(movedX, lessThan(initialX - 50));
    for (final clip in clips) {
      expect(tester.getTopLeft(clip).dx, closeTo(movedX, .5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeline toggles individual frames and deletes the three selected',
    (tester) async {
      final id = await openTimeline(
        tester,
        project: const Size(160, 90),
        screen: const Size(1280, 800),
        pc: true,
        fraction: .4,
      );
      final context = tester.element(find.byType(TimelineScreen));
      final l10n = AppLocalizations.of(context)!;
      final ps = context.read<ProjectService>();
      final initial = ps
          .scenesOf(id)
          .single
          .frames
          .map((frame) => frame.layers.first.id)
          .toList();
      final frames = [0, 1, 3]
          .map((index) => find.byKey(ValueKey('timelineFrameCell$index')))
          .toList();

      await tester.tap(find.byKey(const Key('timelineSelectionMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.timelineFrameTrackLabel).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.timelineStackSelectedCount(0)), findsOneWidget);
      for (final frame in frames) {
        await tester.tap(frame);
        await tester.pump();
      }
      expect(find.text(l10n.timelineStackSelectedCount(3)), findsOneWidget);
      await tester.tap(frames[1]);
      await tester.pump();
      expect(find.text(l10n.timelineStackSelectedCount(2)), findsOneWidget);
      await tester.tap(frames[1]);
      await tester.pump();
      await tester.tap(find.byKey(const Key('timelineSelectionActions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      expect(
        ps.scenesOf(id).single.frames.map((frame) => frame.layers.first.id),
        [
          for (final (index, frame) in initial.indexed)
            if (![0, 1, 3].contains(index)) frame,
        ],
      );
      await tester.longPress(frames[0]);
      await tester.pumpAndSettle();
      await tester.tap(frames[1]);
      await tester.pump();
      expect(find.text(l10n.timelineStackSelectedCount(2)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canvas navigator shows new paint and pans the zoomed canvas', (
    tester,
  ) async {
    final id = await openTimeline(
      tester,
      project: const Size(640, 360),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      showNavigator: true,
      setUpProject: (ps, id) =>
          ps.setSceneFrameCount(id, ps.scenesOf(id).single.id, 2),
    );
    appRouter.go('/canvas/$id');
    final navigator = find.byType(CanvasPreviewNavigator);
    final preview = find.byKey(const ValueKey('canvasPreviewNavigatorImage'));
    final area = find.byType(CanvasArea).first;
    final raw = find.descendant(of: preview, matching: find.byType(RawImage));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(preview, findsOneWidget);
    final viewport = tester.widget<CanvasPreviewNavigator>(navigator).viewport;
    expect(viewport.value, const Rect.fromLTWH(0, 0, 1, 1));

    Future<int> inkPixels() async {
      final image = tester.renderObject<RenderImage>(raw).image!.clone();
      return (await tester.runAsync(() async {
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var count = 0;
          for (var offset = 3; offset < bytes.lengthInBytes; offset += 4) {
            if (bytes.getUint8(offset) > 0) count++;
          }
          return count;
        } finally {
          image.dispose();
        }
      }))!;
    }

    expect(await inkPixels(), 0);
    final center = tester.getCenter(area);
    final stroke = await tester.startGesture(
      center.translate(45, -28),
      kind: ui.PointerDeviceKind.mouse,
    );
    await stroke.moveBy(const Offset(100, 48));
    await stroke.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 1120));
    expect(await inkPixels(), greaterThan(10));

    await tester.tap(find.byKey(const ValueKey('frameStripCell1')));
    await pumpRealAsync(tester, const Duration(milliseconds: 260));
    expect(tester.widget<CanvasPreviewNavigator>(navigator).frameIndex, 1);
    expect(await inkPixels(), 0);
    await tester.tap(find.byKey(const ValueKey('frameStripCell0')));
    await pumpRealAsync(tester, const Duration(milliseconds: 260));
    expect(await inkPixels(), greaterThan(10));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: ui.PointerDeviceKind.mouse,
        position: center,
        scrollDelta: const Offset(0, -480),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final zoomed = viewport.value!;
    expect(zoomed.width, lessThan(1));
    final rect = tester.getRect(preview);
    await tester.tapAt(Offset(rect.left + rect.width * .73, rect.center.dy));
    await tester.pump();
    expect(viewport.value!.center.dx, greaterThan(zoomed.center.dx));
    final panned = viewport.value!.center.dx;
    await tester.dragFrom(
      Offset(rect.left + rect.width * .73, rect.center.dy),
      Offset(-rect.width * .48, 0),
    );
    await tester.pump();
    expect(viewport.value!.center.dx, lessThan(panned));
    expect(tester.takeException(), isNull);
  });

  testWidgets('material scale reaches the thumbnail on its own home frame', (
    tester,
  ) async {
    late String sceneId;
    late Layer material;
    final id = await openTimeline(
      tester,
      project: const Size(160, 90),
      screen: const Size(1280, 800),
      pc: true,
      fraction: .4,
      setUpProject: (projects, id) {
        sceneId = projects.scenesOf(id).single.id;
        projects.setSceneFrameCount(id, sceneId, 5);
        material = projects
            .addLayer(
              projectId: id,
              sceneId: sceneId,
              frameIndex: 2,
              type: LayerType.timelineImage,
              name: 'Blue shape',
            )
            .copyWith(
              rangeMode: LayerRangeMode.frameRange,
              rangeStart: 3,
              rangeEnd: 4,
            );
        projects.updateLayer(
          projectId: id,
          sceneId: sceneId,
          frameIndex: 2,
          layer: material,
        );
        final tiles = projects.tileManagerOf(id);
        final key = projects.tileKeyFor(id, sceneId, 2, material.id);
        final pixels = Uint8List(tiles.canvasWidth * tiles.canvasHeight * 4);
        for (
          var y = tiles.canvasHeight ~/ 2 - 24;
          y < tiles.canvasHeight ~/ 2 + 24;
          y++
        ) {
          for (
            var x = tiles.canvasWidth ~/ 2 - 32;
            x < tiles.canvasWidth ~/ 2 + 32;
            x++
          ) {
            final offset = (y * tiles.canvasWidth + x) * 4;
            pixels[offset + 2] = 255;
            pixels[offset + 3] = 255;
          }
        }
        tiles.replaceLayerPixels(key, pixels);
      },
    );

    Future<int> bluePixels(int frame) async {
      final thumbnail = find
          .descendant(
            of: find.byKey(ValueKey('timelineFrameCell$frame')),
            matching: find.byType(RawImage),
          )
          .first;
      final image = tester.renderObject<RenderImage>(thumbnail).image!.clone();
      return (await tester.runAsync(() async {
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var area = 0;
          for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
            if (bytes.getUint8(offset + 2) > 127 &&
                bytes.getUint8(offset) < 64) {
              area++;
            }
          }
          return area;
        } finally {
          image.dispose();
        }
      }))!;
    }

    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final fullSize = await bluePixels(2);
    expect(fullSize, greaterThan(30));
    expect(await bluePixels(3), fullSize);
    final projects = tester
        .element(find.byType(TimelineScreen))
        .read<ProjectService>();
    projects.updateLayer(
      projectId: id,
      sceneId: sceneId,
      frameIndex: 2,
      layer: material.copyWith(
        keyframes: const [LayerKeyframe(frameIndex: 2, scale: .5)],
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final scaled = await bluePixels(2);
    expect(scaled, greaterThan(0));
    expect(scaled, lessThan(fullSize ~/ 2));
    expect(await bluePixels(3), scaled);
  });

  for (final (route, key) in const [
    ('timeline', 'timelineFrameCell'),
    ('canvas', 'frameStripCell'),
  ]) {
    testWidgets('$route thumbnails retain a five-pixel line', (tester) async {
      final id = await openTimeline(
        tester,
        project: const Size(1920, 1080),
        screen: const Size(1280, 800),
        pc: true,
        fraction: .4,
        setUpProject: (ps, id) {
          ps.setSceneFrameCount(id, ps.scenesOf(id).single.id, 2);
          final scene = ps.scenesOf(id).single.id;
          final layer = ps.layersOf(id, scene, 0).first;
          final tiles = ps.tileManagerOf(id);
          final rgba = Uint8List(tiles.canvasWidth * tiles.canvasHeight * 4);
          final cropX = (tiles.canvasWidth - 1920) ~/ 2;
          final cropY = (tiles.canvasHeight - 1080) ~/ 2;
          for (var y = cropY + 100; y < cropY + 980; y++) {
            for (var x = cropX + 2; x < cropX + 7; x++) {
              rgba[(y * tiles.canvasWidth + x) * 4 + 3] = 255;
            }
          }
          tiles.replaceLayerPixels(ps.tileKeyFor(id, scene, 0, layer.id), rgba);
        },
      );
      if (route == 'canvas') {
        appRouter.go('/canvas/$id');
        await tester.pump();
      }
      final picture = find.descendant(
        of: find.byKey(ValueKey('${key}0')),
        matching: find.byType(RawImage),
      );
      var visibleRows = 0;
      for (var attempt = 0; attempt < 80; attempt++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 25));
        final image = picture.evaluate().isEmpty
            ? null
            : tester.renderObject<RenderImage>(picture.first).image?.clone();
        if (image == null) continue;
        visibleRows = (await tester.runAsync(() async {
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var rows = 0;
            for (var y = image.height ~/ 4; y < image.height * 3 ~/ 4; y++) {
              if (bytes.getUint8((y * image.width) * 4 + 3) > 0) rows++;
            }
            return rows;
          } finally {
            image.dispose();
          }
        }))!;
        if (visibleRows >= 12) break;
      }
      expect(visibleRows, greaterThanOrEqualTo(12));
    });

    testWidgets('$route frame thumbnails follow common layer range changes', (
      tester,
    ) async {
      late String sceneId;
      late Layer shared;
      final id = await openTimeline(
        tester,
        project: const Size(160, 90),
        screen: const Size(1280, 800),
        pc: true,
        fraction: .4,
        setUpProject: (ps, id) {
          sceneId = ps.scenesOf(id).single.id;
          shared = ps
              .addLayer(
                projectId: id,
                sceneId: sceneId,
                frameIndex: 0,
                type: LayerType.common,
                name: 'Thumbnail ink',
              )
              .copyWith(
                rangeMode: LayerRangeMode.frameRange,
                rangeStart: 1,
                rangeEnd: 1,
              );
          ps.updateLayer(
            projectId: id,
            sceneId: sceneId,
            frameIndex: 0,
            layer: shared,
          );
          final tiles = ps.tileManagerOf(id);
          final rgba = Uint8List(tiles.canvasWidth * tiles.canvasHeight * 4);
          for (var index = 0; index < rgba.length; index += 4) {
            rgba[index] = 255;
            rgba[index + 3] = 255;
          }
          tiles.replaceLayerPixels(
            ps.tileKeyFor(id, sceneId, 0, shared.id),
            rgba,
          );
        },
      );
      final service = tester
          .element(find.byType(TimelineScreen))
          .read<ProjectService>();
      if (route == 'canvas') appRouter.go('/canvas/$id');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      const red = [255, 0, 0, 255];
      const blank = [0, 0, 0, 0];
      Future<void> expectPicture(int frame, List<int> expected) async {
        final picture = find.descendant(
          of: find.byKey(ValueKey('$key$frame')),
          matching: find.byType(RawImage),
        );
        List<int>? sample;
        for (var attempt = 0; attempt < 50; attempt++) {
          await tester.pump(const Duration(milliseconds: 25));
          final image = picture.evaluate().isEmpty
              ? null
              : tester.renderObject<RenderImage>(picture.first).image?.clone();
          sample = await tester.runAsync<List<int>?>(() async {
            if (image == null) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return null;
            }
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final offset =
                  (image.height ~/ 2 * image.width + image.width ~/ 2) * 4;
              return bytes.buffer
                  .asUint8List(bytes.offsetInBytes + offset, 4)
                  .toList();
            } finally {
              image.dispose();
            }
          });
          if (listEquals(sample, expected)) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        expect(sample, expected, reason: '$route frame ${frame + 1}');
      }

      await expectPicture(0, red);
      await expectPicture(1, blank);
      service.updateLayer(
        projectId: id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: shared.copyWith(rangeEnd: 2),
      );
      await expectPicture(1, red);
      service.updateLayer(
        projectId: id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: shared,
      );
      await expectPicture(1, blank);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview controls anchor to the band, not the canvas image', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final MapEntry(key: shape, value: project) in projects.entries) {
      for (final screen in screens) {
        for (final fraction in const [0.18, 0.42, 0.7]) {
          final label =
              '$shape ${screen.size.width.toInt()}x'
              '${screen.size.height.toInt()} $fraction';
          await openTimeline(
            tester,
            project: project,
            screen: screen.size,
            pc: screen.pc,
            fraction: fraction,
          );
          expectBandAnchors(tester, label, screen.size, controls);
          final fullscreen = tester.getRect(
            find.byKey(const Key('timelinePreviewFullscreenButton')),
          );
          final count = tester.getRect(
            find.byKey(const Key('timelinePreviewFrameCount')),
          );
          final band = tester.getRect(
            find.byKey(const Key('timelinePreviewArea')),
          );
          expect(fullscreen.top, closeTo(band.top + 8, 12), reason: label);
          expect(count.left, closeTo(band.left + 8, 12), reason: label);
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'fullscreen frame count anchors to the band; entry button disappears',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final MapEntry(key: shape, value: project) in projects.entries) {
        const screen = Size(390, 844);
        await openTimeline(
          tester,
          project: project,
          screen: screen,
          pc: false,
          fraction: 0.42,
        );
        await tester.tap(
          find.byKey(const Key('timelinePreviewFullscreenButton')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
        // 全画面の中には「全画面にする」ボタンを出さない。
        expect(
          find.byKey(const Key('timelinePreviewFullscreenButton')),
          findsNothing,
        );
        expectBandAnchors(tester, 'fullscreen $shape', screen, const [
          'timelinePreviewFrameCount',
        ]);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // プレビュー欄を一番大きくすると、横長の絵は画面の横幅いっぱい（欄の
  // 端からの8pxを除く）まで大きくなる。欄の高さの上限には、絵の上下の
  // フレーム数・全画面の段を足してある（足さないと絵が4分の3の幅で止まる）。
  testWidgets('the largest band lets a landscape picture span the width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screen = Size(390, 844);
    await openTimeline(
      tester,
      project: projects['landscape']!,
      screen: screen,
      pc: false,
      fraction: 1.0,
    );
    expectBandAnchors(tester, 'largest band', screen, controls);
    final picture = tester.getRect(
      find.byKey(const Key('timelinePreviewPicture')),
    );
    expect(
      picture.width,
      greaterThanOrEqualTo(screen.width - 1),
      reason: '$picture',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // PC/DeXの全画面表示は画面いっぱいまで絵を大きくする（通常の欄の、
  // 横に間延びしないための幅900pxの上限は掛けない）。
  testWidgets('the full-screen preview on PC is not capped at 900px', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final screen in const [Size(1920, 1080), Size(1280, 800)]) {
      await openTimeline(
        tester,
        project: projects['landscape']!,
        screen: screen,
        pc: true,
        fraction: 0.42,
      );
      await tester.tap(
        find.byKey(const Key('timelinePreviewFullscreenButton')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      final label = 'pc fullscreen ${screen.width.toInt()}';
      expectBandAnchors(tester, label, screen, const [
        'timelinePreviewFrameCount',
      ]);
      final picture = tester.getRect(
        find.byKey(const Key('timelinePreviewPicture')),
      );
      final area = tester.getRect(find.byKey(const Key('timelinePreviewArea')));
      expect(picture.width, greaterThan(900), reason: '$label $picture');
      // 欄の高さか幅のどちらかいっぱいまで使う。
      expect(
        picture.height >= area.height - 1 || picture.width >= area.width - 1,
        isTrue,
        reason: '$label $picture in $area',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 全画面表示で「戻る」を押すと全画面を閉じるだけで、タイムラインからは
  // 出ない（キャンバスからgo()で来た、履歴が1枚だけのタイムラインでも、
  // ホームから積んだタイムラインでも）。全画面でないときの「戻る」は
  // そのまま前の画面へ戻る。
  testWidgets('Back closes the full-screen preview and stays on the timeline', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screen = Size(390, 844);
    String location() => appRouter.routerDelegate.currentConfiguration.uri.path;
    // Android 16以降の予測型「戻る」：Flutterが「戻る操作を受ける」とOSへ
    // 伝えていないと、OSは戻る操作をアプリへ渡さずにアプリを裏へ回す。
    // handlePopRouteはこの判断を通らないので、OSへ伝えた値を見る。
    final handlesBack = <bool>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        handlesBack.add(call.arguments as bool);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    Future<void> backFromFullscreen(String label) async {
      await tester.tap(
        find.byKey(const Key('timelinePreviewFullscreenButton')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      expect(handlesBack, isNotEmpty, reason: label);
      expect(handlesBack.last, isTrue, reason: '$label: predictive back');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: label);
      expect(find.byType(TimelineScreen), findsOneWidget, reason: label);
      expect(find.byIcon(Icons.fullscreen_exit), findsNothing, reason: label);
      expect(
        find.byKey(const Key('timelinePreviewFullscreenButton')),
        findsOneWidget,
        reason: label,
      );
      expect(
        ModalRoute.of(tester.element(find.byType(TimelineScreen)))!.isCurrent,
        isTrue,
        reason: label,
      );
    }

    // キャンバスからと同じgo()で開いた（履歴が1枚だけの）タイムライン。
    final id = await openTimeline(
      tester,
      project: projects['landscape']!,
      screen: screen,
      pc: false,
      fraction: 0.42,
    );
    await backFromFullscreen('go');
    expect(location(), '/timeline/$id');

    // 全画面の上にダイアログ等が開いているときは、「戻る」はそれを閉じる
    // （全画面はそのまま）。
    await tester.tap(find.byKey(const Key('timelinePreviewFullscreenButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    showDialog<void>(
      context: tester.element(find.byType(TimelineScreen)),
      builder: (_) => const AlertDialog(content: Text('probe')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('probe'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('probe'), findsNothing);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
    expect(find.byType(TimelineScreen), findsOneWidget);

    // ホームから積んだタイムライン：全画面を閉じた後の「戻る」はホームへ。
    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    appRouter.push('/timeline/$id');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await backFromFullscreen('push');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TimelineScreen), findsNothing);
    expect(location(), '/home');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
