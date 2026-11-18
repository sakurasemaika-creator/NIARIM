// 画面名（上部バーの題）は、入らなければ出さない（判断4：「…」で切らない）
// ことを見張る。
//
// 上部バー（AppBar）は題を1行・「…」で描くので、素の`Text`の題は狭い幅・
// 大きな文字で「Mis publicacio…」（自分の投稿、西語360px×文字2倍）、
// 「Réglages de re…」（自動塗りの設定、仏語360px）のように切れた。題は
// `FitOrHideTitle`（入らなければ出さず、吹き出しと読み上げに残す）で描く。
//
// 作者の名前・作品名のように、画面名ではなくデータを題に出す画面と、
// ほかの作業で作り直している画面（ホーム・保存・容量・引き継ぎ・
// プロジェクト詳細・キャンバス）は対象の外。
//
// 選んでいる間の題（自分の投稿の「12 seleccionado(s)」）は画面名ではなく、
// そこにしか出ない情報（選んだ件数）なので、FitOrHideTitleで隠さない。入らない
// 幅では全文→チェックの印と数→数だけ、と短くして必ず出す（字は縮めない）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/autofill/autofill_preset_screen.dart';
import 'package:niarim/screens/community/community_my_works_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

/// 上部バーの題の段落の問題（切れている・はみ出す）。
List<String> _titleProblems(WidgetTester tester, String where) => [
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.descendant(
      of: find.byType(NavigationToolbar),
      matching: find.byType(RichText),
    ),
  ))
    if (p.attached && p.text.style?.fontFamily != 'MaterialIcons')
      for (final problem in textFitProblems(p))
        '$where: «${p.text.toPlainText()}» $problem',
];

Widget _app(Locale locale, double scale, ThemeData theme, Widget home) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );

