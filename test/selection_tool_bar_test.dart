// 選択ツール使用中にキャンバス左下へ出る操作バーの検証。
//
// 独立していた「変形ツール」（DrawingTool.transform／ToolbarItemId.transform）は
// 選択範囲の変形と役割が重複していたため削除し、このバーの
// 「移動」「拡大縮小」「回転」モードボタンへ統合した。ツールバーから
// 変形ツールが消えたこと・バーの文言が7言語のARBから引かれていること
// （かつて「全選択」「全解除」がハードコードされていた）・バー表示中は
// ツールバーとフレーム一覧が畳まれることを、ここで機械的に見張る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/toolbar_item.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
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
  final out = Directory('build/visual-reaudit/canvas-panels');
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_selection_tool_bar_docs',
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

  test('ツールバーの選択肢から変形ツールが消えている', () {
    expect(
      ToolbarItemId.values.map((e) => e.name),
      isNot(contains('transform')),
      reason: '変形ツールは選択ツールの移動・拡大縮小・回転モードへ統合済み',
    );
  });

  test('選択ツールのバーの文言がハードコードされていない', () {
    final source = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();
    for (final literal in [
      "'全選択'",
      "'全解除'",
      "'自由変形'",
      "'メッシュ変形'",
      "'変形キャンセル'",
      "'変形適用'",
    ]) {
      expect(
        source.contains('Text($literal)'),
        isFalse,
        reason: '$literal がハードコードされている（l10nのキーを使うこと）',
      );
    }
  });

  testWidgets('選択ツールのバーが新仕様の2段構成で出て、ツールバーとフレーム一覧を畳む', (tester) async {
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
        name: 'selection-tool-bar',
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

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ToolbarWidget)),
    )!;

    // 選択ツールへ切り替える前はバー自体が出ておらず、ツールバーとフレーム
    // 一覧が出ている。
    expect(find.text(l10n.canvasSelectAllButton), findsNothing);
    expect(find.byType(FrameStripWidget), findsOneWidget);

    final selectTool = find.byIcon(Icons.highlight_alt);
    await tester.ensureVisible(selectTool.first);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(selectTool.first);
    await tester.pump(const Duration(milliseconds: 300));

    // 1段目：自由変形／メッシュ変形／変形キャンセル、2段目：全選択／全解除／変形適用。
    for (final label in [
      l10n.canvasSelectionFreeTransform,
      l10n.canvasSelectionMeshTransform,
      l10n.canvasSelectionRevertButton,
      l10n.canvasSelectAllButton,
      l10n.canvasDeselectAllButton,
      l10n.canvasSelectionApplyButton,
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label がバーに無い');
    }
    // 移動・拡大縮小・回転はボタンではなく、選択範囲のハンドルと
    // 画面下部のスライダーで行うのでバーには出ない。
    expect(find.byType(SelectionTransformSliders), findsNothing);
    // バーが出ている間はツールバーとフレーム一覧を畳む。
    expect(
      find.byType(ToolbarWidget),
      findsNothing,
      reason: '選択ツールのバー表示中はツールバーを畳むこと',
    );
    expect(
      find.byType(FrameStripWidget),
      findsNothing,
      reason: '選択ツールのバー表示中はフレーム一覧を畳むこと',
    );

    await tester.tap(find.text(l10n.canvasSelectAllButton));
    // 選択範囲のオーバーレイ画像生成は本物の非同期処理なので実時間で待つ。
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 選択範囲ができたら画面下部に変形量のスライダーが出る。
    expect(
      find.byType(SelectionTransformSliders),
      findsOneWidget,
      reason: '選択範囲があるときは変形スライダーを出すこと',
    );
    for (final label in [
      l10n.canvasSelectionSliderMoveX,
      l10n.canvasSelectionSliderMoveY,
      l10n.canvasSelectionSliderScale,
      l10n.canvasSelectionSliderRotate,
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label のスライダーが無い');
    }

    await tester.runAsync(
      () => _capture(rootKey, '${out.path}/20_selection_tool_bar.png'),
    );

    // 全解除でスライダーが引っ込む。
    await tester.tap(find.text(l10n.canvasDeselectAllButton));
    // 選択有無の通知はビルド中を避けてポストフレームへ回るので、
    // 反映にはpumpが2回要る。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SelectionTransformSliders), findsNothing);

    // 「変形適用（終了）」で選択ツールを抜け、ツールバーとフレーム一覧が戻る。
    await tester.tap(find.text(l10n.canvasSelectionApplyButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.canvasSelectAllButton), findsNothing);
    expect(
      find.byType(ToolbarWidget),
      findsOneWidget,
      reason: 'バーを閉じるとツールバーが戻ること（戻れないとツールを切り替えられない）',
    );
    expect(find.byType(FrameStripWidget), findsOneWidget);
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
