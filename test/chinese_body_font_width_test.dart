// 中国語（簡体字・繁体字）の画面の本文で、漢字の字幅と字形が1語の中で
// 混ざらないことを見張る（DISC132）。
//
// 以前は本文の書体（白光明朝）の漢字が字幅0.65em（縦長の日本の明朝）で、
// 中国語の「仅显示收藏」では白光明朝にある「示收藏」だけが細く、無い「仅显」は
// 全角のNoto Serif SCになり、「收藏」が詰まって重なって見えた（ブラシ・トーン・
// スタンプのパネルのお気に入りのチップ）。中国語の本文はNoto Serif SCを主にし、
// 漢字はどれも全角（1em）で描く。韓国語のハングルは字幅がそろっていることを
// 確かめる。
//
// 組み込みの名前（ブラシ・トーン・スタンプ等、lib/servicesに日本語で書いた
// もの）も中国語の画面の本文に出る。サブセットに無い字（「八角形」の「八」、
// 「鉛筆」の「鉛」、「吹き出し」の「吹」等）は白光明朝の0.65emに落ちて
// いたので、名前ごとに漢字・かな・全角の字が細い字に落ちないことも確かめる。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

final RegExp _han = RegExp(r'[㐀-䶿一-鿿]');
final RegExp _hangul = RegExp(r'[가-힯]');

/// 段落[p]の本文の書体の漢字・ハングルの字幅の問題（無ければ空）。
/// 漢字は全角（文字の大きさと同じ幅）、ハングルはどれも同じ幅であること。
List<String> _widthProblems(RenderParagraph p) {
  if (p.text.style?.fontFamily == 'Kuramubon') return const [];
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  final size = p.textScaler.scale(p.text.style?.fontSize ?? 14);
  final out = <String>[];
  final hangulWidths = <double>{};
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    final isHan = _han.hasMatch(char);
    final isHangul = _hangul.hasMatch(char);
    if (!isHan && !isHangul) continue;
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final width = boxes.first.right - boxes.first.left;
    if (isHan && (width - size).abs() > 0.5) {
      out.add('«$text»の「$char」の幅が${width.toStringAsFixed(1)}（字の大きさ$size）');
    }
    if (isHangul) hangulWidths.add((width * 2).roundToDouble() / 2);
  }
  if (hangulWidths.length > 1) {
    out.add('«$text»のハングルの幅がそろっていない $hangulWidths');
  }
  return out;
}

List<RenderParagraph> _paragraphs(WidgetTester tester, [Finder? within]) =>
    tester
        .renderObjectList<RenderParagraph>(
          within == null
              ? find.byType(RichText)
              : find.descendant(of: within, matching: find.byType(RichText)),
        )
        .where((p) => p.attached && p.hasSize)
        .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in const ['zh', 'zh_Hant', 'ko']) {
    testWidgets('$language：本物のアプリのテーマで、ホームとブラシ・トーン・'
        'スタンプのパネル（お気に入りのチップ）の本文の字幅がそろう'
        '（文字1.0/2.0）', (tester) async {
      await loadAppFonts(tester);
      final problems = <String>[];
      // 本物のアプリ（NiarimApp）でホームを開き、そのテーマを使う。
      final harness = HomeAppHarness.prepare(tester, language: language);
      await harness.open();
      final home = find.byType(HomeScreen);
      for (final p in _paragraphs(tester, home)) {
        problems.addAll(_widthProblems(p).map((e) => 'home: $e'));
      }
      final theme = Theme.of(tester.element(home));
      final locale = Localizations.localeOf(tester.element(home));
      final l10n = lookupAppLocalizations(locale);

      for (final (name, width, build) in <(String, double, Widget Function())>[
        ('brush', 460, () => BrushPanel(onClose: () {})),
        ('tone', 460, () => TonePanel(onClose: () {})),
        ('stamp', 460, () => StampPanel(onClose: () {})),
        (
          'dock460-brush',
          460,
          () => DockedPanelScope(
            child: BrushPanel(dockedMode: true, onClose: () {}),
          ),
        ),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          SharedPreferences.setMockInitialValues({
            'first_launch': false,
            firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          });
          tester.view.physicalSize = Size(width, 900);
          final providers = (await tester.runAsync(buildAppProviders))!;
          await tester.pumpWidget(
            MultiProvider(
              providers: providers,
              child: MaterialApp(
                theme: theme,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, height: 860, child: build()),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          tester.takeException();
          final chip = find.text(l10n.customAutomationFavoritesOnly);
          if (chip.evaluate().isEmpty) {
            problems.add('$name ×$scale: お気に入りのチップの名前が出ていない');
          }
          for (final p in _paragraphs(tester)) {
            problems.addAll(_widthProblems(p).map((e) => '$name ×$scale: $e'));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      expect(
        problems.toSet().toList(),
        isEmpty,
        reason: problems.toSet().join('\n'),
      );
    });
  }

  for (final locale in const [
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets('${locale.toLanguageTag()}：組み込みの名前（lib/services）を本文の'
        '書体で描いても、漢字・かな・全角の字が白光明朝の細い字（0.65em）に'
        '落ちず、1語の中で字幅がそろう', (tester) async {
      await loadAppFonts(tester);
      final style = ThemeService()
          .themeDataFor(locale)
          .textTheme
          .bodyMedium!
          .copyWith(fontSize: 16);
      final names = <String>{
        for (final file in Directory('lib/services').listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            for (final match in RegExp(
              r"name: '([^'$]+)'",
            ).allMatches(file.readAsStringSync()))
              match.group(1)!,
      };
      expect(names.length, greaterThan(100), reason: '名前を集められていない');
      final fullWidth = RegExp(r'[㐀-䶿一-鿿ぁ-ゟ゠-ヿ！-～]');
      final problems = <String>[];
      var measured = 0;
      for (final name in names) {
        final painter = TextPainter(
          text: TextSpan(text: name, style: style),
          textDirection: TextDirection.ltr,
          locale: locale,
        )..layout();
        for (var i = 0; i < name.length; i++) {
          if (!fullWidth.hasMatch(name[i])) continue;
          final box = painter
              .getBoxesForSelection(
                TextSelection(baseOffset: i, extentOffset: i + 1),
              )
              .first;
          measured++;
          final width = box.right - box.left;
          // 白光明朝へ落ちた字は0.65em。Noto Serif SCのかなは隣の字との
          // 詰め（kern）で0.9em台になることがあるが、それは同じ書体の中。
          if (width < style.fontSize! * 0.85) {
            problems.add(
              '«$name»の「${name[i]}」の幅が${width.toStringAsFixed(1)}'
              '（字の大きさ${style.fontSize}）',
            );
          }
        }
        painter.dispose();
      }
      expect(measured, greaterThan(300));
      expect(
        problems,
        isEmpty,
        reason: '${problems.length}字\n${problems.join('\n')}',
      );
    });
  }
}
