import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/screens/community/community_my_works_screen.dart';
import 'package:niarim/screens/community/community_work_settings_screen.dart';
import 'package:niarim/services/community_preview_service.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(CommunityService, GoogleAuthService)> setup(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    final auth = GoogleAuthService();
    await auth.init();
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(MultiProvider(
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
        home: const CommunityMyWorksScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return (service, auth);
  }

  testWidgets('long press, select all, bulk hide/show, and clear selection',
      (tester) async {
    final (service, _) = await setup(tester);
    final works = service.worksByAuthor(
      kDummySelfAuthorId, includeHidden: true,
    );
    expect(works, isNotEmpty);
    final firstId = works.first.id;
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byKey(const Key('communityMyWorksBulkActions')), findsNothing);

    await tester.longPress(find.byKey(ValueKey('communityMyWorksRow-$firstId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityMyWorksBulkActions')), findsOneWidget);
    expect(tester.widget<Material>(
      find.byKey(const Key('communityMyWorksBulkActions'))).elevation, 0);
    expect(find.byKey(ValueKey('communityMyWorksSelect-$firstId')),
        findsOneWidget);
    expect(find.byKey(ValueKey('communityMyWorksSettings-$firstId')),
        findsNothing);
    expect(find.byKey(const Key('communityMyWorksBulkPublish')),
        findsOneWidget);
    expect(find.byKey(const Key('communityMyWorksBulkHide')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('communityMyWorksSelectAll')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityMyWorksBulkHide')));
    await tester.pumpAndSettle();
    expect(service.worksByAuthor(kDummySelfAuthorId, includeHidden: true)
        .every((work) => !work.isNiarimPublished), isTrue);
    expect(find.byKey(const Key('communityMyWorksBulkActions')), findsNothing);

    await tester.tap(find.byKey(const Key('communityMyWorksSelectAll')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityMyWorksBulkPublish')));
    await tester.pumpAndSettle();
    expect(service.worksByAuthor(kDummySelfAuthorId, includeHidden: true)
        .every((work) => work.isNiarimPublished), isTrue);

    await tester.tap(find.byKey(const Key('communityMyWorksSelectAll')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityMyWorksClearSelection')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityMyWorksBulkActions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrench opens per-work settings; AI and delete are individual',
      (tester) async {
    final (service, _) = await setup(tester);
    final work = service.worksByAuthor(
      kDummySelfAuthorId, includeHidden: true,
    ).first;
    await tester.tap(find.byKey(ValueKey('communityMyWorksSettings-${work.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkSettingsScreen), findsOneWidget);
    expect(find.byKey(const Key('communityWorkSettingsVisibility')),
        findsOneWidget);
    expect(find.byKey(const Key('communityWorkSettingsAiFlag')),
        findsOneWidget);
    expect(find.byKey(const Key('communityWorkTagAdd')), findsOneWidget);
    expect(find.byKey(const Key('communityMyWorksBulkActions')), findsNothing);

    final before = work.containsGenerativeAiImageOrVideo;
    await tester.tap(find.byKey(const Key('communityWorkSettingsAiFlag')));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.containsGenerativeAiImageOrVideo, !before);

    await tester.scrollUntilVisible(
      find.byKey(const Key('communityWorkSettingsDelete')), 160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('communityWorkSettingsDelete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityWorkSettingsConfirmDelete')),
        findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(service.byId(work.id), isNotNull);

    await tester.tap(find.byKey(const Key('communityWorkSettingsDelete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('communityWorkSettingsConfirmDelete')));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityWorkSettingsScreen), findsNothing);
    expect(service.byId(work.id), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner can add, edit, lock, unlock and remove work tags',
      (tester) async {
    final (service, _) = await setup(tester);
    final work = service.worksByAuthor(
      kDummySelfAuthorId, includeHidden: true,
    ).first;
    await tester.tap(find.byKey(ValueKey('communityMyWorksSettings-${work.id}')));
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('communityWorkTagAdd'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('communityWorkTagInput')), '追加テスト');
    await tester.tap(find.byKey(const Key('communityWorkTagSave')));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.tags, contains('追加テスト'));

    await tester.tap(find.byKey(const Key('communityWorkTagEdit-追加テスト')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('communityWorkTagInput')), '編集済み');
    await tester.tap(find.byKey(const Key('communityWorkTagSave')));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.tags, contains('編集済み'));
    expect(service.byId(work.id)!.tags, isNot(contains('追加テスト')));

    await tester.tap(find.byKey(const Key('communityWorkTagLock-編集済み')));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.lockedTags, contains('編集済み'));
    expect(tester.widget<IconButton>(
      find.byKey(const Key('communityWorkTagDelete-編集済み'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('communityWorkTagLock-編集済み')));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.lockedTags, isNot(contains('編集済み')));
    await tester.tap(find.byKey(const Key('communityWorkTagDelete-編集済み')));
    await tester.pumpAndSettle();
    expect(service.byId(work.id)!.tags, isNot(contains('編集済み')));
  });

  testWidgets('my public works page button appears directly under Post',
      (tester) async {
    await setup(tester);
    final post = find.byKey(const Key('communityMyWorksPostButton'));
    final page = find.byKey(const Key('communityMyWorksViewAuthorPage'));
    expect(tester.getRect(post).bottom, lessThan(tester.getRect(page).top));
    await tester.tap(page);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAuthorWorksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
