// 設定の「ホーム画面ウィジェット」→「作品を選ぶ」の画面（P2-11）。
//
// 画面名が無く（上部バーには並び替えだけ）、作品が1つも無いときは文だけが
// 出て、次に何をすればよいかが無かった。作品を選ばない行は「作品を選んで
// いません」と状態の文で、押すと何になるのかが分からなかった。
//
// 上部バーに画面名（入らなければ出さない）、並び替えはホームのプロジェクトの
// 一覧と同じく一覧の上の行。作品が無いときはホームの空の一覧と同じ形（印・
// 題・補足・新規プロジェクト）。作品を選ばない行は「作品を表示しない」。
// 7言語・320/412px・文字1/2倍で、はみ出さないことも見張る。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/new_project_screen.dart';
import 'package:niarim/screens/settings/widget_artwork_picker_screen.dart';
import 'package:niarim/widgets/fit_or_hide_title.dart';
import 'package:niarim/widgets/sort_mode_control.dart';

import 'helpers/home_app_harness.dart';

void main() {
  Finder inPicker(Finder finder) => find.descendant(
    of: find.byType(WidgetArtworkPickerScreen),
    matching: finder,
  );

  Finder inAppBar(Finder finder) =>
      find.descendant(of: inPicker(find.byType(AppBar)), matching: finder);

  final ja = lookupAppLocalizations(const Locale('ja'));

  testWidgets('no works: a title, the empty state and New Project', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open();
    appRouter.push('/settings/widget/artwork');
    await tester.pumpAndSettle();

    expect(inAppBar(find.text(ja.widgetArtworkPickButton)), findsOneWidget);
    expect(
      inPicker(find.byKey(const Key('widgetArtworkNoProjects'))),
      findsOneWidget,
    );
    expect(inPicker(find.byIcon(Icons.movie_creation_outlined)), findsOne);
    expect(inPicker(find.text(ja.widgetNoProjects)), findsOneWidget);
    expect(inPicker(find.text(ja.widgetNoProjectsHint)), findsOneWidget);
    final create = inPicker(find.text(ja.homeAddSheetNewProject));
    expect(create, findsOneWidget);

    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(NewProjectScreen), findsOneWidget);
    // 作らずに戻ると、選ぶ画面に戻る。
    appRouter.pop();
    await tester.pumpAndSettle();
    expect(find.byType(WidgetArtworkPickerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with works: the title, sorting above the list, and the '
      '"show no work" row', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(seed: (service) => HomeAppHarness.work(service, 'apple'));
    appRouter.push('/settings/widget/artwork');
    await tester.pumpAndSettle();

    expect(inAppBar(find.text(ja.widgetArtworkPickButton)), findsOneWidget);
    expect(inAppBar(find.byType(SortModeControl)), findsNothing);
    expect(inPicker(find.byType(SortModeControl)), findsOneWidget);
    expect(inPicker(find.text(ja.widgetArtworkShowNone)), findsOneWidget);
    expect(inPicker(find.text(ja.widgetArtworkNone)), findsNothing);
    expect(inPicker(find.text('apple')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = switch (tag) {
      'zh-Hant' => 'zh_Hant',
      _ => locale.languageCode,
    };
    final l10n = lookupAppLocalizations(locale);
    testWidgets('fits at phone widths and large text ($tag)', (tester) async {
      final home = HomeAppHarness.prepare(tester, language: language);
      await home.open();
      appRouter.push('/settings/widget/artwork');
      await tester.pumpAndSettle();
      for (final width in [320.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 740), textScale: scale);
          await tester.pumpAndSettle();
          final at = '$tag ${width.toInt()}px x$scale';
          expect(tester.takeException(), isNull, reason: at);
          expect(
            inAppBar(find.byType(FitOrHideTitle)),
            findsOneWidget,
            reason: at,
          );
          expect(
            inPicker(find.text(l10n.homeAddSheetNewProject)),
            findsOneWidget,
            reason: at,
          );
        }
      }
      // 作品があるときの並び替えの行も、どの大きさでもはみ出さない。
      await tester.runAsync(() => HomeAppHarness.work(home.service, 'apple'));
      await home.settle();
      for (final width in [320.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 740), textScale: scale);
          await tester.pumpAndSettle();
          final at = '$tag ${width.toInt()}px x$scale (a work)';
          expect(tester.takeException(), isNull, reason: at);
          expect(
            inPicker(find.byType(SortModeControl)),
            findsOneWidget,
            reason: at,
          );
        }
      }
    });
  }
}
