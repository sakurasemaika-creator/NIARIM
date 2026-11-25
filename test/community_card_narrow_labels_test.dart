import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/collection_tile_layout.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 作品広場のカードの小さな字と、ほかの人が付けた名前の書体を見張る。
///
/// - 「横画面」「縦画面」の字は縮めない。入らない幅（スマホの3列）では
///   縦横の印にする。以前は FittedBox で縮め、英語の「Landscape」が
///   5px ほどの読めない字になっていた。
/// - 韓国語・中国語の画面で、かなを含む作品名・作者名（日本語）は白光明朝の
///   1書体で描く。以前は部分フォントにある字と無い字で書体と太さが混ざり、
///   「夜明けの冒険」の「険」だけが細かった。
void main() {
  CommunityWork work(String id, {bool short = false}) => CommunityWork(
    id: id,
    title: '夜明けの冒険',
    authorId: 'creator',
    authorName: 'あにめ工房ミラ',
    viewCount: 1200,
    likeCount: 0,
    bookmarkCount: 278,
    postedAt: DateTime.utc(2026, 10, 22),
    durationSeconds: 90,
    thumbnailColorIndex: 0,
    isShort: short,
  );

  test('かなを含む名前だけ、韓国語・中国語の画面で白光明朝にする', () {
    const base = TextStyle(fontFamily: 'NotoSerifKRSubset');
    for (final code in ['ko', 'zh']) {
      final locale = Locale(code);
      expect(
        userNameStyleFor(locale, '夜明けの冒険', base).fontFamily,
        'HakkouMincho',
      );
      expect(
        userNameStyleFor(locale, 'ｱﾆﾒ工房', base).fontFamily,
        'HakkouMincho',
      );
      expect(
        userNameStyleFor(locale, '새벽의 모험', base).fontFamily,
        'NotoSerifKRSubset',
      );
      expect(
        userNameStyleFor(locale, '黎明冒险', base).fontFamily,
        'NotoSerifKRSubset',
      );
    }
    for (final code in ['ja', 'en', 'es', 'fr']) {
      expect(
        userNameStyleFor(Locale(code), '夜明けの冒険', base).fontFamily,
        'NotoSerifKRSubset',
      );
    }
  });

  testWidgets('縦横の字は縮めず、入らなければ印にする・日本語の題は1書体', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    final community = CommunityService();
    await community.contentFiltersReady;
    addTearDown(community.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final works = [work('a'), work('b', short: true), work('c')];
    var icons = 0, labels = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in [
        CollectionViewSize.small,
        CollectionViewSize.medium,
      ]) {
        for (final width in [320, 360, 390, 412]) {
          for (final scale in [1.0, 1.3]) {
            tester.view.physicalSize = Size(width.toDouble(), 1400);
            await tester.pumpWidget(
              MaterialApp(
                theme: theme.themeDataFor(locale),
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: ChangeNotifierProvider<CommunityService>.value(
                  value: community,
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: CommunityWorkGrid(
                        works: works,
                        bookmarkedIds: const {},
                        viewSize: size,
                        onTapWork: (_) {},
                        onToggleBookmark: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            final scope =
                '${locale.toLanguageTag()} ${size.name} $width x$scale';
            expect(tester.takeException(), isNull, reason: scope);
            for (final w in works) {
              final text = find.byKey(
                ValueKey('community-orientation-${w.id}'),
              );
              final icon = find.byKey(
                ValueKey('community-orientation-icon-${w.id}'),
              );
              if (text.evaluate().isNotEmpty) {
                labels++;
                final paragraph = tester.renderObject<RenderParagraph>(text);
                expect(
                  tester.getSize(text).width,
                  greaterThanOrEqualTo(
                    paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
                  ),
                  reason: '$scope ${w.id}: the label was shrunk',
                );
                expect(
                  find.ancestor(of: text, matching: find.byType(FittedBox)),
                  findsNothing,
                  reason: scope,
                );
              } else {
                icons++;
                expect(icon, findsOneWidget, reason: '$scope ${w.id}');
                expect(
                  tester.getSize(icon).width,
                  18,
                  reason: '$scope ${w.id}',
                );
              }

              final title = tester.widget<Text>(
                find
                    .byWidgetPredicate(
                      (widget) =>
                          widget is Text && widget.semanticsLabel == '夜明けの冒険',
                    )
                    .first,
              );
              final family = title.style?.fontFamily;
              if (locale.languageCode == 'ko' || locale.languageCode == 'zh') {
                expect(family, 'HakkouMincho', reason: scope);
              }
            }
          }
        }
      }
    }
    // 両方の形が実際に出ていること（片方しか出ないなら確かめられていない）。
    expect(icons, greaterThan(0));
    expect(labels, greaterThan(0));
  });

  testWidgets('韓国語の題は、行に入る語を語の途中で折らない', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    final community = CommunityService();
    await community.contentFiltersReady;
    addTearDown(community.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const titles = ['바람에 날리는 머리카락', '비디오테이프의 여름', '안경을 맞춘 날'];
    const locale = Locale('ko');
    for (final width in [320, 360, 390, 412]) {
      for (final size in [
        CollectionViewSize.small,
        CollectionViewSize.medium,
      ]) {
        tester.view.physicalSize = Size(width.toDouble(), 1400);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.themeDataFor(locale),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangeNotifierProvider<CommunityService>.value(
              value: community,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: CommunityWorkGrid(
                    works: [
                      for (var i = 0; i < titles.length; i++)
                        CommunityWork(
                          id: 'ko$i',
                          title: titles[i],
                          authorId: 'creator',
                          authorName: 'creator',
                          viewCount: 10,
                          likeCount: 0,
                          bookmarkCount: 1,
                          postedAt: DateTime.utc(2026, 11, 1),
                          durationSeconds: 30,
                          thumbnailColorIndex: 0,
                        ),
                    ],
                    bookmarkedIds: const {},
                    viewSize: size,
                    onTapWork: (_) {},
                    onToggleBookmark: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final title in titles) {
          final text = find.byWidgetPredicate(
            (w) => w is Text && w.semanticsLabel == title,
          );
          expect(text, findsOneWidget, reason: '$width $title');
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          final lines = ParagraphLines(paragraph);
          for (final at in lines.breaksWithin(0, lines.visible.length)) {
            if (lines.visible[at - 1] == ' ' || lines.visible[at] == ' ') {
              continue;
            }
            // 語の途中で行が変わってよいのは、その語が1行に入らないときだけ。
            final start = lines.visible.lastIndexOf(' ', at) + 1;
            final end = lines.visible.indexOf(' ', at);
            final word = lines.visible.substring(
              start,
              end < 0 ? lines.visible.length : end,
            );
            final painter = TextPainter(
              text: TextSpan(text: word, style: paragraph.text.style),
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout();
            final wide = painter.width;
            painter.dispose();
            expect(
              wide,
              greaterThan(paragraph.size.width),
              reason:
                  '$width ${size.name}: 「${lines.lines.join(' / ')}」の'
                  '「$word」は1行に入るのに途中で折れた',
            );
          }
        }
      }
    }
  });
}
