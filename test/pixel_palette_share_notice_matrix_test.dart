import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:niarim/widgets/pixel_art_palette_picker_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_share_channel.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

/// 「パレットから選ぶ」のダイアログの中に出す、共有できなかったときの知らせ。
/// 7言語×3つの画面×文字の大きさ2通りで、はみ出さず、読める位置へ送れ、
/// ダイアログを閉じられること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  setUp(share.install);
  tearDown(share.remove);

  testWidgets('the in-dialog share notice fits 42 locale and layout profiles', (
    tester,
  ) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var profiles = 0;
    final failures = <String>[];
    for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
      for (final size in [
        const Size(320, 844),
        const Size(390, 220),
        const Size(1440, 900),
      ]) {
        for (final scale in [1.0, 2.0]) {
          final profile = '$language/$size/text$scale';
          try {
            await tester.pumpWidget(const SizedBox.shrink());
            SharedPreferences.setMockInitialValues({
              'first_launch': false,
              'language': language,
              firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
              'pixel_art_palettes': [
                for (final name in ['AUDIT palette', 'AUDIT second palette'])
                  jsonEncode({
                    'id': 'PixelPalette$name',
                    'name': name,
                    'colors': [0xFF112233, 0xFF445566, 0xFF778899],
                    'isFavorite': false,
                  }),
              ],
            });
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final providers = (await tester.runAsync(buildAppProviders))!;
            await tester.pumpWidget(
              MultiProvider(
                providers: providers,
                child: Builder(
                  builder: (themeContext) => MaterialApp(
                    theme: themeContext.watch<ThemeService>().themeData,
                    scrollBehavior: const AppScrollBehavior(),
                    locale: language == 'zh_Hant'
                        ? const Locale.fromSubtags(
                            languageCode: 'zh',
                            scriptCode: 'Hant',
                          )
                        : Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Scaffold(
                      body: Builder(
                        builder: (context) => Center(
                          child: IconButton(
                            icon: const Icon(Icons.palette_outlined),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const PixelArtPalettePickerDialog(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.byIcon(Icons.palette_outlined));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$profile 開く');
            final dialog = find.byType(PixelArtPalettePickerDialog);
            expect(dialog, findsOneWidget, reason: profile);
            final l10n = AppLocalizations.of(tester.element(dialog))!;

            // 1つ目のパレットをファイルで共有する（共有の仕組みが無い端末）。
            share.failure = MissingPluginException('no share on this device');
            final shareButton = find
                .byTooltip(l10n.colorPickerSharePaletteTooltip)
                .first;
            await tester.ensureVisible(shareButton);
            await tester.pumpAndSettle();
            await tester.tap(shareButton);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$profile 共有の方法');
            final asFile = find.text(l10n.colorPickerShareViaFile);
            await tester.ensureVisible(asFile);
            await tester.pumpAndSettle();
            await tester.tap(asFile);
            await pumpRealAsync(tester, const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull, reason: '$profile 共有の後');

            final notice = find.descendant(
              of: dialog,
              matching: find.text(l10n.communityErrorUnsupported),
            );
            expect(notice, findsOneWidget, reason: profile);
            expect(find.byType(SnackBar), findsNothing, reason: profile);
            // 低い画面でも、送らなくても知らせが見える所に出ている。
            expect(
              notice.hitTestable(),
              findsOneWidget,
              reason: '$profile 知らせが見える所まで送られていない',
            );
            expect(
              tester.getRect(notice).bottom,
              lessThanOrEqualTo(size.height),
              reason: '$profile 知らせの下が画面の外',
            );
            await tester.ensureVisible(notice);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$profile 知らせ');
            // 知らせの文が画面の中にあり、知らせの行の幅が潰れていない
            // （1字ずつ縦に並ばない）。
            final noticeRect = tester.getRect(notice);
            expect(noticeRect.top, greaterThanOrEqualTo(0), reason: profile);
            expect(noticeRect.left, greaterThanOrEqualTo(0), reason: profile);
            expect(
              noticeRect.right,
              lessThanOrEqualTo(size.width),
              reason: profile,
            );
            final noticeLine = find.ancestor(
              of: notice,
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.liveRegion == true,
              ),
            );
            expect(noticeLine, findsWidgets, reason: '$profile 読み上げへ伝える');
            expect(
              tester.getSize(noticeLine.first).width,
              greaterThan(150),
              reason: profile,
            );
            expect(
              tester.getCenter(notice).dy,
              inInclusiveRange(0, size.height),
              reason: profile,
            );
            expectNoInternalText(tester, reason: profile);

            // 一覧の名前も読める幅がある。
            final name = find.descendant(
              of: dialog,
              matching: find.text('AUDIT palette'),
            );
            await tester.ensureVisible(name);
            await tester.pumpAndSettle();
            expect(
              tester.getSize(name).width,
              greaterThan(60),
              reason: profile,
            );

            // 適用・キャンセルへ届き、閉じられる。
            final cancel = find.descendant(
              of: dialog,
              matching: find.widgetWithText(TextButton, l10n.commonCancel),
            );
            await tester.ensureVisible(cancel);
            await tester.pumpAndSettle();
            expect(cancel.hitTestable(), findsOneWidget, reason: profile);
            final apply = find.descendant(
              of: dialog,
              matching: find.text(l10n.pixelArtPalettePickerApplyButton),
            );
            await tester.ensureVisible(apply);
            await tester.pumpAndSettle();
            expect(apply.hitTestable(), findsOneWidget, reason: profile);
            await tester.ensureVisible(cancel);
            await tester.pumpAndSettle();
            await tester.tap(cancel);
            await tester.pumpAndSettle();
            expect(dialog, findsNothing, reason: profile);
            expect(tester.takeException(), isNull, reason: '$profile 閉じる');
          } catch (failure) {
            // 1つの組で止めず、はみ出す組をすべて挙げる。
            failures.add(
              '$profile: ${failure is TestFailure ? failure.message : failure}',
            );
            tester.takeException();
          }
          profiles++;
        }
      }
    }
    expect(profiles, 42);
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
