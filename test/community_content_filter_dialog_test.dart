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

/// Muted words and tags are managed as independent rows. Draft edits are
/// persisted together on Save and discarded on Cancel.
void main() {
  Widget host(CommunityService service, {Locale locale = const Locale('ja')}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: service),
          ChangeNotifierProvider<SettingsService>(
            create: (_) => SettingsService(),
          ),
          ChangeNotifierProvider<PremiumService>(
            create: (_) => PremiumService(),
          ),
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

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tapVisible(
      tester,
      find.byKey(const Key('communityContentFilterButton')),
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets('pre-fills each row, edits with pencil and adds without commas', (
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

    final words0 = find.byKey(const Key('communityMutedWordsEntry_0'));
    final tags0 = find.byKey(const Key('communityMutedTagsEntry_0'));
    expect(tester.widget<TextFormField>(words0).initialValue, '既存の語');
    expect(tester.widget<TextFormField>(tags0).initialValue, '既存タグ');
    expect(tester.getTopLeft(words0).dy, lessThan(tester.getTopLeft(tags0).dy));
    expect(tester.getTopLeft(tags0).dy,
        lessThan(tester.getTopLeft(find.byType(SwitchListTile)).dy));

    await tapVisible(tester, find.byKey(const Key('communityMutedWordsEdit_0')));
    await tester.enterText(words0, 'ネタバレ');
    await tapVisible(tester, find.byKey(const Key('communityMutedWordsAddButton')));
    await tester.enterText(
      find.byKey(const Key('communityMutedWordsEntry_1')),
      'ホラー',
    );
    await tapVisible(tester, find.byKey(const Key('communityMutedTagsEdit_0')));
    await tester.enterText(tags0, '風景');
    await tapVisible(tester, find.byKey(const Key('communityMutedTagsAddButton')));
    await tester.enterText(
      find.byKey(const Key('communityMutedTagsEntry_1')),
      '手描き',
    );
    await tapVisible(
      tester,
      find.byKey(const Key('communityContentFilterSaveButton')),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    expect(service.mutedWords, {'ネタバレ', 'ホラー'});
    expect(service.mutedTags, {'風景', '手描き'});
  });

  testWidgets('trash removes one row; Cancel keeps the original settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'community.mutedWords': ['残す', '消す'],
      'community.mutedTags': ['タグ'],
    });
    final service = CommunityService();
    await tester.pumpWidget(host(service));
    await tester.pump();
    await openDialog(tester);

    await tapVisible(tester, find.byKey(const Key('communityMutedWordsDelete_1')));
    expect(find.byKey(const Key('communityMutedWordsEntry_1')), findsNothing);
    expect(
      tester.widget<TextFormField>(
        find.byKey(const Key('communityMutedWordsEntry_0')),
      ).initialValue,
      '残す',
    );
    await tapVisible(tester, find.text(l10nOf(tester).commonCancel));
    expect(service.mutedWords, {'残す', '消す'});
    await openDialog(tester);
    expect(find.byKey(const Key('communityMutedWordsEntry_1')), findsOneWidget);
    await tapVisible(tester, find.text(l10nOf(tester).commonCancel));
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank additions do not save and tags need no #', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    await tester.pumpWidget(host(service));
    await tester.pump();
    await openDialog(tester);

    await tapVisible(tester, find.byKey(const Key('communityMutedWordsAddButton')));
    await tapVisible(tester, find.byKey(const Key('communityMutedTagsAddButton')));
    await tester.enterText(
      find.byKey(const Key('communityMutedTagsEntry_0')),
      '作画',
    );
    await tapVisible(
      tester,
      find.byKey(const Key('communityContentFilterSaveButton')),
    );
    expect(service.mutedWords, isEmpty);
    expect(service.mutedTags, {'作画'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('localized section headings use the Kuramubon font', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    await tester.pumpWidget(host(service, locale: const Locale('en')));
    await tester.pump();
    await openDialog(tester);

    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonCancel), findsOneWidget);
    expect(find.text(l10n.commonSave), findsOneWidget);
    for (final label in [l10n.communityMutedWords, l10n.communityMutedTags]) {
      expect(tester.widget<Text>(find.text(label)).style?.fontFamily, 'Kuramubon');
    }
    expect(find.text(l10n.communityMuteAddNew), findsNWidgets(2));
    expect(find.textContaining('キャンセル'), findsNothing);
    await tapVisible(tester, find.text(l10n.commonCancel));
    expect(tester.takeException(), isNull);
  });
}
