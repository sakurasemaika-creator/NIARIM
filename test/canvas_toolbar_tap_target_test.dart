import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'canvas toolbar keeps 48dp hit targets at every icon size and orientation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 480);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsService();
      await settings.init();
      addTearDown(settings.dispose);
      final themes = ThemeService();
      await themes.init();
      addTearDown(themes.dispose);
      // バケツの印はトーンで塗る間トーンの印になる（ToneServiceを見る）。
      final tones = ToneService();
      addTearDown(tones.dispose);

      for (final vertical in [false, true]) {
        for (var level = 1; level <= 5; level++) {
          await settings.setToolbarSizeLevel(level);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsService>.value(value: settings),
                ChangeNotifierProvider<ThemeService>.value(value: themes),
                ChangeNotifierProvider<ToneService>.value(value: tones),
              ],
              child: MaterialApp(
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: themes.themeDataFor(const Locale('ja')),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: vertical ? 120 : 640,
                      height: vertical ? 420 : 120,
                      child: ToolbarWidget(
                        currentTool: DrawingTool.pen,
                        currentColor: Colors.black,
                        onToolSelected: (_) {},
                        onColorTap: () {},
                        onBrushTap: () {},
                        onLayerTap: () {},
                        onPenLongPress: () {},
                        onFingerLongPress: () {},
                        onTextTap: () {},
                        onShapeTap: () {},
                        onQuickToolTap: () {},
                        onQuickToolLongPress: () {},
                        onSaveTap: () {},
                        onLassoFillSelected: () {},
                        onRulerTap: () {},
                        vertical: vertical,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final scope =
              '${vertical ? 'vertical' : 'horizontal'} toolbar, level $level';
          final buttons = find.descendant(
            of: find.byType(ToolbarWidget),
            matching: find.byType(CanvasIconButton),
          );
          expect(buttons, findsWidgets, reason: scope);
          for (final button in buttons.evaluate()) {
            final ink = find
                .descendant(
                  of: find.byWidget(button.widget),
                  matching: find.byType(InkResponse),
                )
                .first;
            final size = tester.getSize(ink);
            expect(
              size.width,
              greaterThanOrEqualTo(48),
              reason: '$scope: $size',
            );
            expect(
              size.height,
              greaterThanOrEqualTo(48),
              reason: '$scope: $size',
            );
          }

          final swatch = find.byKey(const ValueKey('canvasColorSwatch'));
          expect(
            tester.getSize(swatch).width,
            greaterThanOrEqualTo(48),
            reason: scope,
          );
          expect(
            tester.getSize(swatch).height,
            greaterThanOrEqualTo(48),
            reason: scope,
          );
          expect(tester.takeException(), isNull, reason: scope);
        }
      }
    },
  );
}
