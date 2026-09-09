import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_work_detail_screen.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/settings_service.dart';

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
}
