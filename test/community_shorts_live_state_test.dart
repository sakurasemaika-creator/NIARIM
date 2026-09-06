import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/community_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('縦画面はブックマーク変更を即時反映し詳細情報アイコンを動画外UIに持つ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityService();
    final work = service.works.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<CommunityService>.value(
        value: service,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityShortsScreen(
            works: [work],
            bookmarkedIds: const <String>{},
            onToggleBookmark: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(service.isBookmarked(work.id), isFalse);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(service.isBookmarked(work.id), isTrue);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pump();

    expect(service.isBookmarked(work.id), isFalse);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });
}
