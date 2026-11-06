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

    /// ハンドルの半径（キャンバスpx）。実装と同じく**画面px基準**なので、
    /// いまの描画エリアの拡大率で割り戻して求める
    /// （canvas_area.dartのselectionHandleRadiusFor）。
    double handleRadius() {
      final rect = tester.getRect(find.byType(CanvasArea));
      final scale = math.min(rect.width / exportSize, rect.height / exportSize);
      return kSelectionHandleScreenRadius / scale;
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
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '選択範囲ができたら画面下部に変形スライダーが出ること',
    );
    await capture('lasso_selected_with_handles');

    // 選択範囲(80,80)-(230,195)の中心は(155,137.5)。拡大縮小ハンドルは四隅、
    // 移動の十字矢印は中央、回転ハンドルは右上の外側。
    const cx = 155.0;
    const cy = 137.5;

    // ── 右上の回転ハンドルを掴んで+90°回す ───────────────────────────
    // 回転ハンドルは角から kSelectionRotateHandleGap 個ぶん斜めに離れている。
    final gap = handleRadius() * kSelectionRotateHandleGap;
    final rotateHandle = Offset(230 + gap, 80 - gap);
    final rotate = await tester.startGesture(
      at(rotateHandle.dx, rotateHandle.dy),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    // 中心から見たベクトル(v)を+90°回した(-v.dy, v.dx)の先へ運ぶ。
    final v = rotateHandle - const Offset(cx, cy);
    await rotate.moveTo(at(cx - v.dy, cy + v.dx));
    await tester.pump(const Duration(milliseconds: 50));
    await rotate.up();
    await settle();
    expect(
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '回転ハンドルの操作で選択範囲が消えていないこと',
    );
    await capture('rotated_by_handle');

    // ── 右下の角ハンドルを掴んで0.5倍に縮める ────────────────────────
    //
    // 回転で選択範囲の矩形も変わっている点に注意。中心(155,137.5)まわりに
    // +90°回したので、(80,80)-(230,195)は(97.5,62.5)-(212.5,212.5)になる
    // （(x,y)→(cx-(y-cy), cy+(x-cx))）。
    // 掴む位置がずれると新規選択の開始として扱われ、**選択範囲が黙って
    // 作り直される**（実際に一度これで空のPNGを撮った）ので、各操作のあとに
    // 選択範囲が残っていることを必ず確かめる。
    const rotatedRight = 212.5;
    const rotatedBottom = 212.5;
    final scale = await tester.startGesture(
      at(rotatedRight, rotatedBottom),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    await scale.moveTo(
      at(cx + (rotatedRight - cx) * 0.5, cy + (rotatedBottom - cy) * 0.5),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await scale.up();
    await settle();
    expect(
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '角ハンドルの操作で選択範囲が消えていないこと',
    );
    await capture('scaled_by_corner_handle');

    // ── 中央の十字矢印を掴んで動かす ─────────────────────────────────
    final move = await tester.startGesture(
      at(cx, cy),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await settle();
    await move.moveTo(at(cx - 45, cy + 50));
    await tester.pump(const Duration(milliseconds: 50));
    await move.up();
    await settle();
    expect(
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '中央の十字矢印の操作で選択範囲が消えていないこと',
    );
    await capture('moved_by_center_handle');

    // ── 全選択 ────────────────────────────────────────────────────────
    await tester.tap(find.text(l10n.canvasSelectAllButton));
    await settle();
    await capture('select_all');

    // ── 自由変形：四隅のハンドルと左下のキャンセル／適用だけになる ────
    await tester.tap(find.text(l10n.canvasSelectionFreeTransform));
    await settle();
    expect(
      find.byType(MeshTransformPanel),
      findsNothing,
      reason: '自由変形中は専用パネルを出さない（左下のキャンセル／適用のみ）',
    );
    expect(find.text(l10n.commonCancel), findsOneWidget);
    expect(find.text(l10n.meshTransformApplyButton), findsOneWidget);
    expect(
      find.text(l10n.meshTransformDensityLabel),
      findsNothing,
      reason: '自由変形（分割数1）では分割数スライダーを出さない',
    );
    await capture('free_transform');

    await tester.tap(find.text(l10n.commonCancel));
    await settle();

    // ── メッシュ変形：分割数スライダーが画面下部へ出る ────────────────
    await tester.ensureVisible(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.canvasSelectionMeshTransform));
    await settle();
    expect(
      find.text(l10n.meshTransformDensityLabel),
      findsOneWidget,
      reason: 'メッシュ変形では分割数スライダーを出すこと',
    );
    await capture('mesh_transform');

    await tester.tap(find.text(l10n.commonCancel));
    await settle();

    // ── 「変形適用（終了）」で選択ツールを抜ける ──────────────────────
    await tester.ensureVisible(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byIcon(Icons.highlight_alt).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.canvasSelectionApplyButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(ToolbarWidget),
      findsOneWidget,
      reason: '変形適用（終了）でツールバーが戻ること',
    );
    expect(find.byType(FrameStripWidget), findsOneWidget);
    await capture('applied_and_exited');
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
