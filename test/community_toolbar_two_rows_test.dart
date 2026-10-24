import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/screens/community/widgets/video_type_filter.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/help_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

/// 作品広場の上部のツールバーは2段（ユーザー指定）：1段目に画面名、2段目に
/// 通知・動画の種類・表示フィルター・検索・ヘルプ。以前は1段に並べていて、
/// 画面名が「作…」のように途中で切れていた。
void main() {
  testWidgets('the Work Plaza title is never cut off by the toolbar icons', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    final service = CommunityService();
    addTearDown(themes.dispose);
    addTearDown(service.dispose);
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 360.0, 412.0]) {
      for (final locale in AppLocalizations.supportedLocales) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, 800);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<CommunityService>.value(value: service),
                ChangeNotifierProvider(create: (_) => SettingsService()),
                ChangeNotifierProvider(create: (_) => PremiumService()),
                ChangeNotifierProvider(
                  create: (_) => CommunityPreviewService(),
                ),
              ],
              child: MaterialApp(
                theme: themes.themeData,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const CommunityScreen(),
              ),
            ),
          );
          await tester.pump();
          final why = '$width ${locale.toLanguageTag()} x$scale';
          expect(tester.takeException(), isNull, reason: why);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(CommunityScreen)),
          )!;
          final title = find.descendant(
            of: find.byType(AppBar),
            matching: find.text(l10n.communityScreenTitle),
          );
          expect(title, findsOneWidget, reason: why);
          final paragraph = tester.renderObject<RenderParagraph>(title);
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
            ),
            reason: '$why: title cut off',
          );
          // 操作のアイコンは画面名の下の段。
          final actions = find.byKey(const Key('communityToolbarActions'));
          expect(
            tester.getRect(actions).top,
            greaterThanOrEqualTo(tester.getRect(title).bottom),
            reason: why,
          );
          // 通知とヘルプは、画面名を切らずに並べられるときは1段目の右側
          // （ユーザー指定）。並べられないとき（長い画面名・狭い画面・大きな
          // 文字）だけ2段目。
          final row2 = tester.getRect(actions);
          final bell = tester.getRect(
            find.byKey(const Key('communityNotificationsButton')),
          );
          final help = tester.getRect(find.byType(HelpButton));
          if (scale == 1.0 &&
              width >= 360 &&
              const {'ja', 'ko', 'zh'}.contains(locale.languageCode)) {
            expect(bell.bottom, lessThanOrEqualTo(row2.top), reason: why);
            expect(help.bottom, lessThanOrEqualTo(row2.top), reason: why);
          }
          // タブ名は切れない（入りきらないときは横にスクロールする）。
          for (final element
              in find
                  .descendant(
                    of: find.byKey(const Key('communityTabBar')),
                    matching: find.byType(RichText),
                    skipOffstage: false,
                  )
                  .evaluate()) {
            final tab = element.renderObject! as RenderParagraph;
            expect(
              tab.size.width,
              greaterThanOrEqualTo(
                tab.getMaxIntrinsicWidth(double.infinity) - 0.5,
              ),
              reason: '$why: tab "${tab.text.toPlainText()}" cut',
            );
          }
          // 2段目は左に検索窓、右にフィルター（ユーザー指定）。検索窓は左端から
          // 動画の種類のボタンのすぐ手前まで（空白を残さない）。
          final field = find.byKey(const Key('communitySearchField'));
          final tune = tester.getRect(
            find.byKey(const Key('communityContentFilterButton')),
          );
          final videoType = tester.getRect(find.byType(VideoTypeFilterButton));
          if (field.evaluate().isNotEmpty) {
            final box = tester.getRect(field);
            expect(box.width, greaterThanOrEqualTo(140), reason: why);
            expect(box.left, lessThan(12), reason: why);
            expect(videoType.left - box.right, lessThan(12), reason: why);
            expect(tune.left, greaterThan(videoType.left), reason: why);
            if (bell.bottom <= row2.top) {
              expect(width - tune.right, lessThan(12), reason: why);
            }
          } else {
            // 検索窓を置く幅が無いときは、左端の虫眼鏡のボタン。
            final button = tester.getRect(
              find.byKey(const Key('communitySearchButton')),
            );
            expect(button.left, lessThan(12), reason: why);
            expect(
              button.right,
              lessThanOrEqualTo(videoType.left),
              reason: why,
            );
          }
          // 文字の大きさが既定のうちは全部が画面内に収まる。
          if (scale == 1.0) {
            for (final rect in [bell, help]) {
              expect(rect.left, greaterThanOrEqualTo(0), reason: why);
              expect(rect.right, lessThanOrEqualTo(width), reason: why);
            }
            for (final key in [const Key('communityContentFilterButton')]) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.left, greaterThanOrEqualTo(0), reason: why);
              expect(rect.right, lessThanOrEqualTo(width), reason: why);
            }
            final search = tester.getRect(find.byIcon(Icons.search));
            expect(search.left, greaterThanOrEqualTo(0), reason: why);
            expect(search.right, lessThanOrEqualTo(width), reason: why);
            // 表示フィルターは表示の調整のつまみ（目のアイコンは何のボタンか
            // 分かりにくく、自分の投稿では「非公開」の印でもある）。
            expect(
              find.descendant(
                of: find.byKey(const Key('communityContentFilterButton')),
                matching: find.byIcon(Icons.tune),
              ),
              findsOneWidget,
              reason: why,
            );
            expect(
              find.descendant(
                of: actions,
                matching: find.byIcon(Icons.visibility_off_outlined),
              ),
              findsNothing,
              reason: why,
            );
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the preview opens below the toolbar and the tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await themes.init();
    final service = CommunityService();
    final preview = CommunityPreviewService();
    addTearDown(themes.dispose);
    addTearDown(service.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => PremiumService()),
          ChangeNotifierProvider<CommunityPreviewService>.value(value: preview),
        ],
        child: MaterialApp(
          theme: themes.themeData,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(CommunityWorkCard).first);
    await tester.pump();
    expect(preview.work, isNotNull);
    // 以前は高さ100の固定の位置で、2段のバーの下のタブを覆った。
    final tabs = tester.getRect(find.byType(TabBar));
    expect(preview.position.dy, greaterThanOrEqualTo(tabs.bottom));

    // 利用者が動かした位置は、次に開いたときもそのまま。
    preview.close();
    preview.updatePosition(const Offset(20, 300));
    await tester.tap(find.byType(CommunityWorkCard).first);
    await tester.pump();
    expect(preview.position, const Offset(20, 300));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
