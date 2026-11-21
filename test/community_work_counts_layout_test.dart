import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/widgets/community_work_counts.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets(
    'localized work metrics stay grouped at narrow widths and enlarged text',
    (tester) async {
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final community = CommunityService();
      addTearDown(community.dispose);
      final work = community.works.first;

      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final width in const [320.0, 360.0, 412.0]) {
          for (final scale in const [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 900);
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<CommunityService>.value(
                    value: community,
                  ),
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
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CommunityWorkCounts(
                        work: work,
                        fontSize: 14,
                        postedLabel: l10n.communityWorkDetailPostedLabel(
                          '12/11/2026 10:06',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final scope =
                '${locale.toLanguageTag()} ${width.round()}dp ×$scale';
            final bookmark = find.byKey(
              ValueKey('community-bookmark-count-${work.id}'),
            );
            final repost = find.byKey(
              ValueKey('community-repost-count-${work.id}'),
            );
            expect(bookmark, findsOneWidget, reason: scope);
            expect(repost, findsOneWidget, reason: scope);
            expect(
              tester.getCenter(bookmark).dy,
              closeTo(tester.getCenter(repost).dy, 1),
              reason: '$scope: bookmark and repost metrics must stay together',
            );
            expect(tester.takeException(), isNull, reason: scope);
          }
        }
      }
    },
  );
}
