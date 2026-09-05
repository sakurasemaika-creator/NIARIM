// 選択ツールまわりを「実際に操作して」1枚ずつ撮り、意図どおりの画面に
// なっているかを目視監査できるようにするウォークスルー。
//
// 実機が無い環境なので、本番のCanvasScreenをそのまま載せてペンで描く→
// 範囲を囲む→モードを切り替えて変形する→自由変形を開く→選択ツールを
// 抜ける、までを実タップ・実ドラッグで通し、各段階のPNGを
// build/selection-walkthrough/へ焼く。テストが緑でも見た目の不具合は
// 残るので、焼いたPNGは必ず目で見ること。
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
import 'package:niarim/screens/canvas/widgets/mesh_transform_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/selection-walkthrough');
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_selection_walkthrough_docs',
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

  testWidgets('選択ツールの一連の操作を実タップ・実ドラッグで通して各段階を撮る', (tester) async {
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

    final project = (await tester.runAsync(
      () => ps!.createProject(
        name: 'selection-walkthrough',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 320,
      ),
    ))!;
    projectId = project.id;
    rebuildHost!(() {});
    await tester.pump(const Duration(milliseconds: 1400));

    // 実時間の非同期（合成画像・浮動画像の生成）を進めてから撮る。
    Future<void> settle([int rounds = 10]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
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

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ToolbarWidget)),
    )!;

    await capture('default');

    // ── ペンで線を描く（変形の結果が目で分かるようにするため） ────────
    //
    // 座標はウィジェットの割合ではなく**プロジェクトのピクセル座標**で
    // 指定する。描画エリアはCanvasAreaの中央にアスペクト比フィットで
    // 置かれるため、ウィジェットの割合で指定すると狙った位置からずれ、
    // 拡大縮小・回転の量も計算どおりにならない
    // （canvas_area.dartのcanvasDrawingRectFor()と同じ計算）。
    //
    // なお選択ツールへ入るとツールバー・フレーム一覧が畳まれてキャンバスが
    // 縦に広がるため、**呼ぶたびに現在のCanvasAreaの矩形から計算し直す**
    // （一度キャッシュすると、畳まれた後に狙った位置からずれる）。
    const exportSize = 320.0;
    // 左右端32px（画面端ダブルタップ専用ゾーン）に入らないよう、
    // 指定するxはウィジェット座標で32〜(幅-32)の内側に収めること。
    Offset at(double x, double y) {
      final rect = tester.getRect(find.byType(CanvasArea));
      final scale = math.min(rect.width / exportSize, rect.height / exportSize);
      final origin = Offset(
        rect.left + (rect.width - exportSize * scale) / 2,
        rect.top + (rect.height - exportSize * scale) / 2,
      );
      return origin + Offset(x * scale, y * scale);
    }

    // ストロークの実画素化は本物の非同期処理なので、1点動かすごとに
    // 実時間を進める（FakeAsyncのままだと最初の点しか描かれない）。
    // ジェスチャー自体はrunAsyncの外で駆動する（runAsyncはネストできない）。
    final pen = await tester.startGesture(
      at(96, 112),
      kind: PointerDeviceKind.touch,
    );
    for (final p in [
      at(112, 100),
      at(128, 96),
      at(144, 116),
      at(160, 136),
      at(176, 116),
      at(192, 100),
      at(205, 124),
      at(218, 148),
      at(198, 164),
      at(176, 180),
      at(147, 172),
      at(122, 160),
    ]) {
      await pen.moveTo(p);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await pen.up();
    await settle();
    await capture('drawn_with_pen');

    // ── 選択ツールへ切り替える ────────────────────────────────────────
    final selectTool = find.byIcon(Icons.highlight_alt);
    await tester.ensureVisible(selectTool.first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(selectTool.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byType(ToolbarWidget),
      findsNothing,
      reason: 'バー表示中はツールバーを畳むこと',
    );
    expect(find.byType(FrameStripWidget), findsNothing);
    await capture('select_tool_active');

    // ── 投げ縄で描いた線の一部を囲む ─────────────────────────────────
    final lasso = await tester.startGesture(
      at(80, 80),
      kind: PointerDeviceKind.touch,
    );
    for (final p in [at(230, 80), at(230, 195), at(80, 195), at(80, 82)]) {
      await lasso.moveTo(p);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await lasso.up();
    await settle();
    expect(
      find.text(l10n.canvasSelectionModeMove),
      findsOneWidget,
      reason: '選択範囲ができたらモードボタンが出ること',
    );
    await capture('lasso_selected');

    // ── 回転モードでドラッグする ──────────────────────────────────────
    await tester.tap(find.text(l10n.canvasSelectionModeRotate));
    await tester.pump(const Duration(milliseconds: 200));
    await capture('rotate_mode_selected');

    // 選択範囲(80,80)-(230,195)の中心は(155,137.5)。そこから見て
    // 真上(155,90)を掴み、真右(202.5,137.5)へ動かす＝ちょうど+90°回転。
    //
    // 掴む位置は選択範囲の内側（拡大縮小・回転では枠を少し広げた範囲）で
    // ないと、新規選択の開始として扱われて選択範囲が作り直されてしまう。
    final rotate = await tester.startGesture(
      at(155, 90),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    await rotate.moveTo(at(202.5, 137.5));
    await tester.pump(const Duration(milliseconds: 50));
    await rotate.up();
    await settle();
    await capture('rotated');

    // ── 全選択 → 拡大縮小モードで縮める ──────────────────────────────
    await tester.tap(find.text(l10n.canvasSelectAllButton));
    await settle();
    await capture('select_all');

    await tester.tap(find.text(l10n.canvasSelectionModeScale));
    await tester.pump(const Duration(milliseconds: 200));
    // 全選択なので中心は(160,160)。中心からの距離が半分になる位置まで
    // ドラッグする＝ちょうど0.5倍に縮小される。
    final scale = await tester.startGesture(
      at(260, 260),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    await scale.moveTo(at(210, 210));
    await tester.pump(const Duration(milliseconds: 50));
    await scale.up();
    await settle();
    await capture('scaled_down');

    // ── 移動モードで動かす ────────────────────────────────────────────
    await tester.tap(find.text(l10n.canvasSelectionModeMove));
    await tester.pump(const Duration(milliseconds: 200));
    final move = await tester.startGesture(
      at(160, 160),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    await move.moveTo(at(105, 215));
    await tester.pump(const Duration(milliseconds: 50));
    await move.up();
    await settle();
    await capture('moved');

    // ── 全解除でモードボタンが引っ込む ────────────────────────────────
    await tester.tap(find.text(l10n.canvasDeselectAllButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text(l10n.canvasSelectionModeMove),
      findsNothing,
      reason: '全解除で変形モードのボタンが引っ込むこと',
    );
    await capture('deselected');

    // もう一度囲み直してから自由変形を開く。
    final lasso2 = await tester.startGesture(
      at(80, 80),
      kind: PointerDeviceKind.touch,
    );
    for (final p in [at(230, 80), at(230, 195), at(80, 195), at(80, 82)]) {
      await lasso2.moveTo(p);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await lasso2.up();
    await settle();

    // ── 自由変形を開く ────────────────────────────────────────────────
    await tester.tap(find.text(l10n.canvasSelectionFreeTransform));
    await settle();
    expect(
      find.byType(MeshTransformPanel),
      findsOneWidget,
      reason: '自由変形ボタンから自由変形・メッシュ変形パネルが開くこと',
    );
    await capture('free_transform_panel');

    // パネルを閉じる（キャンセル）とペンへ戻る。
    await tester.tap(find.text(l10n.commonCancel).last);
    await settle();
    await capture('mesh_cancelled');

    // ── もう一度選択ツールへ入り、終了ボタンで抜ける ─────────────────
    await tester.ensureVisible(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip(l10n.canvasSelectionExitTooltip));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(ToolbarWidget),
      findsOneWidget,
      reason: '終了ボタンでツールバーが戻ること',
    );
    expect(find.byType(FrameStripWidget), findsOneWidget);
    await capture('exited_back_to_toolbar');
  });
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
}
