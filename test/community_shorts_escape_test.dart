import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/community/widgets/community_shorts_viewer.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Esc did nothing in the Work Plaza's portrait (shorts) viewer; only its ×
/// button left it (found by walking the app against a local copy of the
/// backend, 2026-11-28). Esc now leaves it, as the × does, wherever the
/// focus is on the screen; an open menu closes first.
void main() {
  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final community = CommunityService();
    addTearDown(community.dispose);
    final works = community.discoverableWorks.take(3).toList();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: community,
        child: MaterialApp(
          locale: const Locale('ja'),
          scrollBehavior: const AppScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityShortsScreen(
                      works: works,
                      bookmarkedIds: const {},
                      onToggleBookmark: (_) {},
                    ),
                  ),
                ),
                child: const Text('Open shorts'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open shorts'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityShortsScreen), findsOneWidget);
  }

  testWidgets('Esc leaves the portrait viewer', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityShortsScreen), findsNothing);
    expect(find.text('Open shorts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the end-of-video menu open, Esc closes the menu first', (
    tester,
  ) async {
    await open(tester);
    final l10n = lookupAppLocalizations(const Locale('ja'));
    await tester.tap(find.byType(PopupMenuButton<CommunityShortsEndBehavior>));
    await tester.pumpAndSettle();
    final loop = find.text(l10n.communityShortsEndBehaviorLoop);
    expect(loop, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(loop, findsNothing);
    expect(find.byType(CommunityShortsScreen), findsOneWidget);

    // The focus is back on the header's menu button, outside the pages.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityShortsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
