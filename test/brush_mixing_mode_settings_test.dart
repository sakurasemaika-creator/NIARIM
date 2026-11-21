// ブラシカスタムの混色モード（デジタル・油彩風混色・水彩風混色）を本番の
// ブラシ設定シートで実際に切り替え、モードごとのスライダーが出ること・
// ぼかし半径・ふち滲みがスライダーだけで変えられること・
// 保存した値がブラシに残ることを確かめる。各モードの画面は
// build/brush-mixing/settings_*.png へ焼く。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_brush_mixing_settings_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    appDocs.createSync(recursive: true);
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async {
          return appDocs.path;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('デジタル・油彩風混色・水彩風混色を選ぶとそれぞれのスライダーが出て保存される', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final providers = (await tester.runAsync(buildAppProviders))!;
    final shotKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => RepaintBoundary(
            key: shotKey,
            child: MaterialApp(
              theme: themeContext.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: BrushPanel(onClose: () {})),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(BrushPanel));
    final brushes = context.read<BrushService>();
    // 筆圧OFFの設定を最初に開いた状態にする。
    await tester.runAsync(
      () => context.read<SettingsService>().setPenPressureEnabled(false),
    );
    // 組み込みブラシは長押しで開かないので、複製した自作ブラシを編集する。
    final before = brushes.brushes.map((b) => b.id).toSet();
    brushes.duplicateBrush('Brush0001');
    final copy = brushes.brushes.firstWhere((b) => !before.contains(b.id));
    await tester.pump();

    final tile = find.text(copy.name);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.longPress(tile);
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
      final boundary =
          shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final dir = Directory('build/brush-mixing')
          ..createSync(recursive: true);
        File('${dir.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> choose(String label) async {
      final radio = find.widgetWithText(RadioListTile<BrushMixingMode>, label);
      await tester.ensureVisible(radio.last);
      await tester.pumpAndSettle();
      await tester.tap(radio.last);
      await tester.pumpAndSettle();
    }

    // 混色の設定はシートの下の方（筆圧ON・OFFの各セクション）にある。
    final sheetScroll = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('筆圧OFF'),
      300,
      scrollable: sheetScroll,
    );
    await tester.pumpAndSettle();
    // 筆圧OFFのセクションが開いていて、混色の選択肢がある（筆圧ONは閉じている）。
    for (final label in ['デジタル', '油彩風混色', '水彩風混色']) {
      await tester.scrollUntilVisible(
        find.widgetWithText(RadioListTile<BrushMixingMode>, label),
        200,
        scrollable: sheetScroll,
      );
    }
    for (final label in ['デジタル', '油彩風混色', '水彩風混色']) {
      expect(
        find.widgetWithText(RadioListTile<BrushMixingMode>, label),
        findsOneWidget,
      );
    }
    // 旧「にじみ」モードは無い（にじみは水彩風混色のスライダー）。
    expect(
      find.widgetWithText(RadioListTile<BrushMixingMode>, 'にじみ'),
      findsNothing,
    );

    await choose('油彩風混色');
    expect(find.text('混色度合い'), findsWidgets);
    expect(find.text('色延び'), findsOneWidget);
    expect(find.text('輝度の補正'), findsOneWidget);
    expect(find.text('水分量'), findsNothing);
    await tester.ensureVisible(find.text('色延び'));
    await tester.pumpAndSettle();
    await shoot('settings_oil.png');

    await choose('水彩風混色');
    expect(find.text('水分量'), findsOneWidget);
    expect(find.text('絵具量'), findsOneWidget);
    // 縁の濃さは水彩境界フィルターで付けるので、ブラシには無い。
    expect(find.text('縁の濃さ'), findsNothing);
    expect(find.text('にじみ'), findsOneWidget);
    expect(find.text('むら'), findsOneWidget);
    expect(find.text('境界のぼかし'), findsOneWidget);
    expect(find.text('色延び'), findsNothing);
    await tester.ensureVisible(find.text('にじみ'));
    await tester.pumpAndSettle();
    await shoot('settings_watercolor.png');

    // ぼかし半径・ふち滲みはスイッチを入れなくてもスライダーで直接変えられる
    // （0でなし）。
    Finder sliderFor(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(LabeledSlider),
    );
    for (final label in ['ぼかし半径', 'ふち滲み']) {
      await tester.scrollUntilVisible(
        sliderFor(label),
        200,
        scrollable: sheetScroll,
      );
      expect(sliderFor(label), findsOneWidget);
    }
    expect(copy.pressureOff.blur.enabled, isFalse);
    final blurPlus = find.descendant(
      of: sliderFor('ぼかし半径'),
      matching: find.byIcon(Icons.add_circle_outline),
    );
    await tester.ensureVisible(blurPlus);
    await tester.pumpAndSettle();
    await tester.tap(blurPlus);
    await tester.pump();
    await tester.tap(blurPlus);
    await tester.pumpAndSettle();
    await shoot('settings_blur.png');

    // 保存すると水彩風混色として残る。
    final save = find.byType(FilledButton);
    await tester.scrollUntilVisible(save, 300, scrollable: sheetScroll);
    await tester.tap(save.last);
    await tester.pumpAndSettle();
    final saved = brushes.brushes.firstWhere((b) => b.id == copy.id);
    expect(saved.pressureOff.mixing.enabled, isTrue);
    expect(saved.pressureOff.mixing.mode, BrushMixingMode.watercolor);
    expect(saved.pressureOff.mixing.water, kDefaultMixingWater);
    expect(saved.pressureOff.mixing.bleed, kDefaultMixingBleed);
    expect(saved.pressureOff.mixing.texture, kDefaultMixingTexture);
    expect(saved.pressureOff.mixing.softEdge, kDefaultMixingSoftEdge);
    expect(saved.pressureOff.blur.enabled, isTrue);
    expect(saved.pressureOff.blur.value, 2);

    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  });
}
