import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/brush_size_slider.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/editable_slider_value.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 本物のキャンバスの太さ・不透明度の欄で変えた値が、ブラシごとに残る
/// （別のブラシへ切り替えて戻る・起動し直す・ブラシの一覧）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_brush_memory_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the canvas size and opacity fields are remembered per brush', (
    tester,
  ) async {
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final projects = home.read<ProjectService>();
    final brushes = home.read<BrushService>();
    late String id;
    await tester.runAsync(() async {
      final project = await projects.createProject(
        name: 'brush memory',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    brushes.selectBrush('Brush0002');
    final defaultSize = brushes.currentBrush!.size;
    final otherSize = brushes.brushes
        .firstWhere((b) => b.id == 'Brush0001')
        .size;
    appRouter.push('/canvas/$id');
    await settle(tester, 12);

    BrushSizeSlider slider() =>
        tester.widget<BrushSizeSlider>(find.byType(BrushSizeSlider));
    expect(slider().brushSize, defaultSize);

    // 欄を開いて、太さと不透明度の数字を直接打つ。
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BrushSizeSlider)),
    )!;
    await tester.tap(find.text(l10n.canvasBrushSliderToggleLabel));
    await tester.pump(const Duration(milliseconds: 200));
    Future<void> enter(int field, String text) async {
      await tester.tap(
        find
            .descendant(
              of: find.byType(BrushSizeSlider),
              matching: find.byType(EditableSliderValue),
            )
            .at(field),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await enter(0, '42');
    await enter(1, '35');
    expect(slider().brushSize, 42);
    expect(slider().opacity, 35);
    expect(brushes.currentBrush!.size, 42);

    // 別のブラシへ切り替えるとそのブラシの値、戻ると覚えた値。
    brushes.selectBrush('Brush0001');
    await tester.pump();
    expect(slider().brushSize, otherSize);
    brushes.selectBrush('Brush0002');
    await tester.pump();
    expect(slider().brushSize, 42, reason: '戻ると覚えた太さ');
    expect(slider().opacity, 35);
    expect(tester.takeException(), isNull);

    // 一覧で選ぶ・早替えツールは、同じフレームでこの画面も作り直す
    // （一覧を閉じるsetState）。そのときも欄は選んだブラシの値になる
    // （以前は前のブラシの値のまま残り、そこから±を押すと別のブラシの
    // 値として覚えた）。
    void selectWithRebuild(String id) {
      brushes.selectBrush(id);
      // ignore: invalid_use_of_protected_member
      tester.state(find.byType(CanvasScreen)).setState(() {});
    }

    selectWithRebuild('Brush0001');
    await tester.pump();
    expect(slider().brushSize, otherSize, reason: '同じフレームの作り直しでも追従する');
    expect(slider().opacity, isNot(35));
    selectWithRebuild('Brush0002');
    await tester.pump();
    expect(slider().brushSize, 42);
    expect(slider().opacity, 35);
    // 早替えツールが一時的に当てる太さも欄に出る。
    brushes.updateCurrentBrushSize(120, remember: false);
    // ignore: invalid_use_of_protected_member
    tester.state(find.byType(CanvasScreen)).setState(() {});
    await tester.pump();
    expect(slider().brushSize, 120);
    brushes.selectBrush('Brush0001');
    brushes.selectBrush('Brush0002');
    await tester.pump();
    expect(slider().brushSize, 42, reason: '一時的な太さは覚えない');

    // 数字を確定した時点で保存され、起動し直しても同じ。
    await settle(tester, 2);
    final prefs = await SharedPreferences.getInstance();
    final working =
        jsonDecode(prefs.getString('brush_builtin_working_values')!)
            as Map<String, dynamic>;
    expect(working['Brush0002'], {'size': 42.0, 'opacity': 35});
    final again = BrushService();
    await tester.runAsync(again.init);
    expect(again.currentBrush!.id, 'Brush0002');
    expect(again.currentBrush!.size, 42);
    expect(again.currentBrush!.opacity, 35);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the brush list shows the remembered values', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BrushPanel(onClose: () {})),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(BrushPanel));
    final brushes = context.read<BrushService>();
    final l10n = AppLocalizations.of(context)!;
    Finder row(String brushId) => find.descendant(
      of: find.byKey(ValueKey(brushId)),
      matching: find.byType(Text),
    );
    String subtitle(String brushId) =>
        tester.widgetList<Text>(row(brushId)).last.data!;

    brushes.selectBrush('Brush0002');
    brushes.updateCurrentBrushSize(77);
    brushes.updateCurrentBrushOpacity(12);
    await tester.pump();
    expect(subtitle('Brush0002'), l10n.penSubToolBrushSizeOpacity(77, 12));

    // 別のブラシを使っている間も、一覧には覚えた値が出る。
    brushes.selectBrush('Brush0001');
    await tester.pump();
    expect(subtitle('Brush0002'), l10n.penSubToolBrushSizeOpacity(77, 12));

    // 早替えツールが一時的に当てた太さは、使っている間だけ出る。
    brushes.selectBrush('Brush0002');
    brushes.updateCurrentBrushSize(200, remember: false);
    await tester.pump();
    expect(subtitle('Brush0002'), l10n.penSubToolBrushSizeOpacity(200, 12));
    brushes.selectBrush('Brush0001');
    await tester.pump();
    expect(subtitle('Brush0002'), l10n.penSubToolBrushSizeOpacity(77, 12));

    // 覚えた値のある組み込みブラシだけ、メニューから既定へ戻せる。
    Future<void> openMenu(String brushId) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(brushId)),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openMenu('Brush0003');
    expect(find.text(l10n.brushPanelResetRememberedValues), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await openMenu('Brush0002');
    await tester.tap(find.text(l10n.brushPanelResetRememberedValues));
    await tester.pumpAndSettle();
    final definition = BrushService();
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await definition.init();
    });
    final original = definition.brushes.firstWhere((b) => b.id == 'Brush0002');
    expect(
      subtitle('Brush0002'),
      l10n.penSubToolBrushSizeOpacity(original.size.round(), original.opacity),
    );
    await openMenu('Brush0002');
    expect(find.text(l10n.brushPanelResetRememberedValues), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // 選んだ行の先頭のアイコンは、選択色の上の文字色（選択色と同じ色の
    // 差し色を直接渡していて、既定のテーマで見えなかった）。
    final icon = find.descendant(
      of: find.byKey(const ValueKey('Brush0001')),
      matching: find.byIcon(Icons.brush),
    );
    final iconContext = tester.element(icon);
    final tiles = Theme.of(iconContext).listTileTheme;
    final drawn =
        tester.widget<Icon>(icon).color ?? IconTheme.of(iconContext).color;
    expect(drawn, tiles.selectedColor);
    expect(drawn, isNot(tiles.selectedTileColor));
    expect(tester.takeException(), isNull);
  });

  test('list rows leave the leading icon colour to the list tile', () {
    for (final name in [
      'brush_panel',
      'pen_sub_tool_panel',
      'stamp_panel',
      'tone_panel',
    ]) {
      final source = File(
        'lib/screens/canvas/widgets/$name.dart',
      ).readAsStringSync();
      expect(
        RegExp(
          r'leading:\s*(const\s+)?Icon\([^;]*?isSelected[^;]*?AccentTextTheme',
          dotAll: true,
        ).hasMatch(source),
        isFalse,
        reason: name,
      );
    }
  });
}
