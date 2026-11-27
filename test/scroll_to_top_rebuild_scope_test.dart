// 一覧を一番上から送り出したとき・一番上へ戻したとき、「↑」のボタンだけを
// 組み立て直し、画面（ホーム・作品広場）ごと組み立て直さないことを確かめる。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/community/community_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';

import 'helpers/home_app_harness.dart';

/// [run]の間に[screen]の画面そのもの（State.build）を組み立て直した回数。
Future<int> screenRebuildsDuring(
  WidgetTester tester,
  Finder screen,
  Future<void> Function() run,
) async {
  final element = tester.element(screen);
  var count = 0;
  debugOnRebuildDirtyWidget = (e, _) {
    if (identical(e, element)) count++;
  };
  try {
    await run();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return count;
}

Scrollable longestVerticalList(WidgetTester tester) {
  ScrollableState? best;
  for (final e in find.byType(Scrollable).evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.position.axis != Axis.vertical) continue;
    if (best == null ||
        s.position.maxScrollExtent > best.position.maxScrollExtent) {
      best = s;
    }
  }
  return best!.widget;
}

void main() {
  testWidgets('ホーム：「↑」が出る・消えるときにホームの画面ごと組み立て直さない', (tester) async {
    final h = HomeAppHarness.prepare(tester);
    await h.open(
      seed: (s) async {
        for (var i = 0; i < 30; i++) {
          await HomeAppHarness.work(s, '作品$i');
        }
      },
    );
    const up = Key('homeScrollToTopFab');
    expect(find.byKey(up), findsNothing);
    final list = find.byWidget(longestVerticalList(tester));

    final down = await screenRebuildsDuring(
      tester,
      find.byType(HomeScreen),
      () async {
        await tester.drag(list, const Offset(0, -400));
        await h.settle();
      },
    );
    expect(find.byKey(up), findsOneWidget);
    expect(down, 0);

    final back = await screenRebuildsDuring(
      tester,
      find.byType(HomeScreen),
      () async {
        await tester.tap(find.byKey(up));
        await h.settle();
        await h.settle();
      },
    );
    expect(find.byKey(up), findsNothing);
    expect(back, 0);
    await h.close();
  });

  testWidgets('作品広場：「↑」が出るときに作品広場の画面ごと組み立て直さない', (tester) async {
    final h = HomeAppHarness.prepare(tester);
    await h.open();
    appRouter.push('/community');
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    const up = Key('communityScrollToTopButton');
    expect(find.byKey(up), findsNothing);
    final list = find.byWidget(longestVerticalList(tester));
    final rebuilds = await screenRebuildsDuring(
      tester,
      find.byType(CommunityScreen),
      () async {
        await tester.drag(list, const Offset(0, -300));
        await h.settle();
      },
    );
    expect(find.byKey(up), findsOneWidget);
    expect(rebuilds, 0);
    await h.close();
  });
}
