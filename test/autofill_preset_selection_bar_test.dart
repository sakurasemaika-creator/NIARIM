// 自動塗りのプリセットの一覧で、選んでいる間の操作の行（全選択・全解除・
// 件数・複製・貼り付け・書き出し・削除）が、スマホの幅でもはみ出さず、
// どの操作も押せることを見張る（DISC113）。
//
// 以前は［全選択］［全解除］の文字のボタン・件数・48pxのアイコン4つを1行に
// 固定で並べていて、412pxの簡体字（実操作）でも削除のボタンがほとんど隠れた。
// 所有者の判断3：文字は縮めない。入らない幅では文字のボタンをアイコンにし
// （名前は吹き出し・読み上げ）、件数は短くして全文を吹き出しにする。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/first_that_fits.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('7言語×320〜412px×文字1.0/2.0で、選択中の操作の行がはみ出さず、'
      '6つの操作がどれも画面の中で押せる', (tester) async {
    await loadAppFonts(tester);
    final problems = <String>[];
    var shortened = 0;
    var full = 0;
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
                  theme: themeContext.watch<ThemeService>().themeData,
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
          if (presets.isEmpty) {
            problems.add('$where: 組み込みのプリセットが無い');
            continue;
          }
          // 長押しで選ぶ（選択の行が出る）。
          await tester.longPress(find.text(presets.first.name).first);
          await tester.pump(const Duration(milliseconds: 400));
          final error = tester.takeException();
          if (error != null) {
            problems.add('$where: $error');
            continue;
          }
          bool inside(Finder f) {
            if (f.evaluate().isEmpty) return false;
            final r = tester.getRect(f.first);
            return r.left >= -0.5 && r.right <= width + 0.5;
          }

          // 全選択・全解除は文字のボタンか、名前を吹き出しにしたアイコン。
          for (final name in [
            l10n.homeSelectionAllSelect,
            l10n.homeSelectionAllDeselect,
          ]) {
            final asText = find.widgetWithText(TextButton, name);
            final asIcon = find.byTooltip(name);
            if (!inside(asText) && !inside(asIcon)) {
              problems.add('$where: 「$name」が画面の中に無い');
            }
          }
          for (final name in [
            l10n.commonDuplicate,
            l10n.commonPaste,
            l10n.autofillPresetExportMenuItem,
            l10n.commonDelete,
          ]) {
            if (!inside(find.byTooltip(name))) {
              problems.add('$where: 「$name」が画面の中に無い');
            }
          }
          // 件数：全文が出ているか、短くした件数の吹き出しに全文がある。
          final count = l10n.homeSelectionCount(1);
          if (inside(find.text(count))) {
            full++;
          } else if (inside(find.byTooltip(count))) {
            shortened++;
          } else {
            problems.add('$where: 件数「$count」が無い');
          }
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 広い所では件数の全文、狭い所では短い件数（全文は吹き出し）。
    expect(full, greaterThan(0), reason: '短くした件数 $shortened');
  });

  testWidgets('削除のボタンにキーボードのフォーカスがあるまま幅が変わって行の形が'
      '替わっても、フォーカスは削除に残り、Enter で削除の確かめが出る（検索は'
      '開かない）', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
    expect(tester.takeException(), isNull);

    bool deleteFocused() {
      var hit = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        final widget = e.widget;
        hit = widget is Tooltip && widget.message == l10n.commonDelete;
        return !hit;
      });
      return hit;
    }

    for (var i = 0; i < 40 && !deleteFocused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(deleteFocused(), isTrue, reason: '削除にフォーカスが来ない');
    // 320px と 412px（回転・画面分割）では行の形が違う。
    int chosenForm() =>
        (tester.element(find.byType(FirstThatFits)).findRenderObject()!
                as RenderFirstThatFits)
            .chosenIndex;
    final formAt320 = chosenForm();
    tester.view.physicalSize = const Size(412, 900);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(chosenForm(), isNot(formAt320));
    expect(
      deleteFocused(),
      isTrue,
      reason: '${FocusManager.instance.primaryFocus}',
    );
    final fieldsBefore = find.byType(TextField).evaluate().length;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField).evaluate().length, fieldsBefore);
    expect(tester.takeException(), isNull);
  });
}
