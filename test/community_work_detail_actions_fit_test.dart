// 作品の詳細の「YouTubeで見る」とブックマークのボタンが、狭い幅・大きな
// 文字でも押しつぶされず、名前を語の途中で折らないことを見張る。
//
// 以前は「YouTubeで見る」を`Expanded`で広げた行にブックマークのボタンを
// 名前の幅のまま並べていた。仏語360px×文字1.0では「Retirer des favoris」が
// 行の大半を取り、「Voir sur YouTube」が4行（「Voir / sur / You / Tube」）に
// 押しつぶされて、名前がボタンの枠を越えた。2つが名前の幅のまま1行に入らない
// ときは、1つずつの行に分ける。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/text_fit_problems.dart';

/// 段落[p]が描く行の数（書体の違う字が混ざっても、行の数で数える）。
int _lines(RenderParagraph p) {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    locale: p.locale,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.constraints.maxWidth);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('7言語×320/360/412/1280px×文字1.0/2.0で、2つのボタンの名前を'
      '語の途中で折らず、1行に入らない名前は無い', (tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final problems = <String>[];
    for (final bookmarked in [false, true]) {
      final service = CommunityService();
      final work = service.works.first;
      if (bookmarked) await service.toggleBookmark(work.id);
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        for (final size in const [
          Size(320, 3000),
          Size(360, 3000),
          Size(412, 3000),
          Size(1280, 3000),
        ]) {
          for (final scale in const [1.0, 2.0]) {
            final where =
                '${locale.toLanguageTag()} ${size.width.round()}px ×$scale'
                '${bookmarked ? ' ブックマーク済み' : ''}';
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<CommunityService>.value(
                    value: service,
                  ),
                  ChangeNotifierProvider(create: (_) => SettingsService()),
                  ChangeNotifierProvider(create: (_) => GoogleAuthService()),
                ],
                child: MaterialApp(
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: ThemeService().themeDataFor(locale),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: CommunityWorkDetailScreen(workId: work.id),
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final label in [
              l.communityWorkDetailViewOnYoutube,
              bookmarked
                  ? l.communityWorkDetailBookmarkRemove
                  : l.communityWorkDetailBookmarkAdd,
            ]) {
              final text = find.text(label);
              if (text.evaluate().isEmpty) {
                // アイコンの形なら、名前は吹き出しで分かること。
                if (find.byTooltip(label).evaluate().isEmpty) {
                  problems.add('$where: «$label»のボタンが無い');
                }
                continue;
              }
              final p = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: text.first,
                  matching: find.byType(RichText),
                ),
              );
              for (final problem in textFitProblems(p)) {
                problems.add('$where: «$label» $problem');
              }
              final lines = _lines(p);
              if (lines > 1) {
                problems.add('$where: «$label»が$lines行に折れる');
              }
            }
          }
        }
      }
      service.dispose();
    }
    expect(
      problems,
      isEmpty,
      reason: '${problems.length}件\n${problems.join('\n')}',
    );
  });
}
