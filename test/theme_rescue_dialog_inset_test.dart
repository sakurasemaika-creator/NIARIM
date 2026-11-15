// 読めないテーマの救済のダイアログ（「標準のテーマに戻しますか」）も、狭い
// 画面ではMaterialの最小の幅（280px）を取る（DISC221）。
//
// 救済のダイアログは、今のテーマの色を使わないように中身を自分の
// `Theme(ThemeService.rescueThemeData)`で包む。そのため、画面ごとの印が
// テーマに入れる狭い画面の空き（`NarrowDialogInset`、DISC211）が隠れ、
// 320pxの画面では既定の左右の空き（40px）のまま240pxで描かれていた。
//
// 7言語×320/360/412px×文字1.0/2.0で、救済のダイアログが320pxでは280px、
// 360・412pxでは今までどおり左右40pxで描かれること、ダイアログの色は
// 救済の固定の配色（標準のライトのテーマ）のままであること、題・ボタンの
// 語がその幅で途中で折れず、はみ出さないことを見張る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/theme_rescue_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/word_breaks.dart';

/// 文字も背景も同じ色＝何も読めないテーマ。
const _unreadable = AppThemePreset(
  id: 'unreadable_rescue_inset',
  name: 'unreadable',
  accentColor: Color(0xFF336699),
  textColor: Color(0xFF336699),
  buttonTextColor: Color(0xFF336699),
  menuTextColor: Color(0xFF336699),
  selectionTextColor: Color(0xFF336699),
  panelBgColor: Color(0xFF336699),
  menuBgColor: Color(0xFF336699),
  selectionColor: Color(0xFF336699),
  updateMarkColor: Color(0xFF336699),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET1_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets(
      'the theme rescue dialog takes the narrow-screen inset ($tag)',
      (tester) async {
        if (!fontsLoaded) {
          await loadAppFonts(tester);
          fontsLoaded = true;
        }
        SharedPreferences.setMockInitialValues({});
        final service = ThemeService();
        await tester.runAsync(service.init);
        service.restoreCurrent(_unreadable);
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider<ThemeService>.value(
            value: service,
            child: Builder(
              builder: (context) => RepaintBoundary(
                key: rootKey,
                child: MaterialApp(
                  locale: locale,
                  theme: context.watch<ThemeService>().themeDataFor(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: const Scaffold(
                    body: Align(
                      alignment: Alignment.topRight,
                      child: ThemeRescueButton(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final problems = <String>[];
        final errors = <String>[];
        final onError = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        try {
          for (final width in [320.0, 360.0, 412.0]) {
            for (final scale in [1.0, 2.0]) {
              tester.view.physicalSize = Size(width, 760);
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              await tester.pumpAndSettle();
              final at = '${width.toInt()}px x$scale';
              await tester.tap(find.byType(ThemeRescueButton));
              await tester.pumpAndSettle();
              expect(find.text(l10n.themeResetConfirmTitle), findsOneWidget);

              final surface = find
                  .descendant(
                    of: find.byType(Dialog),
                    matching: find.byType(Material),
                  )
                  .first;
              final dialogWidth = tester.getSize(surface).width;
              // 320pxでは最小の幅が取れるところまで左右の空きを縮める
              // （左右20px）。360・412pxは既定の左右40px・上下24pxのまま。
              final inset = tester
                  .widget<AnimatedPadding>(
                    find
                        .descendant(
                          of: find.byType(Dialog),
                          matching: find.byType(AnimatedPadding),
                        )
                        .first,
                  )
                  .padding;
              final expectedInset = EdgeInsets.symmetric(
                horizontal: width < 360 ? (width - 280) / 2 : 40,
                vertical: 24,
              );
              if (inset != expectedInset) {
                problems.add(
                  '$at: the dialog inset is $inset (expected $expectedInset)',
                );
              }
              if (dialogWidth < 280 - 0.5 || dialogWidth > width - 2 * 20) {
                problems.add(
                  '$at: the dialog is ${dialogWidth.toStringAsFixed(0)}px wide '
                  '(the Material minimum is 280px)',
                );
              }

              // 救済のダイアログは今のテーマ（読めない色）を使わない。
              final dialogTheme = Theme.of(
                tester.element(find.byType(AlertDialog)),
              );
              expect(
                dialogTheme.colorScheme.onSurface,
                AppThemePreset.defaultLight.textColor,
                reason: '$at: the rescue dialog uses the rescue colours',
              );
              expect(
                tester.widget<Material>(surface).color,
                AppThemePreset.defaultLight.menuBgColor,
                reason: '$at: the rescue dialog surface is the rescue colour',
              );

              for (final paragraph in textParagraphsIn(
                find.byType(AlertDialog),
              )) {
                for (final broken in wordsBrokenThatFit(paragraph)) {
                  problems.add('$at: $broken');
                }
              }
              for (final error in errors) {
                problems.add('$at: $error');
              }
              errors.clear();

              if (shots != null && scale == 2.0 && width != 412) {
                await tester.runAsync(() async {
                  final boundary =
                      rootKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$shots/DISC221-${tag}_${width.toInt()}_x2.png',
                  ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                  image.dispose();
                });
              }

              await tester.tap(find.text(l10n.commonCancel).last);
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsNothing);
            }
          }
        } finally {
          FlutterError.onError = onError;
        }
        for (final problem in problems.take(12)) {
          debugPrint('$tag $problem');
        }
        expect(problems, isEmpty, reason: '${problems.length} problems');
        expect(service.current.id, _unreadable.id, reason: 'cancel keeps it');
      },
    );
  }
}
