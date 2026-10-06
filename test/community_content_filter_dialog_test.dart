import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The plaza's display-filter dialog: it starts from the saved filters,
/// splits what is typed the way the service documents (commas, 「、」 and new
/// lines; a leading # on a tag is dropped), and closes without touching its
/// text controllers after they are gone.
void main() {
  Widget host(
    CommunityService service, {
    Locale locale = const Locale('ja'),
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<CommunityService>.value(value: service),
      ChangeNotifierProvider<SettingsService>(create: (_) => SettingsService()),
      ChangeNotifierProvider<PremiumService>(create: (_) => PremiumService()),
      ChangeNotifierProvider<CommunityPreviewService>(
        create: (_) => CommunityPreviewService(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CommunityScreen(),
    ),
  );

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CommunityScreen)))!;

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('communityContentFilterButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets('pre-fills the saved filters and parses every separator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'community.mutedWords': ['既存の語'],
      'community.mutedTags': ['既存タグ'],
    });
    final service = CommunityService();
    await tester.pumpWidget(host(service));
    await tester.pump();
    await openDialog(tester);

    final words = find.byKey(const Key('communityMutedWordsField'));
    final tags = find.byKey(const Key('communityMutedTagsField'));
    expect(tester.widget<TextField>(words).controller!.text, '既存の語');
    expect(tester.widget<TextField>(tags).controller!.text, '既存タグ');

    await tester.enterText(words, 'ネタバレ、ホラー\n予告, Spoiler，最終回');
    await tester.enterText(tags, '#手描き、＃作画\n風景');
    await tester.tap(find.byKey(const Key('communityContentFilterSaveButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    expect(service.mutedWords, {'ネタバレ', 'ホラー', '予告', 'spoiler', '最終回'});
    expect(service.mutedTags, {'手描き', '作画', '風景'});
  });

  testWidgets('cancel keeps the saved filters', (tester) async {
    SharedPreferences.setMockInitialValues({
      'community.mutedWords': ['既存の語'],
    });
    final service = CommunityService();
    await tester.pumpWidget(host(service));
    await tester.pump();
    await openDialog(tester);

    await tester.enterText(
      find.byKey(const Key('communityMutedWordsField')),
      '別の語',
    );
    await tester.tap(find.text(l10nOf(tester).commonCancel));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(service.mutedWords, {'既存の語'});
  });

  testWidgets('is localized: the buttons and labels follow the app language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    await tester.pumpWidget(host(service, locale: const Locale('en')));
    await tester.pump();
    await openDialog(tester);

    final l10n = l10nOf(tester);
    expect(l10n.localeName, 'en');
    expect(find.text(l10n.commonCancel), findsOneWidget);
    expect(find.text(l10n.commonSave), findsOneWidget);
    expect(find.text(l10n.communityMutedWords), findsOneWidget);
    expect(find.text(l10n.communityMutedTags), findsOneWidget);
    expect(find.textContaining('キャンセル'), findsNothing);
    expect(find.textContaining('保存'), findsNothing);

    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
