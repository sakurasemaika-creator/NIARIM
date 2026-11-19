import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/google_auth_service.dart';

void main() {
  testWidgets('作品詳細では10タグ到達時に追加チップを無効化する', (tester) async {
    final service = CommunityService();
    final work = service.works.first;

    for (var i = 0; i < CommunityService.maxTagsPerWork; i++) {
      service.addTag(work.id, 'limit_tag_$i');
    }
    final full = service.byId(work.id)!;
    expect(full.tags.length, CommunityService.maxTagsPerWork);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityService>.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => GoogleAuthService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityWorkDetailScreen(workId: work.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addChipFinder = find.byWidgetPredicate(
      (widget) => widget is ActionChip && widget.avatar is Icon,
    );
    final chips = tester.widgetList<ActionChip>(addChipFinder).toList();
    final addChip = chips.firstWhere(
      (chip) => (chip.avatar as Icon).icon == Icons.add,
    );
    expect(addChip.onPressed, isNull);
  });

  testWidgets('投稿者の編集可能タグでは4つの操作を横に並べる', (tester) async {
    final service = CommunityService();
    addTearDown(service.dispose);
    final work = service.works.first;
    service.setCurrentUserId(work.authorId);
    await service.addTag(work.id, 'tag_to_edit');
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => GoogleAuthService()),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityWorkDetailScreen(workId: work.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tag = find.text('tag_to_edit');
    await tester.ensureVisible(tag);
    await tester.pumpAndSettle();
    await tester.tap(tag);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    Finder action(String name) => find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextButton, name).hitTestable(),
    );
    final centers = [
      for (final name in ['キャンセル', '編集', '削除', 'ロック'])
        tester.getCenter(action(name)),
    ];
    for (var i = 1; i < centers.length; i++) {
      expect(centers[i].dy, closeTo(centers.first.dy, 1));
      expect(centers[i].dx, greaterThan(centers[i - 1].dx));
    }
    await tester.tap(action('削除'));
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(find.text(l10n.communityTagDeleteConfirm), findsOneWidget);
    expect(service.byId(work.id)!.tags, contains('tag_to_edit'));
    expect(tester.takeException(), isNull);
  });
}
