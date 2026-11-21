import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// 「お気に入りだけ」で一覧が空のとき、お気に入りがほかの場所にあるのに
/// 「お気に入りの作品はありません」「メニューで『お気に入り登録』を選ぶと…」と
/// 言わない（作品を登録済みの利用者に、登録するよう促していた）。
/// 探している言葉に当たるお気に入りが無い・このフォルダに無い・フォルダの
/// 外に無い、のどれかを言い、「すべて表示」を出す。登録の説明は、お気に入りが
/// 1つも無いときだけ。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  Finder inList(Finder finder) => HomeAppHarness.inProjects(finder);

  Future<void> favoritesOnly(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilterChip, ja.homeFavoritesOnly));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.tap(find.byKey(const Key('homeSearchButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('homeSearchInput')), query);
    await tester.pumpAndSettle();
  }

  // お気に入りが無いとは言わない。
  void expectNoFalseClaim(String why) {
    expect(
      inList(find.text(ja.projectListNoFavoritesTitle)),
      findsNothing,
      reason: why,
    );
    expect(
      inList(find.text(ja.projectListNoFavoritesHint)),
      findsNothing,
      reason: why,
    );
    expect(inList(find.text(ja.projectListShowAll)), findsOneWidget);
  }

  testWidgets('a search hit that is not a favorite names the search', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      seed: (service) async {
        await HomeAppHarness.work(service, 'apple');
        final banana = await HomeAppHarness.work(service, 'banana');
        await service.setFavorite(banana.id, true);
      },
    );
    await favoritesOnly(tester);
    await search(tester, 'apple');
    expectNoFalseClaim('search');
    expect(inList(find.text('「apple」に一致するお気に入りはありません')), findsOneWidget);
    await tester.tap(inList(find.text(ja.projectListShowAll)));
    await tester.pumpAndSettle();
    expect(inList(find.text('apple')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a folder without favorites says so', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      seed: (service) async {
        final folder = await service.createFolder('F');
        await HomeAppHarness.work(service, 'apple', folderId: folder.id);
        final banana = await HomeAppHarness.work(service, 'banana');
        await service.setFavorite(banana.id, true);
      },
    );
    await tester.tap(inList(find.text('F')).first);
    await tester.pumpAndSettle();
    await favoritesOnly(tester);
    expectNoFalseClaim('folder');
    expect(inList(find.text('このフォルダにお気に入りはありません')), findsOneWidget);
    await tester.tap(inList(find.text(ja.projectListShowAll)));
    await tester.pumpAndSettle();
    expect(inList(find.text('apple')), findsOneWidget);
    await home.close();
  });

  testWidgets('favorites only inside folders are not called missing', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      seed: (service) async {
        final folder = await service.createFolder('F');
        final apple = await HomeAppHarness.work(
          service,
          'apple',
          folderId: folder.id,
        );
        await service.setFavorite(apple.id, true);
        await HomeAppHarness.work(service, 'banana');
      },
    );
    await favoritesOnly(tester);
    expectNoFalseClaim('top level');
    expect(inList(find.text('フォルダの外にお気に入りはありません')), findsOneWidget);
    await home.close();
  });

  // お気に入りが1つも無いときは、今までどおり登録の説明を出す。
  testWidgets('without any favorite the menu hint stays', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      seed: (service) async {
        final folder = await service.createFolder('F');
        await HomeAppHarness.work(service, 'apple', folderId: folder.id);
      },
    );
    await favoritesOnly(tester);
    expect(inList(find.text(ja.projectListNoFavoritesTitle)), findsOneWidget);
    expect(inList(find.text(ja.projectListNoFavoritesHint)), findsOneWidget);
    await tester.tap(inList(find.text(ja.projectListShowAll)));
    await tester.pumpAndSettle();
    expect(inList(find.text('F')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 7言語・320/360/1280px・文字1倍/2倍で、新しい3つの文がはみ出さず、
  // 「すべて表示」が切れず、左下・右下に浮く丸いボタンに重ならない。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('favorite empty states fit in $language', (tester) async {
      await loadAppFonts(tester);
      final l10n = lookupAppLocalizations(
        language == 'zh_Hant'
            ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
            : Locale(language),
      );
      final home = HomeAppHarness.prepare(tester, language: language);
      await home.open(
        size: const Size(360, 800),
        seed: (service) async {
          final folder = await service.createFolder('F');
          await HomeAppHarness.work(service, 'apple', folderId: folder.id);
          final banana = await HomeAppHarness.work(
            service,
            'banana',
            folderId: folder.id,
          );
          await service.setFavorite(banana.id, true);
          await service.createFolder('G');
        },
      );
      final chip = find.widgetWithText(FilterChip, l10n.homeFavoritesOnly);

      Future<void> expectFits(String title, String why) async {
        for (final width in [320.0, 360.0, 1280.0]) {
          for (final scale in [1.0, 2.0]) {
            await home.resize(Size(width, 800), textScale: scale);
            final reason = '$why $language $width x$scale';
            expect(tester.takeException(), isNull, reason: reason);
            final shown = inList(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.data ??
                            w.textSpan
                                ?.toPlainText(includeSemanticsLabels: false)
                                .replaceAll('\u2060', '')) ==
                        title,
              ),
            );
            expect(shown, findsOneWidget, reason: reason);
            final button = inList(find.text(l10n.projectListShowAll));
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: button, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
            final outlined = tester.getRect(
              find.ancestor(of: button, matching: find.byType(OutlinedButton)),
            );
            expect(outlined.left, greaterThanOrEqualTo(0), reason: reason);
            expect(outlined.right, lessThanOrEqualTo(width), reason: reason);
            for (final fab in find.byType(FloatingActionButton).evaluate()) {
              final rect = tester.getRect(
                find.byElementPredicate((e) => e == fab),
              );
              expect(outlined.overlaps(rect), isFalse, reason: reason);
            }
          }
        }
      }

      // 一番上：お気に入りはフォルダの中にだけある。
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await expectFits(
        l10n.projectListNoFavoritesOutsideFoldersTitle,
        'top level',
      );
      // お気に入りの無いフォルダの中。
      await tester.tap(inList(find.text(l10n.projectListShowAll)));
      await tester.pumpAndSettle();
      await tester.tap(inList(find.text('G')).first);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await expectFits(l10n.projectListNoFavoritesInFolderTitle, 'folder');
      // 探している言葉に当たるお気に入りが無い。
      await search(tester, 'apple');
      await expectFits(l10n.projectListNoFavoriteMatchTitle('apple'), 'search');
      await home.close();
    });
  }
}
