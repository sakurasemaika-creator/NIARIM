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
      "'移動'",
      "'回転'",
      "'拡大縮小'",
      "'自由変形'",
      "'メッシュ変形'",
    ]) {
      expect(
        source.contains('Text($literal)'),
        isFalse,
        reason: '$literal がハードコードされている（l10nのキーを使うこと）',
      );
    }
  });

  testWidgets('選択ツールのバーがモードボタンを出し、ツールバーとフレーム一覧を畳む', (tester) async {
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

    expect(find.text(l10n.canvasSelectAllButton), findsOneWidget);
    expect(find.text(l10n.canvasDeselectAllButton), findsOneWidget);
    // 選択範囲がまだ無いのでモードボタンは出ない（掴む対象が無い）。
    expect(find.text(l10n.canvasSelectionModeRotate), findsNothing);
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

    expect(find.text(l10n.canvasSelectionModeMove), findsOneWidget);
    expect(find.text(l10n.canvasSelectionModeScale), findsOneWidget);
    expect(find.text(l10n.canvasSelectionModeRotate), findsOneWidget);
    expect(find.text(l10n.canvasSelectionFreeTransform), findsOneWidget);
    expect(find.text(l10n.canvasSelectionMeshTransform), findsOneWidget);

    // 既定は「移動」。回転を押すとそちらが選択状態（差し色）になる。
    final scheme = Theme.of(
      tester.element(find.byType(CanvasScreen)),
    ).colorScheme;
    Color? modeColor(String label) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return (box.decoration as BoxDecoration?)?.color;
    }

    expect(modeColor(l10n.canvasSelectionModeMove), scheme.primary);
    expect(modeColor(l10n.canvasSelectionModeRotate), isNot(scheme.primary));

    await tester.tap(find.text(l10n.canvasSelectionModeRotate));
    await tester.pump(const Duration(milliseconds: 200));

    expect(modeColor(l10n.canvasSelectionModeRotate), scheme.primary);
    expect(modeColor(l10n.canvasSelectionModeMove), isNot(scheme.primary));

    await tester.runAsync(
      () => _capture(rootKey, '${out.path}/20_selection_tool_bar.png'),
    );

    // 全解除でモードボタンが引っ込む。
    await tester.tap(find.text(l10n.canvasDeselectAllButton));
    // 選択有無の通知はビルド中を避けてポストフレームへ回るので、
    // 反映にはpumpが2回要る。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l10n.canvasSelectionModeRotate), findsNothing);

    // 終了ボタンで選択ツールを抜け、ツールバーとフレーム一覧が戻る。
    await tester.tap(find.byTooltip(l10n.canvasSelectionExitTooltip));
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
