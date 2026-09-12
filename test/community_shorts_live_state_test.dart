import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/community_author_works_screen.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/community_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('縦画面はブックマーク・詳細情報・作者導線・制作情報を即時反映する', (tester) async {
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

    // 詳細情報アイコンとNIARIM制作情報は動画外パネルに存在する。
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.text('${work.projectFrameCount}f'), findsOneWidget);
    expect(find.text('${work.projectFps}fps'), findsOneWidget);
    expect(
      find.text('${work.projectCanvasWidth}×${work.projectCanvasHeight}'),
      findsOneWidget,
    );

    // bookmark_outlineは制作情報の件数アイコンにも使われ、Flutterでは
    // bookmark_borderと同じIconData alias。操作ボタンだけを対象にする。
    final bookmarkBorderButton = find.descendant(
      of: find.byType(IconButton),
      matching: find.byIcon(Icons.bookmark_border),
    );
    expect(bookmarkBorderButton, findsOneWidget);
    expect(service.isBookmarked(work.id), isFalse);

    await tester.tap(bookmarkBorderButton);
    await tester.pump();

    expect(service.isBookmarked(work.id), isTrue);
    final bookmarkedButton = find.descendant(
      of: find.byType(IconButton),
      matching: find.byIcon(Icons.bookmark),
    );
    expect(bookmarkedButton, findsOneWidget);
    expect(bookmarkBorderButton, findsNothing);

    await tester.tap(bookmarkedButton);
    await tester.pump();

    expect(service.isBookmarked(work.id), isFalse);
    expect(bookmarkBorderButton, findsOneWidget);

    // 作者アイコン/作者名の領域から作者作品一覧へ遷移できる。
    await tester.tap(find.text(work.authorName));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAuthorWorksScreen), findsOneWidget);
  });
}
