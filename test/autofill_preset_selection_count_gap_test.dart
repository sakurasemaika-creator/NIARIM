// 自動塗りのプリセットの一覧で、選んでいる間の行の件数（「3件選択中」・
// 短くした「☑3」）と「複製」のアイコンの間に隙間があることを見張る（DISC135）。
//
// 以前は件数のすぐ後ろに「複製」のボタンを置いていて、件数の文字と複製の
// アイコンの間（約12px）が操作のアイコンどうしの間（約24px）より狭く、件数が
// 複製のアイコンに隙間なく接して見えた（実操作、DISC113の確認）。件数は操作の
// アイコンどうしより離して、別のまとまりに見せる。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('7言語×320〜412px×文字1.0/2.0で、件数と「複製」のアイコンの間に'
      '操作のアイコンどうしより広い隙間がある（件数を全文・短い形のどちらで'
      '出しても）', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    var measured = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final width in const [320.0, 360.0, 380.0, 412.0]) {
        for (final scale in const [1.0, 2.0]) {
          final where = '${locale.toLanguageTag()} ${width.round()} ×$scale';
          SharedPreferences.setMockInitialValues({
            'first_launch': false,
            firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          });
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          final providers = (await tester.runAsync(buildAppProviders))!;
          await tester.pumpWidget(
            MultiProvider(
              providers: providers,
              child: Builder(
                builder: (themeContext) => MaterialApp(
                  // 本物のアプリと同じ、表示言語のテーマ（中国語は本文の
                  // 書体が違う）。
                  theme: themeContext.watch<ThemeService>().themeDataFor(
                    locale,
                  ),
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: const AutofillPresetScreen(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          final presets = tester
              .element(find.byType(AutofillPresetScreen))
              .read<AutofillPresetService>()
              .presets;
          await tester.longPress(find.text(presets.first.name).first);
          await tester.pump(const Duration(milliseconds: 400));
          tester.takeException();
          final duplicate = find.descendant(
            of: find.byTooltip(l10n.commonDuplicate),
            matching: find.byIcon(Icons.content_copy),
          );
          final count = l10n.homeSelectionCount(1);
          // 全文の件数か、短い件数（☑と数）。
          final fullCount = find.text(count);
          final shortCount = find.descendant(
            of: find.byTooltip(count),
            matching: find.text('1'),
          );
          final countFinder = fullCount.evaluate().isNotEmpty
              ? fullCount
              : shortCount;
          if (countFinder.evaluate().isEmpty || duplicate.evaluate().isEmpty) {
            problems.add('$where: 件数か複製が無い');
            continue;
          }
          final countRect = tester.getRect(countFinder.first);
          final iconRect = tester.getRect(duplicate.first);
          final paste = find.descendant(
            of: find.byTooltip(l10n.commonPaste),
            matching: find.byIcon(Icons.content_paste),
          );
          // 操作のアイコンどうしの間（複製と貼り付け）。
          final iconGap = tester.getRect(paste.first).left - iconRect.right;
          // 同じ行に並ぶときだけ（2行の形では複製は下の行）。
          final sameLine =
              countRect.top < iconRect.bottom &&
              iconRect.top < countRect.bottom;
          if (!sameLine) continue;
          // 件数の字の右端（段落の箱ではなく、描かれた行の幅）。
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: countFinder.first,
              matching: find.byType(RichText),
            ),
          );
          final lines = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: paragraph.text.toPlainText().length,
            ),
          );
          final textRight =
              paragraph.localToGlobal(Offset.zero).dx +
              lines.map((b) => b.right).reduce((a, b) => a > b ? a : b);
          final gap = iconRect.left - textRight;
          measured++;
          if (gap < iconGap) {
            problems.add(
              '$where: 件数と複製の間が${gap.toStringAsFixed(1)}px'
              '（アイコンどうしは${iconGap.toStringAsFixed(1)}px）',
            );
          }
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(measured, greaterThan(0));
  });
}
