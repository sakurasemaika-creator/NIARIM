// 所有者の判断（2026-11-27）でキャンバスに足した・変えた動き。
//
// - フレーム一覧のコマを長押しすると、そのコマの複製・削除・保持セル数を選べる。
// - スマホのキャンバスは画面いっぱいに収め、上部バー・ツールバー・フレーム一覧は
//   その上に浮かべる（ツールを替えても紙は動かない）。
// - テキストツールで既にある文字を押すと編集、つかんで動かすと移動（取り消せる）。
//   新しい文字は、最後に確定した文字の書式で始まる。
// - 自作のブラシは設定のシートで名前を変えられる。
// - 手ぶれ補正はアプリの設定（どのブラシにも同じ強さ）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUp(() {
    docs = Directory.systemTemp.createTempSync('niarim_owner_1127_');
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => docs.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Opens a 320x320 work in the phone canvas (412x860).
  Future<(ProjectService, Project)> openCanvas(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    ProjectService? projects;
    StateSetter? rebuild;
    String? projectId;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) {
                projects ??= context.read<ProjectService>();
                rebuild = setState;
                if (projectId == null) return const SizedBox.expand();
                return CanvasScreen(projectId: projectId);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final project = (await tester.runAsync(
      () => projects!.createProject(
        name: 'owner decisions',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 320,
      ),
    ))!;
    projectId = project.id;
    rebuild!(() {});
    await tester.pump(const Duration(milliseconds: 1400));
    await settle(tester, 6);
    return (projects!, project);
  }

  String sceneOf(ProjectService ps, Project project) =>
      ps.scenesOf(project.id).first.id;

  testWidgets('long-pressing a frame offers duplicate, delete and hold', (
    tester,
  ) async {
    final (ps, project) = await openCanvas(tester);
    final scene = sceneOf(ps, project);
    final before = ps.frameCount(project.id, scene);

    Future<void> chooseOnCell(int index, Key item) async {
      final cell = find.byKey(ValueKey('frameStripCell$index'));
      await tester.longPress(cell);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('frameStripMenuDuplicate')), findsOneWidget);
      expect(find.byKey(const Key('frameStripMenuDelete')), findsOneWidget);
      expect(find.byKey(const Key('frameStripMenuHold')), findsOneWidget);
      await tester.tap(find.byKey(item));
      await tester.pumpAndSettle();
    }

    await chooseOnCell(0, const Key('frameStripMenuDuplicate'));
    expect(ps.frameCount(project.id, scene), before + 1);
    expect(
      tester
          .widget<FrameStripWidget>(find.byType(FrameStripWidget))
          .currentFrame,
      1,
      reason: 'moves to the copy to keep drawing on it',
    );

    await chooseOnCell(1, const Key('frameStripMenuDelete'));
    expect(ps.frameCount(project.id, scene), before);

    await chooseOnCell(0, const Key('frameStripMenuHold'));
    expect(find.text(l10n.frameStripHoldDialogTitle(1)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    await tester.tap(find.text(l10n.commonOk));
    await tester.pumpAndSettle();
    expect(ps.frameHold(project.id, scene, 0), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone canvas fills the screen under the floating bars', (
    tester,
  ) async {
    await openCanvas(tester);
    final screen = tester.getRect(find.byType(CanvasScreen));
    final canvas = tester.getRect(find.byType(CanvasArea));
    expect(canvas.top, closeTo(screen.top, 0.5));
    expect(canvas.bottom, closeTo(screen.bottom, 0.5));
    expect(canvas.width, closeTo(screen.width, 0.5));
    final toolbar = tester.getRect(find.byType(ToolbarWidget));
    final strip = tester.getRect(find.byType(FrameStripWidget));
    expect(canvas.contains(toolbar.center), isTrue);
    expect(canvas.contains(strip.center), isTrue);

    // Switching tools (text, lasso fill) never moves the paper.
    await tester.tap(find.byIcon(Icons.text_fields).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byType(CanvasArea)), canvas);
    expect(find.text('キャンバスをタップしてテキストを入力'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text: tap to edit, drag to move, new text keeps the format', (
    tester,
  ) async {
    final (ps, project) = await openCanvas(tester);
    final scene = sceneOf(ps, project);
    await tester.tap(find.byIcon(Icons.text_fields).first);
    await tester.pump(const Duration(milliseconds: 300));

    Offset screenOf(Offset canvasPx) {
      final area = tester.getRect(find.byType(CanvasArea));
      final drawing = canvasDrawingRectFor(area.size, project);
      final scale = drawing.width / 320;
      return area.topLeft + drawing.topLeft + canvasPx * scale;
    }

    // New text at (60, 60) with a bigger size.
    await tester.tapAt(screenOf(const Offset(60, 60)));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field.first, 'ABC');
    await tester.tap(find.text(l10n.commonOk));
    for (var i = 0; i < 30; i++) {
      await settle(tester, 1);
      if (find.byType(AlertDialog).evaluate().isEmpty) break;
    }
    expect(find.byType(AlertDialog), findsNothing);
    final textLayers = ps
        .layersOf(project.id, scene, 0)
        .where((l) => l.textObject != null)
        .toList();
    expect(textLayers, hasLength(1));
    final layer = textLayers.single;
    final tiles = ps.tileManagerOf(project.id);
    final bounds = tiles.contentBounds(
      ps.tileKeyFor(project.id, scene, 0, layer.id),
    )!;

    // Tapping the text opens it for editing.
    await tester.tapAt(screenOf(bounds.center));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(TextField, 'ABC'), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    // Dragging the text moves it by the dragged amount.
    final start = layer.textObject!.position;
    final gesture = await tester.startGesture(screenOf(bounds.center));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(screenOf(bounds.center + Offset(10.0 * i, 5.0 * i)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester, 20);
    expect(find.byType(AlertDialog), findsNothing, reason: 'a drag is no tap');
    final moved = ps
        .layersOf(project.id, scene, 0)
        .singleWhere((l) => l.id == layer.id)
        .textObject!
        .position;
    expect(moved.dx - start.dx, closeTo(80, 1.5));
    expect(moved.dy - start.dy, closeTo(40, 1.5));
    final movedBounds = tiles.contentBounds(
      ps.tileKeyFor(project.id, scene, 0, layer.id),
    )!;
    expect(movedBounds.left - bounds.left, closeTo(80, 2));

    // One undo puts it back.
    final undo = tester.element(find.byType(CanvasScreen)).read<UndoManager>();
    expect(undo.canUndo, isTrue);
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle(tester, 10);
    expect(
      ps
          .layersOf(project.id, scene, 0)
          .singleWhere((l) => l.id == layer.id)
          .textObject!
          .position,
      start,
    );

    // A new text starts from the last text's format (font size kept).
    await tester.tapAt(screenOf(const Offset(260, 280)));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'ABC'),
      findsNothing,
      reason: 'an empty spot starts a new text',
    );
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an own brush is renamed in its settings sheet', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    late BrushService brushes;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  brushes = context.read<BrushService>();
                  return DockedPanelScope(child: BrushPanel(onClose: () {}));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final id = brushes.duplicateBrush(
      brushes.brushes.first.id,
      name: '名前を変えるペン',
    )!;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('名前を変えるペン'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey(id));
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.creativePanelEditAction).last);
    await tester.pumpAndSettle();
    final name = find.byKey(const Key('brush-settings-name'));
    expect(name, findsOneWidget);
    await tester.enterText(name, '  わたしのペン  ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('brush-settings-save')));
    for (var i = 0; i < 10; i++) {
      await settle(tester, 1);
    }
    expect(brushes.brushes.singleWhere((b) => b.id == id).name, 'わたしのペン');
    expect(tester.takeException(), isNull);
  });

  test('stabilization is one app setting, kept and limited to 0-100', () async {
    final settings = SettingsService();
    await settings.init();
    expect(settings.strokeStabilization, 0);
    await settings.setStrokeStabilization(150);
    expect(settings.strokeStabilization, 100);
    await settings.setStrokeStabilization(40);
    final again = SettingsService();
    await again.init();
    expect(again.strokeStabilization, 40);
    settings.dispose();
    again.dispose();
  });

  test(
    'the app stabilization smooths every brush, the brush flag does not',
    () async {
      Future<int> rightmostInk(int strength, {required bool brushFlag}) async {
        final pen = BrushService.builtInBrushes.firstWhere(
          (b) => b.id == 'Brush0001',
        );
        final tiles = TileManager(canvasWidth: 256, canvasHeight: 64);
        final engine = DrawingEngine(tileManager: tiles)
          ..currentBrush = pen.copyWith(
            size: 4,
            opacity: 100,
            stabilization: brushFlag,
            stabilizationStrength: brushFlag ? 100 : 0,
          )
          ..currentColor = const ui.Color(0xFF000000)
          ..pressureEnabled = false
          ..stabilizationStrength = strength;
        engine.beginStroke(const StrokePoint(x: 10, y: 32), 'l');
        engine.continueStroke(const StrokePoint(x: 200, y: 32), 'l');
        engine.endStroke();
        final image = await tiles.compositeLayerToImage('l');
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();
        tiles.dispose();
        var right = -1;
        for (var x = 0; x < 256; x++) {
          if (data.getUint8((32 * 256 + x) * 4 + 3) > 0) right = x;
        }
        return right;
      }

      expect(await rightmostInk(0, brushFlag: false), greaterThan(190));
      expect(
        await rightmostInk(0, brushFlag: true),
        greaterThan(190),
        reason: 'the brush\'s own stabilization is no longer used',
      );
      expect(await rightmostInk(100, brushFlag: false), lessThan(80));
    },
  );
}
