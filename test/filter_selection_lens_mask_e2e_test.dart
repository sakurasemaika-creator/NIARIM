import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/filter_lens_mask.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/selection_transform_sliders.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pick_filter_card.dart';
import 'helpers/pump_real_async.dart';

const _size = 256;
const _thresholdFilterId = 'Filter0014';
const _lensFilterId = 'Filter0017';

/// Two colours of 8 px vertical stripes (so the glasses filter's bend
/// shows), with a black ring around the centre (so the bucket has a region
/// to fill).
Uint8List _stripesWithRing() {
  final out = Uint8List(_size * _size * 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final dx = x - 128, dy = y - 128;
      final d2 = dx * dx + dy * dy;
      final ring = d2 >= 46 * 46 && d2 <= 50 * 50;
      final colour = ring
          ? const [0, 0, 0]
          : (x ~/ 8).isEven
          ? const [40, 120, 200]
          : const [230, 200, 60];
      out.setAll((y * _size + x) * 4, [...colour, 255]);
    }
  }
  return out;
}

/// On the real canvas screen: with a selection made on the canvas, a
/// drawing filter changes only what is inside it (the panel says so). The
/// glasses filter starts its lens area from that selection, and its lens
/// area is painted on the canvas with the panel's pen, cleared, filled with
/// the bucket, each step undone and redone with the filter's Undo, and
/// applying it bends only that area.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('filters keep to the selection; the lens area is painted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tempDir = Directory.systemTemp.createTempSync('niarim_lens_e2e_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null),
    );
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    BuildContext? providerContext;
    final activeProject = ValueNotifier<String?>(null);
    addTearDown(activeProject.dispose);
    final boundary = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            providerContext = context;
            return RepaintBoundary(
              key: boundary,
              child: ValueListenableBuilder<String?>(
                valueListenable: activeProject,
                builder: (context, id, _) => MaterialApp(
                  theme: context.watch<ThemeService>().themeData,
                  scrollBehavior: const AppScrollBehavior(),
                  locale: const Locale('ja'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: id == null
                      ? const Scaffold(body: SizedBox.expand())
                      : CanvasScreen(projectId: id),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final context = providerContext!;
    final ps = context.read<ProjectService>();
    final fs = context.read<FilterService>();

    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'Filter selection E2E',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _size,
        exportHeight: _size,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.first;
    final tm = ps.tileManagerOf(project.id);
    final key = ps.tileKeyFor(project.id, scene.id, 0, layer.id);
    final original = _stripesWithRing();
    tm.replaceLayerPixels(key, original);
    activeProject.value = project.id;
    await pumpRealAsync(tester, const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    final l10n = AppLocalizations.of(tester.element(find.byType(CanvasArea)))!;

    final out = Directory('build/filter-selection')
      ..createSync(recursive: true);
    Future<void> capture(String name) async {
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(
          '${out.path}/$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    final canvasFinder = find.byType(CanvasArea);
    Future<Uint8List> layerPixels() async => (await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    Project currentProject() =>
        ps.projects.firstWhere((p) => p.id == project.id);
    Offset onScreen(double x, double y) {
      final area = tester.getRect(canvasFinder);
      final rect = canvasDrawingRectFor(area.size, currentProject());
      return area.topLeft + rect.topLeft + Offset(x, y) * (rect.width / _size);
    }

    List<int> px(Uint8List data, int x, int y) =>
        data.sublist((y * _size + x) * 4, (y * _size + x) * 4 + 4);

    Future<void> openFilterPanel() async {
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pump(const Duration(milliseconds: 250));
      final entry = find.byIcon(Icons.blur_on);
      await tester.ensureVisible(entry);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      await tester.tap(entry);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(find.byType(FilterPanel), findsOneWidget);
    }

    Future<void> applyFilter() async {
      final apply = find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byIcon(Icons.check),
      );
      await tester.tap(apply.first);
      await pumpRealAsync(tester, const Duration(milliseconds: 1500));
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
      expect(find.byType(FilterPanel), findsNothing);
    }

    // ── A lasso selection around (40,40)-(120,120) ──
    await tester.ensureVisible(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 300));
    final lasso = await tester.startGesture(
      onScreen(40, 40),
      kind: PointerDeviceKind.touch,
    );
    for (final (x, y) in const [(120.0, 40.0), (120.0, 120.0), (40.0, 120.0)]) {
      await lasso.moveTo(onScreen(x, y));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await lasso.moveTo(onScreen(40, 42));
    await tester.pump(const Duration(milliseconds: 16));
    await lasso.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    await capture('00_selection');

    /// Whether the selection's editing UI (its tool bar and transform
    /// sliders) is on the screen.
    void expectSelectionEditing(bool shown, String when) {
      final matcher = shown ? findsOneWidget : findsNothing;
      expect(
        find.text(l10n.canvasSelectionFreeTransform),
        matcher,
        reason: 'selection tool bar $when',
      );
      expect(
        find.byType(SelectionTransformSliders),
        matcher,
        reason: 'selection sliders $when',
      );
      expect(
        tester.widget<CanvasArea>(canvasFinder).lockToolInput,
        !shown,
        reason: 'canvas handles $when',
      );
    }

    expectSelectionEditing(true, 'with the selection made');

    // ── Opening the filter panel and closing it again (cancel) ──
    await openFilterPanel();
    expectSelectionEditing(false, 'while the filter panel is open');
    await tester.tap(
      find
          .descendant(
            of: find.byType(FilterPanel),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(find.byType(FilterPanel), findsNothing);
    expectSelectionEditing(true, 'after the filter panel is closed');

    // ── Threshold, inside the selection only ──
    await openFilterPanel();
    expect(
      tester.widget<FilterPanel>(find.byType(FilterPanel)).selectionMask,
      isNotNull,
      reason: 'the panel knows the canvas selection',
    );
    await pickFilterCard(tester, _thresholdFilterId);
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    expect(fs.currentFilter!.kind, FilterKind.threshold);
    expect(find.text(l10n.filterSelectionOnlyHint), findsOneWidget);
    expectSelectionEditing(false, 'while a filter is adjusted');
    await capture('01_threshold_preview_in_selection');
    await applyFilter();
    expectSelectionEditing(true, 'after the filter is applied');
    final thresholded = await layerPixels();
    // Inside: black or white; outside: as it was.
    final inside = px(thresholded, 80, 80);
    expect(inside[0], anyOf(0, 255));
    expect(inside[0], inside[1]);
    expect(px(thresholded, 180, 80), px(original, 180, 80));
    expect(px(thresholded, 80, 180), px(original, 80, 180));
    var changedOutside = 0;
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        if (x >= 38 && x <= 122 && y >= 38 && y <= 122) continue;
        final i = (y * _size + x) * 4;
        for (var c = 0; c < 4; c++) {
          if (thresholded[i + c] != original[i + c]) {
            changedOutside++;
            break;
          }
        }
      }
    }
    expect(changedOutside, 0, reason: 'nothing outside the selection');
    await capture('02_threshold_applied');
    // Put the stripes back for the glasses filter.
    tm.replaceLayerPixels(key, original);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));

    // ── The glasses filter starts from the selection ──
    await openFilterPanel();
    await pickFilterCard(tester, _lensFilterId);
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    expect(fs.currentFilter!.kind, FilterKind.lensDistortion);
    FilterLensMask lensMask() =>
        tester.widget<CanvasArea>(canvasFinder).filterLensMask!;
    int coverageAt(int x, int y) =>
        lensMask().coverage == null ? 0 : lensMask().coverage![y * _size + x];
    expect(coverageAt(80, 80), 255, reason: 'started from the selection');
    expect(coverageAt(180, 180), 0);
    expect(lensMask().tool, FilterLensMaskTool.pen);
    expect(find.text(l10n.filterLensMaskTitle), findsOneWidget);
    await capture('03_lens_started_from_selection');

    // Clearing it is one Undo step.
    await tester.ensureVisible(find.byKey(const ValueKey('lens-mask-clear')));
    await tester.tap(find.byKey(const ValueKey('lens-mask-clear')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(lensMask().isEmpty, isTrue);
    expect(find.text(l10n.filterLensDistortionNoMaskHint), findsOneWidget);
    fs.undoFilterEdit();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(coverageAt(80, 80), 255, reason: 'Undo brings the area back');
    fs.redoFilterEdit();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(lensMask().isEmpty, isTrue);

    // ── Paint a stroke with the pen ──
    final pen = await tester.startGesture(
      onScreen(60, 200),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 6; i++) {
      await pen.moveTo(onScreen(60 + 140 * i / 6, 200));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await capture('04_pen_stroke_live');
    await pen.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(coverageAt(130, 200), 255, reason: 'along the stroke');
    expect(coverageAt(130, 230), 0, reason: 'beyond the pen');
    expect(coverageAt(80, 80), 0, reason: 'the cleared selection');
    // The stroke is one Undo step.
    fs.undoFilterEdit();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(coverageAt(130, 200), 0);
    fs.redoFilterEdit();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(coverageAt(130, 200), 255);

    // ── The eraser takes part of it away ──
    await tester.tap(find.text(l10n.filterLensMaskEraser));
    await tester.pump();
    expect(lensMask().tool, FilterLensMaskTool.eraser);
    final eraser = await tester.startGesture(
      onScreen(190, 200),
      kind: PointerDeviceKind.mouse,
    );
    await eraser.moveTo(onScreen(200, 200));
    await tester.pump();
    await eraser.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(coverageAt(196, 200), 0, reason: 'erased');
    expect(coverageAt(100, 200), 255, reason: 'kept');

    // ── The bucket adds the stripe inside the ring ──
    await tester.tap(find.text(l10n.filterLensMaskBucket));
    await tester.pump();
    final bucket = await tester.startGesture(
      onScreen(130, 128),
      kind: PointerDeviceKind.mouse,
    );
    await bucket.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(coverageAt(130, 128), 255, reason: 'the tapped stripe');
    expect(coverageAt(130, 100), 255, reason: 'the same stripe, inside');
    expect(coverageAt(130, 60), 0, reason: 'the ring stops it');
    expect(coverageAt(140, 128), 0, reason: 'the next stripe');
    await capture('05_lens_area_painted');

    // ── Applying bends only the lens area ──
    await tester.tap(find.text(l10n.filterLensMaskPen));
    await tester.pump();
    fs.updateFilterParams(fs.currentFilter!.id, strength: 100);
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    final area = Uint8List.fromList(lensMask().coverage!);
    await applyFilter();
    final bent = await layerPixels();
    var changedInside = 0, changedElsewhere = 0;
    for (var p = 0; p < _size * _size; p++) {
      final i = p * 4;
      var changed = false;
      for (var c = 0; c < 4; c++) {
        if (bent[i + c] != original[i + c]) changed = true;
      }
      if (!changed) continue;
      if (area[p] > 0) {
        changedInside++;
      } else {
        changedElsewhere++;
      }
    }
    expect(changedInside, greaterThan(50), reason: 'the stripes bend');
    expect(changedElsewhere, 0, reason: 'nothing outside the lens area');
    await capture('06_lens_applied');
    expectSelectionEditing(true, 'after the glasses filter is applied');
    expect(tester.takeException(), isNull);
    // The lens area is forgotten with the panel.
    expect(tester.widget<CanvasArea>(canvasFinder).filterLensMask, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
