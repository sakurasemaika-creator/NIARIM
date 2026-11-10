import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/widgets/mission_completion_dialog.dart';

void main() {
  testWidgets('mission completion popup offers close and Missions navigation',
      (tester) async {
    late BuildContext pageContext;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) {
          pageContext = ctx;
          return const Scaffold(body: Text('Works Plaza'));
        },
      ),
      GoRoute(
        path: '/rewards',
        builder: (_, __) => const Scaffold(body: Text('Missions screen')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('ja'),
      routerConfig: router,
    ));
    final shown = showMissionCompletionDialog(pageContext,
      titles: const ['作品広場を5分開く']);
    await tester.pumpAndSettle();
    expect(find.text('ミッションをクリアしました！'), findsOneWidget);
    expect(find.textContaining('作品広場を5分開く'), findsOneWidget);
    expect(find.byKey(const Key('missionCompletedClose')), findsOneWidget);
    expect(find.byKey(const Key('missionCompletedGoToMissions')), findsOneWidget);
    await tester.tap(find.byKey(const Key('missionCompletedGoToMissions')));
    await tester.pumpAndSettle();
    await shown;
    expect(find.text('Missions screen'), findsOneWidget);
  });

  testWidgets('close leaves Works Plaza in place', (tester) async {
    late BuildContext pageContext;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (ctx, _) {
        pageContext = ctx;
        return const Scaffold(body: Text('Works Plaza'));
      }),
      GoRoute(path: '/rewards',
        builder: (_, __) => const Scaffold(body: Text('Missions screen'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('ja'), routerConfig: router,
    ));
    final shown = showMissionCompletionDialog(pageContext,
      titles: const ['週3日ログイン']);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('missionCompletedClose')));
    await tester.pumpAndSettle();
    await shown;
    expect(find.text('Works Plaza'), findsOneWidget);
    expect(find.text('Missions screen'), findsNothing);
  });
}
