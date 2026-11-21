import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// プロジェクトタブの一覧が空のとき、なぜ空かを言う（検索に当たらない・
/// お気に入りが無い・お気に入りで隠れている・フォルダが空）。絞り込みで
/// 隠れているだけなのに「プロジェクトがありません／＋ ボタンから新規作成」と
/// 言わず、絞り込みを外すボタンを出す。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  Future<void> search(WidgetTester tester, String query) async {
    if (find.byKey(const Key('homeSearchInput')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('homeSearchButton')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('homeSearchInput')), query);
    await tester.pumpAndSettle();
  }

  Finder inList(Finder finder) => HomeAppHarness.inProjects(finder);

  void expectNotEmptyLibrary(WidgetTester tester) {
    expect(inList(find.text(ja.projectListEmptyTitle)), findsNothing);
    expect(inList(find.text(ja.projectListEmptyHint)), findsNothing);
  }

  testWidgets('a search without hits offers to clear it', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(seed: (service) => HomeAppHarness.work(service, 'apple'));
    await search(tester, 'zzz');
    expect(
      inList(find.text(ja.projectListNoMatchTitle('zzz'))),
      findsOneWidget,
    );
    expect(inList(find.text(ja.projectListNoMatchNameHint)), findsOneWidget);
    expectNotEmptyLibrary(tester);
    await tester.tap(inList(find.text(ja.projectListClearSearch)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeSearchInput')), findsNothing);
    expect(inList(find.text('apple')), findsOneWidget);

    // タグで探しているときはタグの説明。
    await search(tester, 'zzz');
    await tester.tap(find.byKey(const Key('homeSearchTagToggle')));
    await tester.pumpAndSettle();
    await search(tester, 'zzz');
    expect(inList(find.text(ja.projectListNoMatchTagHint)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('favorites-only without favorites offers to show all', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(seed: (service) => HomeAppHarness.work(service, 'apple'));
    await tester.tap(find.widgetWithText(FilterChip, ja.homeFavoritesOnly));
    await tester.pumpAndSettle();
    expect(inList(find.text(ja.projectListNoFavoritesTitle)), findsOneWidget);
    expect(inList(find.text(ja.projectListNoFavoritesHint)), findsOneWidget);
    expectNotEmptyLibrary(tester);
    await tester.tap(inList(find.text(ja.projectListShowAll)));
    await tester.pumpAndSettle();
    expect(inList(find.text('apple')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a hit hidden only by favorites says so', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      seed: (service) async {
        await HomeAppHarness.work(service, 'apple');
        final banana = await HomeAppHarness.work(service, 'banana');
        await service.setFavorite(banana.id, true);
      },
    );
    await tester.tap(find.widgetWithText(FilterChip, ja.homeFavoritesOnly));
    await tester.pumpAndSettle();
    await search(tester, 'apple');
    // 「apple」は検索には当たるが、お気に入りではない（お気に入りはほかに
    // あるので、登録の説明は出さない）。
    expect(
      inList(find.text(ja.projectListNoMatchTitle('apple'))),
      findsNothing,
    );
    expect(
      inList(find.text(ja.projectListNoFavoriteMatchTitle('apple'))),
      findsOneWidget,
    );
    expect(inList(find.text(ja.projectListNoFavoritesHint)), findsNothing);
    await tester.tap(inList(find.text(ja.projectListShowAll)));
    await tester.pumpAndSettle();
    expect(inList(find.text('apple')), findsOneWidget);
    await home.close();
  });

  testWidgets('an empty folder says so', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(seed: (service) => service.createFolder('空'));
    await tester.tap(inList(find.text('空')));
    await tester.pumpAndSettle();
    expect(inList(find.text(ja.projectListEmptyFolderTitle)), findsOneWidget);
    expect(inList(find.text(ja.projectListEmptyTitle)), findsNothing);
    await home.close();
  });

  // 7言語・320/360/1280px・文字1倍/2倍で、空の表示とボタンがはみ出さず、
  // ボタンの名前が切れない。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('filtered empty states fit in $language', (tester) async {
      await loadAppFonts(tester);
      final l10n = lookupAppLocalizations(_locale(language));
      final home = HomeAppHarness.prepare(tester, language: language);
      await home.open(seed: (service) => HomeAppHarness.work(service, 'apple'));
      await search(tester, 'zzz');
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 800), textScale: scale);
          final why = '$language $width x$scale';
          expect(tester.takeException(), isNull, reason: why);
          final button = inList(find.text(l10n.projectListClearSearch));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: button, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: why);
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0), reason: why);
          expect(rect.right, lessThanOrEqualTo(width), reason: why);
          // 左下・右下に浮く丸いボタンに重ならない。
          final outlined = tester.getRect(
            find.ancestor(of: button, matching: find.byType(OutlinedButton)),
          );
          for (final fab
              in find
                  .byType(FloatingActionButton)
                  .evaluate()
                  .map(
                    (e) =>
                        tester.getRect(find.byElementPredicate((x) => x == e)),
                  )) {
            expect(outlined.overlaps(fab), isFalse, reason: '$why $fab');
          }
        }
      }
      await home.close();
    });
  }

  // 選ぶ専用画面（ホーム画面ウィジェットの作品選び）では、カードに
  // メニューが無いので、メニューを指すお気に入りの説明を出さない。
  testWidgets('the picker list hides the menu hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => ProjectService(),
            child: ProjectListWidget(
              projects: const [],
              viewMode: ProjectViewMode.detail,
              sortMode: ProjectSortMode.updatedDesc,
              isSelectionMode: false,
              selectedIds: const {},
              onLongPress: (_) {},
              onSelectionChanged: (_) {},
              currentFolderId: null,
              onOpenFolder: (_) {},
              showFavoritesOnly: true,
              onPickProject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(ja.projectListNoFavoritesTitle), findsOneWidget);
    expect(find.text(ja.projectListNoFavoritesHint), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Locale _locale(String code) => code == 'zh_Hant'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
    : Locale(code);
