import 'dart:convert';
import 'dart:math' as math;

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
import 'helpers/pump_real_async.dart';

/// 「パレットから選ぶ」のダイアログの下のボタン（追加・読み込み・キャンセル・
/// 適用）は、高さが足りる限り、送らなくても見える所に固定する。
///
/// 決まり（このテストが言葉にしている境目）：ダイアログに使える高さ
/// （画面の高さ−上下のシステムの帯−ダイアログの上下の余白）に、見出しと
/// 下のボタンを置いて、一覧に1行分（72px以上。名前1行×文字の倍率＋色見本＋
/// 行の操作を名前の下に置くときはその段）が残れば固定する。共有できなかった
/// 知らせが出ている間は、知らせを置いても半行分が残れば固定のまま（一覧と
/// 知らせで残りを分け合う）。足りないときだけ、見出しからボタンまでを1つの
/// スクロールで送る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = FakeShareChannel();
  setUp(share.install);
  tearDown(share.remove);

  const bars = FakeViewPadding(top: 24, bottom: 48);
  // 画面の大きさ（論理px）と、上下のシステムの帯。
  const screens = <(Size, FakeViewPadding)>[
    (Size(320, 568), FakeViewPadding.zero),
    (Size(360, 640), bars),
    (Size(390, 844), FakeViewPadding.zero),
    (Size(390, 220), FakeViewPadding.zero),
    (Size(800, 360), bars),
    (Size(915, 412), FakeViewPadding.zero),
    (Size(393, 500), FakeViewPadding.zero),
    (Size(1440, 900), FakeViewPadding.zero),
  ];

  testWidgets('the picker keeps Add, Import, Cancel and Apply in view in 144 '
      'profiles', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var profiles = 0;
    final failures = <String>[];

    for (final language in ['ja', 'en', 'fr']) {
      for (final (size, padding) in screens) {
        for (final scale in [1.0, 2.0]) {
          for (final count in [0, 3, 12]) {
            final profile =
                '$language/${size.width.round()}x${size.height.round()}'
                '${padding.top > 0 ? '+bars' : ''}/text$scale/n$count';
            profiles++;
            try {
              await tester.pumpWidget(const SizedBox.shrink());
              SharedPreferences.setMockInitialValues({
                'first_launch': false,
                'language': language,
                firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
                'pixel_art_palettes': [
                  for (var i = 0; i < count; i++)
                    jsonEncode({
                      'id': 'PixelPalette$i',
                      'name': 'AUDIT palette ${i + 1}',
                      'colors': [0xFF112233, 0xFF445566, 0xFF778899],
                      'isFavorite': false,
                    }),
                ],
              });
              tester.view.physicalSize = size;
              tester.view.padding = padding;
              tester.view.viewPadding = padding;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              final providers = (await tester.runAsync(buildAppProviders))!;
              await tester.pumpWidget(
                MultiProvider(
                  providers: providers,
                  child: Builder(
                    builder: (themeContext) => MaterialApp(
                      theme: themeContext.watch<ThemeService>().themeData,
                      scrollBehavior: const AppScrollBehavior(),
                      locale: Locale(language),
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
              final l10n = AppLocalizations.of(tester.element(dialog))!;
              final surface = find
                  .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(Material),
                  )
                  .first;
              final safeHeight = size.height - padding.top - padding.bottom;
              Rect dialogRect() => tester.getRect(surface);
              expect(
                dialogRect().top,
                greaterThanOrEqualTo(padding.top),
                reason: '$profile システムの帯に重ならない',
              );
              expect(
                dialogRect().bottom,
                lessThanOrEqualTo(size.height - padding.bottom),
                reason: '$profile システムの帯に重ならない',
              );

              final apply = find.widgetWithText(
                FilledButton,
                l10n.pixelArtPalettePickerApplyButton,
              );
              final cancel = find.widgetWithText(TextButton, l10n.commonCancel);
              final add = find.text(l10n.commonAdd);
              final import = find.byTooltip(
                l10n.colorPickerImportPaletteTooltip,
              );
              bool shown(Finder control) {
                if (control.evaluate().isEmpty) return false;
                final rect = tester.getRect(control);
                return rect.top >= dialogRect().top - 0.5 &&
                    rect.bottom <= dialogRect().bottom + 0.5 &&
                    control.hitTestable().evaluate().isNotEmpty;
              }

              bool footerShown() =>
                  shown(apply) && shown(cancel) && shown(add) && shown(import);

              // 見出し・下のボタン・知らせの高さから、決まりのとおりなら
              // 固定されるはずか。
              bool fits() {
                double heightOf(String key) {
                  final part = find.byKey(Key(key));
                  expect(part, findsOneWidget, reason: '$profile $key');
                  return tester.getSize(part).height;
                }

                final available = safeHeight - (size.height < 520 ? 32 : 48);
                // 文字が大きいときは左右の余白を詰めている（24→8）。
                final side = scale >= 2 ? 8.0 : 24.0;
                final actionsBeside =
                    dialogRect().width - side * 2 >= 240 + 140 * scale;
                final oneRow = math.max(
                  72.0,
                  16 + 24 * scale + 14 + (actionsBeside ? 0 : 48),
                );
                final room =
                    available -
                    heightOf('pixelPaletteHeader') -
                    heightOf('pixelPaletteFooter');
                final notice = heightOf('pixelPaletteNotice');
                return room >= oneRow &&
                    (notice == 0 || room - notice >= oneRow / 2);
              }

              final firstName = find.text('AUDIT palette 1');
              final lastName = find.text('AUDIT palette $count');
              final pinned = footerShown();
              // 文字が標準の大きさなら、とても低い画面（390x220）以外では
              // 送らなくても下のボタンが見える。
              if (scale == 1.0 && size.height > 220) {
                expect(pinned, isTrue, reason: '$profile 下のボタンが見えていない');
                if (count > 0) {
                  expect(
                    firstName.hitTestable(),
                    findsOneWidget,
                    reason: '$profile 一覧の1行目が見えていない',
                  );
                }
              }
              expect(pinned, fits(), reason: '$profile 固定するかどうかの境目');

              if (count == 0) {
                expect(
                  find.text(l10n.pixelArtPalettePickerEmpty),
                  findsOneWidget,
                  reason: profile,
                );
              } else {
                // 一覧を指で送って、最後のパレットまで届く。
                final listArea = tester.getCenter(find.byType(ListTile).first);
                for (
                  var i = 0;
                  i < 80 && lastName.hitTestable().evaluate().isEmpty;
                  i++
                ) {
                  await tester.dragFrom(listArea, const Offset(0, -120));
                  await tester.pumpAndSettle();
                }
                expect(
                  lastName.hitTestable(),
                  findsOneWidget,
                  reason: '$profile 最後のパレットへ届かない',
                );
                expect(tester.takeException(), isNull, reason: '$profile 送る');
                if (pinned) {
                  expect(
                    footerShown(),
                    isTrue,
                    reason: '$profile 一覧を送ると下のボタンが隠れた',
                  );
                }

                // 最後のパレットをファイルで共有する（共有の仕組みが無い端末）。
                share.failure = MissingPluginException('no share here');
                final shareButton = find
                    .byTooltip(l10n.colorPickerSharePaletteTooltip)
                    .last;
                await tester.ensureVisible(shareButton);
                await tester.pumpAndSettle();
                await tester.tap(shareButton);
                await tester.pumpAndSettle();
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
                expect(
                  notice.hitTestable(),
                  findsOneWidget,
                  reason: '$profile 知らせが見える所に出ていない',
                );
                expect(
                  tester.getRect(notice).bottom,
                  lessThanOrEqualTo(dialogRect().bottom + 0.5),
                  reason: '$profile 知らせの下がダイアログの外',
                );
                expect(footerShown(), fits(), reason: '$profile 知らせが出ている間の境目');
              }

              // 固定していないときも、送れば届いて閉じられる。
              await tester.ensureVisible(apply);
              await tester.pumpAndSettle();
              expect(apply.hitTestable(), findsOneWidget, reason: profile);
              await tester.ensureVisible(cancel);
              await tester.pumpAndSettle();
              await tester.tap(cancel);
              await tester.pumpAndSettle();
              expect(dialog, findsNothing, reason: '$profile 閉じる');
              expect(tester.takeException(), isNull, reason: '$profile 閉じる');
            } catch (failure) {
              // 1つの組で止めず、崩れる組をすべて挙げる。
              failures.add(
                '$profile: '
                '${failure is TestFailure ? failure.message : failure}',
              );
              tester.takeException();
            }
          }
        }
      }
    }
    expect(profiles, 144);
    expect(
      failures,
      isEmpty,
      reason: '${failures.length}組\n${failures.join('\n')}',
    );
  });
}