const _sizes = [Size(320, 700), Size(360, 760), Size(412, 900)];

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('自分の投稿：7言語×320/360/412px×文字1.0/2.0で題を切らない', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    final auth = GoogleAuthService();
    await auth.init();
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in _sizes) {
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: service),
                ChangeNotifierProvider.value(value: auth),
                ChangeNotifierProvider(
                  create: (_) => CommunityPreviewService(),
                ),
                ChangeNotifierProvider(create: (_) => SettingsService()),
                ChangeNotifierProvider(create: (_) => PremiumService()),
              ],
              child: _app(
                locale,
                scale,
                ThemeService().themeDataFor(locale),
                const CommunityMyWorksScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          problems.addAll(
            _titleProblems(
              tester,
              '${locale.toLanguageTag()} ${size.width.round()}px ×$scale',
            ),
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('自分の投稿：選んでいる間の件数は、7言語×320/360/412px×'
      '文字1.0/1.3/2.0のどれでも隠さず切らない（全文→印と数→数）', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    final auth = GoogleAuthService();
    await auth.init();
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    final semantics = tester.ensureSemantics();
    final problems = <String>[];
    final forms = <String>{};
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final size in _sizes) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          // 全部選ぶ（2桁）と、1つだけ長押しで選ぶ（1桁）。
          for (final all in const [true, false]) {
            final where =
                '${locale.toLanguageTag()} ${size.width.round()}px ×$scale '
                '${all ? '全部' : '1つ'}';
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: service),
                  ChangeNotifierProvider.value(value: auth),
                  ChangeNotifierProvider(
                    create: (_) => CommunityPreviewService(),
                  ),
                  ChangeNotifierProvider(create: (_) => SettingsService()),
                  ChangeNotifierProvider(create: (_) => PremiumService()),
                ],
                child: MaterialApp(
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  theme: ThemeService().themeDataFor(locale),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  // 本物と同じく前の画面から開き、戻るボタンも並べる。
                  initialRoute: '/works',
                  routes: {
                    '/': (_) => const SizedBox(),
                    '/works': (_) => const CommunityMyWorksScreen(),
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (all) {
              final selectAll = find.byKey(
                const Key('communityMyWorksSelectAll'),
              );
              await tester.ensureVisible(selectAll);
              await tester.pumpAndSettle();
              await tester.tap(selectAll);
            } else {
              final row = find
                  .byWidgetPredicate(
                    (w) =>
                        w is ListTile &&
                        '${w.key}'.contains('communityMyWorksRow-'),
                  )
                  .first;
              await tester.ensureVisible(row);
              await tester.pumpAndSettle();
              await tester.longPress(row);
            }
            await tester.pumpAndSettle();
            final count = all
                ? service
                      .worksByAuthor(kDummySelfAuthorId, includeHidden: true)
                      .length
                : 1;
            final text = l.homeSelectionCount(count);
            final shown = [
              for (final p in tester.renderObjectList<RenderParagraph>(
                find.descendant(
                  of: find.byType(NavigationToolbar),
                  matching: find.byType(RichText),
                ),
              ))
                if (p.attached && p.text.style?.fontFamily != 'MaterialIcons')
                  p.text.toPlainText(),
            ];
            if (!shown.contains(text) && !shown.contains('$count')) {
              problems.add('$where: 件数「$text」が上部バーに出ていない $shown');
            }
            forms.add(shown.contains(text) ? '全文' : '短い形');
            problems.addAll(_titleProblems(tester, where));
            if (find.bySemanticsLabel(text).evaluate().isEmpty) {
              problems.add('$where: 読み上げに「$text」が無い');
            }
          }
        }
      }
    }
    semantics.dispose();
    expect(problems, isEmpty, reason: problems.join('\n'));
    // 狭い幅・大きな文字では短い形になることも確かめる（全部が全文なら、
    // 短い形を見ていない）。
    expect(forms, containsAll(['全文', '短い形']));
  });

  testWidgets('自動塗りの設定：7言語×320/360/412px×文字1.0/2.0で題を切らない', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('niarim_title_fit_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final providers = (await tester.runAsync(buildAppProviders))!;
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in _sizes) {
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MultiProvider(
              providers: providers,
              child: Builder(
                builder: (context) => _app(
                  locale,
                  scale,
                  context.watch<ThemeService>().themeDataFor(locale),
                  const AutofillPresetScreen(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          problems.addAll(
            _titleProblems(
              tester,
              '${locale.toLanguageTag()} ${size.width.round()}px ×$scale',
            ),
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('lib配下の上部バーの画面名は、素のTextでなくFitOrHideTitleで描く', () {
    // データを題に出す画面・ほかの作業で作り直している画面・何行かで出す
    // ように作った画面。
    const exempt = {
      // 作者の名前・作品名（データ）。
      'lib/screens/community/community_author_works_screen.dart',
      'lib/screens/settings/widget_artwork_picker_screen.dart',
      // 作品広場は題を3行まで折り返す（dev_branchの作り）。
      'lib/screens/community/community_screen.dart',
      // ほかの作業の画面。
      'lib/screens/project/project_detail_screen.dart',
      'lib/screens/canvas/canvas_screen.dart',
    };
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      final path = file.path.replaceAll('\\', '/');
      if (file is! File || !path.endsWith('.dart')) continue;
      if (exempt.contains(path) ||
          path.startsWith('lib/screens/home/') ||
          path.startsWith('lib/screens/save_tree/')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'AppBar\(\s*(?:[^()]*?\s)?title:\s*(?:const\s+)?Text\(\s*([^,)]+)',
      ).allMatches(source)) {
        // 見本一覧の作者のページの模型（作者の名前＝データ）。
        if (match.group(1)!.contains('themePreviewSampleArtist')) continue;
        final line = source.substring(0, match.start).split('\n').length;
        found.add('$path:$line ${match.group(1)!.trim()}');
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('件数のような、題にしか出ない情報はFitOrHideTitleに渡さない（隠さない）', () {
    // FitOrHideTitleは入らないときに出さないので、画面名だけに使う。
    // 括弧を1段まで含む引数を取り出し、件数（…Count(…)）を探す。
    final call = RegExp(
      r'FitOrHideTitle\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)',
    );
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      final path = file.path.replaceAll('\\', '/');
      if (file is! File || !path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in call.allMatches(source)) {
        if (!RegExp(r'Count\(').hasMatch(match.group(1)!)) continue;
        final line = source.substring(0, match.start).split('\n').length;
        found.add('$path:$line ${match.group(1)!.trim()}');
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
