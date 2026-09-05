import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/mesh_transform_panel.dart';
import 'package:niarim/screens/canvas/widgets/onion_skin_panel.dart';
import 'package:niarim/screens/canvas/widgets/quick_tool_panel.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/screens/canvas/widgets/panel_close_bar.dart';
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
    '${Directory.systemTemp.path}/niarim_canvas_panel_audit_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    out.createSync(recursive: true);
    appDocs.createSync(recursive: true);
  });

  setUp(() {
    // 初回タップ吹き出しを全て「表示済み」にしておく。
    //
    // FirstUseTooltipは吹き出し表示中に画面全体を覆う透明バリア
    // （どこをタップしても閉じられるようにするためのもの）をOverlayへ
    // 敷く。ツールバーの定規・クイックツール等がこの吹き出し対象なので、
    // 素の状態だと「あるボタンを押す→吹き出しが出る→次の操作がバリアに
    // 吸われて何も起きない」となり、パネルが開かない失敗になる
    // （実際にQuickToolPanelがこれで0件になっていた）。
    // 吹き出し自体は別のテストで検証しており、ここはパネルの見た目を
    // 撮るテストなので出さない状態を前提にする。
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getTemporaryDirectory':
              return appDocs.path;
            default:
              return appDocs.path;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('実CanvasScreenの主要オーバーレイパネルを実操作で開いてPNG保存する', (tester) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 同梱フォントに加えてMaterialアイコンも読み込む。アイコンを
    // 読み込まないと、撮ったPNGのアイコンが全て豆腐（□）になり
    // 「どのボタンがどう並んでいるか」を目視できない。
    await loadAppFonts(tester);

    final providers = await tester.runAsync(buildAppProviders);
    final providerList = providers!;
    ProjectService? ps;
    StateSetter? rebuildHost;
    String? projectId;
    final rootKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(
          providers: providerList,
          child: Builder(
            builder: (themeContext) => MaterialApp(
              // アプリ本体のテーマを必ず適用する。付けないとFlutter既定の
              // テーマ（Roboto・M3の既定配色）で描かれてしまい、**同梱
              // フォントも配色も本番と違うPNG**が撮れる。実際に日本語の
              // ボタンラベルが全て豆腐（□）になっていた。
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
    expect(ps, isNotNull, reason: '本番ProviderツリーからProjectServiceを取得できること');

    final project = (await tester.runAsync(
      () => ps!.createProject(
        name: 'panel-visual-audit',
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
    _expectNoException(tester, 'CanvasScreen initial');

    Future<void> capture(String file) async {
      // 読み込み中（ぐるぐる）のまま撮ると、その画面は目視監査に
      // ならない。プレビューの生成などは本物の非同期処理なので、
      // 待ちは必ずrunAsyncの中で行う（FakeAsyncの下ではpumpを何回
      // 回しても完了しない）。
      for (var i = 0; i < 12; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() => _capture(rootKey, '${out.path}/$file.png'));
    }

    await capture('00_canvas_default');

    // ツールバーは横スクロールするSingleChildScrollViewで、狭い画面
    // （このテストは論理320px幅）では右側のボタンが表示範囲の外にある。
    // 座標がビューポート外だとタップはヒットテストに当たらず、ボタンが
    // 反応しないまま「パネルが開かない」という失敗になる（実際にこれで
    // BrushPanelが0件になっていた）。タップ前に必ず可視位置へ送る。
    Future<void> revealInToolbar(Finder finder) async {
      try {
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 120));
      } on StateError {
        // Scrollableの中に無いコントロール（オーバーレイ上のボタン等）は
        // スクロール不要なのでそのままタップする。
      }
    }

    // オーバーレイパネルは画面左側へ縦いっぱいに開くため、この画面幅
    // （論理320x720）ではツールバー（y=588..628）を覆ってしまう。開いた
    // ままだと次のツールバー操作がパネル側に吸われてボタンが反応しない。
    // 実際の操作と同じく、次を開く前に今開いているパネルを閉じる。
    Future<void> closeOpenPanel() async {
      final closeBar = find.byType(PanelCenterCloseBar);
      if (closeBar.evaluate().isEmpty) return;
      await tester.tap(closeBar.first);
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 設定シートは項目が縦に長く、この画面（論理320x720）では下の方の
    // 項目が画面外にある。座標が画面外だとタップがヒットテストに当たらず、
    // 項目が反応しないまま失敗する。シート内の項目も送ってからタップする。
    Future<void> tapInSheet(Finder finder) async {
      expect(finder, findsWidgets);
      await revealInToolbar(finder.last);
      await tester.tap(finder.last);
      // シートは`Navigator.pop`で閉じるが、退場アニメーションが終わって
      // ツリーから外れるまでに数フレームかかる。待たずに撮ると
      // **開いたパネルの上にシートが被ったPNG**になり、肝心のパネルが
      // ほとんど見えない（オニオンスキン・フィルター・メッシュ変形の
      // 3枚が実際にそうなっていた）。シートが消えるまで進める。
      for (var i = 0; i < 20; i++) {
        if (find.byType(BottomSheet).evaluate().isEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // 設定シートを開く。直前に開いたパネルがツールバーを覆っていると
    // 歯車ボタンのタップがパネル側に吸われるため、必ず閉じてから開く。
    Future<void> openSettingsSheet() async {
      await closeOpenPanel();
      await revealInToolbar(find.byIcon(Icons.settings).first);
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> tapPanel({
      required Finder control,
      required Type panelType,
      required String file,
      bool longPress = false,
    }) async {
      await closeOpenPanel();
      expect(control, findsWidgets, reason: '$file control exists');
      await revealInToolbar(control.first);
      if (longPress) {
        await tester.longPress(control.first);
      } else {
        await tester.tap(control.first);
      }
      await tester.pump(const Duration(milliseconds: 500));
      _expectNoException(tester, file);
      expect(
        find.byType(panelType),
        findsOneWidget,
        reason: '$file panel opened from real CanvasScreen control',
      );
      await capture(file);
    }

    final colorControl = find.descendant(
      of: find.byType(ToolbarWidget),
      matching: find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.child is Stack,
        description: 'toolbar color GestureDetector',
      ),
    );
    expect(colorControl, findsOneWidget);
    await revealInToolbar(colorControl);
    await tester.tap(colorControl);
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'color_picker');
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    await capture('01_color_picker');

    await tapPanel(
      control: find.byIcon(Icons.tune),
      panelType: BrushPanel,
      file: '02_brush_panel',
    );
    expect(find.byType(ColorPickerPanel), findsNothing);
    await tapPanel(
      control: find.byIcon(Icons.layers),
      panelType: LayerPanel,
      file: '03_layer_panel',
    );
    await tapPanel(
      control: find.byIcon(Icons.straighten),
      panelType: RulerPanel,
      file: '04_ruler_panel',
    );
    await tapPanel(
      control: find.byIcon(Icons.loop),
      panelType: QuickToolPanel,
      file: '05_quick_tool_panel',
      longPress: true,
    );

    await openSettingsSheet();
    _expectNoException(tester, 'settings_edit_sheet');
    expect(find.byType(BottomSheet), findsWidgets);
    await capture('06_settings_edit_sheet');

    await tapInSheet(find.byIcon(Icons.layers_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'onion_skin_panel');
    expect(find.byType(OnionSkinPanel), findsOneWidget);
    await capture('07_onion_skin_panel');

    await openSettingsSheet();
    await tapInSheet(find.byIcon(Icons.blur_on));
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'filter_panel');
    expect(find.byType(FilterPanel), findsOneWidget);
    await capture('08_filter_panel');

    await openSettingsSheet();
    await tapInSheet(find.byIcon(Icons.crop_free));
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'mesh_transform_panel');
    // スマホ幅では自由変形・メッシュ変形の専用パネルを出さない（パネルが
    // キャンバスを覆って格子点を掴めなくなるため）。代わりにキャンバス左下の
    // キャンセル／適用だけを出し、格子点の操作に画面を明け渡す。
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CanvasScreen)),
    )!;
    expect(
      find.byType(MeshTransformPanel),
      findsNothing,
      reason: 'スマホ幅では自由変形・メッシュ変形の専用パネルを出さないこと',
    );
    expect(find.text(l10n.commonCancel), findsOneWidget);
    expect(find.text(l10n.meshTransformApplyButton), findsOneWidget);
    await capture('09_mesh_transform_panel');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

void _expectNoException(WidgetTester tester, String operation) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: '$operation visual panel must not overflow/throw',
  );
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  image.dispose();
}
