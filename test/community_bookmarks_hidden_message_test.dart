import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 自分の作者ページの「ブックマーク」タブで、ブックマークはあるのに出せる
/// 作品が無い（まだ読み込めていない・今は公開されていない）ときは、
/// 「ブックマークした作品がありません」と言わない（DISC008）。
void main() {
  Future<CommunityService> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    final auth = GoogleAuthService();
    await auth.init();
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => CommunityPreviewService()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => PremiumService()),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CommunityAuthorWorksScreen(
            authorId: kDummySelfAuthorId,
            authorName: 'me',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> openBookmarksTab(WidgetTester tester) async {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    await tester.tap(find.text(l10n.communityAuthorTabBookmarks));
    await tester.pumpAndSettle();
  }

  testWidgets('no bookmarks: says there are none', (tester) async {
    final service = await open(tester);
    expect(service.bookmarkedIds, isEmpty);
    await openBookmarksTab(tester);
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(find.text(l10n.communityBookmarksEmptyMessage), findsOneWidget);
    expect(find.text(l10n.communityBookmarksHiddenMessage), findsNothing);
  });

  testWidgets('bookmarks that are not loaded or public: explains why', (
    tester,
  ) async {
    final service = await open(tester);
    // まだ読み込まれていない（または公開されていない）作品のブックマーク。
    // ブックマークは手元へすぐ反映する（接続先の無いビルドでは送信の完了を
    // 待たない）。
    const missing = 'work-not-loaded';
    unawaited(service.toggleBookmark(missing));
    await tester.pumpAndSettle();
    expect(service.bookmarkedIds, contains(missing));
    expect(service.bookmarkedWorksOf(kDummySelfAuthorId), isEmpty);
    await openBookmarksTab(tester);
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(find.text(l10n.communityBookmarksHiddenMessage), findsOneWidget);
    expect(find.text(l10n.communityBookmarksEmptyMessage), findsNothing);
  });
}
