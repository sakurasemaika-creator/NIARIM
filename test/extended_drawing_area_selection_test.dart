import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/screens/canvas/widgets/selection_transform_sliders.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/extended-area-walkthrough');
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_extended_area_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    out.createSync(recursive: true);
    appDocs.createSync(recursive: true);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => appDocs.path,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('拡張描画範囲ONでも、タップ位置と実際に描かれる位置が一致する', (tester) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final providers = (await tester.runAsync(buildAppProviders))!;
    ProjectService? ps;
    StateSetter? rebuildHost;
    String? projectId;
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(
          providers: providers,
          child: Builder(
            builder: (themeContext) => MaterialApp(
              theme: themeContext.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: StatefulBuilder(
                builder: (context, setState) {
                  ps ??= context.read<ProjectService>();
                  rebuildHost = setState;
                  if (projectId == null) return const SizedBox.expand();
                  return CanvasScreen(projectId: projectId);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 書き出し320x320・描画領域倍率2.0＝描画範囲640x640。
    final project = (await tester.runAsync(
      () => ps!.createProject(
        name: 'extended-area',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 320,
        drawingAreaScale: 2.0,
      ),
    ))!;
    projectId = project.id;
    rebuildHost!(() {});
    await tester.pump(const Duration(milliseconds: 1400));

    expect(project.drawingWidth, 640);
    expect(project.drawingHeight, 640);
    final tm = ps!.tileManagerOf(project.id);
    expect(tm.canvasWidth, 640, reason: 'タイルは描画範囲ぶんの大きさ');

    Future<void> settle([int rounds = 10]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // 実装(canvasDrawingRectFor)と同じ計算で、描画範囲のピクセル座標を
    // ウィジェット座標へ直す。拡張ONのときの描画エリアは「描画範囲を
    // アスペクト比フィットさせた矩形」であるべき、という前提で書く。
    final drawSize = project.drawingWidth.toDouble();
    Offset at(double x, double y) {
      final rect = tester.getRect(find.byType(CanvasArea));
      final scale = math.min(rect.width / drawSize, rect.height / drawSize);
      final origin = Offset(
        rect.left + (rect.width - drawSize * scale) / 2,
        rect.top + (rect.height - drawSize * scale) / 2,
      );
      return origin + Offset(x * scale, y * scale);
    }

    var shot = 0;
    Future<void> capture(String name) async {
      await settle(6);
      await tester.runAsync(
        () => _capture(
          rootKey,
          '${out.path}/${shot.toString().padLeft(2, '0')}_$name.png',
        ),
      );
      shot++;
    }

    await capture('extended_default');

    // ── ペンで線を描く ────────────────────────────────────────────────
    // 描画範囲の中心(320,320)を通る線。書き出し範囲（中央160..480）の外まで
    // はみ出させて、拡張範囲側にもちゃんと描けることを見えるようにする。
    final pen = await tester.startGesture(
      at(85, 320),
      kind: PointerDeviceKind.touch,
    );
    // 手ぶれ補正（スタビライザ）が入っているため、尖った1点だけ遠くへ
    // 飛ばすと丸められて消える。端まで届かせたいときは点を密に置くこと。
    for (final p in [
      const Offset(200, 230),
      const Offset(260, 210),
      const Offset(320, 200),
      const Offset(380, 210),
      const Offset(440, 230),
      const Offset(500, 265),
      const Offset(540, 300),
      const Offset(555, 320),
      const Offset(540, 345),
      const Offset(500, 380),
      const Offset(440, 410),
      const Offset(380, 430),
      const Offset(320, 440),
      const Offset(260, 430),
      const Offset(200, 410),
      const Offset(140, 375),
      const Offset(100, 340),
      const Offset(88, 320),
    ]) {
      await pen.moveTo(at(p.dx, p.dy));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await pen.up();
    await settle();
    debugPrint('canvasRect=${tester.getRect(find.byType(CanvasArea))}');
    debugPrint('at(520,320)=${at(520, 320)} at(120,320)=${at(120, 320)}');
    await capture('drawn_across_export_border');

    // ── タップ位置と実際に描かれた位置が一致しているか実画素で確かめる ──
    final scene = ps!.scenesOf(project.id).first;
    final layerId = scene.frames.first.layers.first.id;
    final key = ps!.tileKeyFor(project.id, scene.id, 0, layerId);
    final img = (await tester.runAsync(() => tm.compositeLayerToImage(key)))!;
    final bytes = (await tester.runAsync(() => img.toByteData()))!;
    final rgba = bytes.buffer.asUint8List();
    int alphaAt(int x, int y) => rgba[(y * img.width + x) * 4 + 3];

    expect(img.width, 640, reason: 'レイヤー画像は描画範囲ぶんの大きさ');

    var sx = 0, sy = 0, n = 0, minX = img.width, maxX = 0;
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        if (alphaAt(x, y) > 0) {
          sx += x;
          sy += y;
          n++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
    }
    img.dispose();
    expect(n, greaterThan(0), reason: '線が実画素として残っていること');
    final cx = sx / n, cy = sy / n;
    debugPrint('ink=$n centroid=$cx,$cy xRange=$minX..$maxX');

    // 描いた線は描画範囲の中心(320,320)を中心に左右対称なので、重心も
    // そこへ来るはず。座標変換が書き出しサイズ基準（＝旧実装）だと
    // drawingAreaScale倍ずれて(160,160)付近になる。
    expect(cx, closeTo(320, 40), reason: 'タップ位置と描画位置が一致すること');
    expect(cy, closeTo(320, 40), reason: 'タップ位置と描画位置が一致すること');
    // 書き出し範囲（中央160..480）の外側にも描けていること。
    expect(minX, lessThan(160), reason: '書き出し範囲の左外にも描けること');
    expect(maxX, greaterThan(480), reason: '書き出し範囲の右外にも描けること');

    // ── 選択ツールへ切り替えて、拡張範囲まで含めて囲む ────────────────
    final selectTool = find.byIcon(Icons.highlight_alt);
    await tester.ensureVisible(selectTool.first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(selectTool.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ToolbarWidget), findsNothing);
    expect(find.byType(FrameStripWidget), findsNothing);
    await capture('select_tool_active');

    final lasso = await tester.startGesture(
      at(100, 200),
      kind: PointerDeviceKind.touch,
    );
    for (final p in [
      const Offset(540, 200),
      const Offset(540, 440),
      const Offset(100, 440),
      const Offset(100, 202),
    ]) {
      await lasso.moveTo(at(p.dx, p.dy));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await lasso.up();
    await settle();
    expect(
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '拡張描画範囲ONでも選択範囲ができたら変形スライダーが出ること',
    );
    await capture('lasso_across_export_border');

    // ── 右上の回転ハンドルを掴んで回す ────────────────────────────────
    double handleRadius() {
      final rect = tester.getRect(find.byType(CanvasArea));
      final scale = math.min(rect.width / drawSize, rect.height / drawSize);
      return kSelectionHandleScreenRadius / scale;
    }

    const selection = Rect.fromLTRB(100, 200, 540, 440);
    final r = handleRadius();
    final handle = selectionRotateHandleOf(selection, r);
    final rotate = await tester.startGesture(
      at(handle.dx, handle.dy),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    final v = handle - selection.center;
    await rotate.moveTo(
      at(selection.center.dx - v.dy, selection.center.dy + v.dx),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await rotate.up();
    await settle();
    expect(
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '回転しても選択範囲は保たれること（掴み損ねると選択が消える）',
    );
    await capture('rotated_by_handle');

    // ── 全選択：拡張範囲まで含めて選ばれること ────────────────────────
    final l10n = AppLocalizations.of(tester.element(find.byType(CanvasArea)))!;
    await tester.tap(find.text(l10n.canvasSelectAllButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await settle();
    expect(find.byType(SelectionTransformSliders), findsOneWidget);
    await capture('select_all_extended');
  });
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}
