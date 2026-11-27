// ブラシの設定のシートは、描く人がしていることごとのまとまりに分ける：
// 上に固定した題・保存・今の設定で描いた線の見本、その下に「描き味」
// （入り抜き・間隔・紙目・減衰・ドット絵）、いま使っている筆圧（ON/OFF）の
// 設定、「縁取り・折り畳み・反復」、使っていない方の筆圧の設定（たたむ）、
// 「ペン先・画像素材」（たたむ）。保存は送らなくても押せ、入り抜きは
// チップで選び、選んだ値は保存される。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/stroke_sample_preview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_brush_settings_sheet_docs',
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

  for (final pressure in [true, false]) {
    testWidgets('sections follow the pen pressure in use ($pressure)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);

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
      final l10n = AppLocalizations.of(context)!;
      final brushes = context.read<BrushService>();
      await tester.runAsync(
        () => context.read<SettingsService>().setPenPressureEnabled(pressure),
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

      // 題・保存・見本はスクロールの外で、開いてすぐ見える。
      final save = find.byKey(const Key('brush-settings-save'));
      expect(save.hitTestable(), findsOneWidget);
      final sample = find.byKey(const Key('brush-settings-sample'));
      expect(sample.hitTestable(), findsOneWidget);
      expect(tester.widget<StrokeSamplePreview>(sample).brush?.id, copy.id);

      // まとまりの順と、開いているかどうか。
      final inUse = pressure
          ? 'brush-settings-pressure-on'
          : 'brush-settings-pressure-off';
      final other = pressure
          ? 'brush-settings-pressure-off'
          : 'brush-settings-pressure-on';
      final order = [
        // 自作のブラシは一番上に名前の欄（2026-11-27）。
        'brush-settings-name',
        'brush-settings-stroke',
        inUse,
        'brush-settings-effects',
        other,
        'brush-settings-tip',
      ];
      // まとまりは一覧の子として順に並ぶ（後ろの方は送るまで作られないので、
      // 一覧の子の並びで見る）。
      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ListView),
        ),
      );
      final sections = {
        for (final child
            in (list.childrenDelegate as SliverChildListDelegate).children)
          if (child.key case ValueKey<String>(:final value)) value: child,
      };
      expect(sections.keys.toList(), order);
      bool expanded(String key) =>
          ((sections[key]! as Material).child! as ExpansionTile)
              .initiallyExpanded;
      expect(expanded('brush-settings-stroke'), isTrue);
      expect(expanded(inUse), isTrue);
      expect(expanded('brush-settings-effects'), isTrue);
      expect(expanded(other), isFalse);
      expect(expanded('brush-settings-tip'), isFalse);
      expect(find.text(l10n.brushSettingsStrokeSection), findsOneWidget);

      // 入り抜きはチップ：カスタムを選ぶと距離のスライダーが出る。
      final custom = find.byKey(const Key('brush-fade-custom'));
      await tester.ensureVisible(custom);
      await tester.pumpAndSettle();
      await tester.tap(custom);
      await tester.pumpAndSettle();
      expect(find.text(l10n.brushSettingsFadeEndValueLabel), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(custom).selected,
        isTrue,
        reason: 'the chosen fade is the selected chip',
      );

      // 入り抜き（太さ）はフェード（透け方）のすぐ下の別の設定。
      final taperCustom = find.byKey(const Key('brush-taper-custom'));
      await tester.ensureVisible(taperCustom);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(taperCustom).dy,
        greaterThan(tester.getTopLeft(custom).dy),
      );
      await tester.tap(taperCustom);
      await tester.pumpAndSettle();
      expect(find.text(l10n.brushSettingsTaperEndValueLabel), findsOneWidget);
      expect(find.text(l10n.brushSettingsTaperModeTitle), findsOneWidget);

      // 送った後も保存は同じ所で押せる。
      final sheetScroll = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      await tester.drag(sheetScroll, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved = brushes.brushes.firstWhere((b) => b.id == copy.id);
      expect(saved.fadeMode, FadeMode.custom);
      expect(saved.taperMode, FadeMode.custom);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    });
  }
}
