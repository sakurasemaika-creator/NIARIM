// 作品を開いている間、下に残るホームは作品の変更で組み立て直さず、戻る
// 動きの最初のフレームで最新の内容になることを確かめる（lib/widgets/
// hidden_route_project_gate.dart）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/home/home_screen.dart';

import 'helpers/home_app_harness.dart';

void main() {
  Future<void> settleReal(WidgetTester tester, [int times = 8]) async {
    for (var i = 0; i < times; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [run]の間に組み立て直したホームの中の部品の数。
  Future<int> homeRebuildsDuring(
    WidgetTester tester,
    Future<void> Function() run,
  ) async {
    final home = tester.element(find.byType(HomeScreen, skipOffstage: false));
    var count = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      var under = identical(element, home);
      if (!under) {
        element.visitAncestorElements((a) {
          if (identical(a, home)) under = true;
          return !under;
        });
      }
      if (under) count++;
    };
    try {
      await run();
    } finally {
      debugOnRebuildDirtyWidget = null;
    }
    return count;
  }

  testWidgets('キャンバスの下のホームは作品を変えても組み立て直さず、戻る最初のフレームで新しい名前を出す', (tester) async {
    final h = HomeAppHarness.prepare(tester);
    late String id;
    final service = await h.open(
      seed: (s) async {
        for (var i = 0; i < 3; i++) {
          id = (await HomeAppHarness.work(s, '作品$i')).id;
        }
      },
    );
    expect(h.shownNames(), contains('作品2'));

    appRouter.push('/canvas/$id');
    await settleReal(tester);
    expect(find.byType(CanvasArea), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing, reason: '覆われて見えない');

    final rebuilds = await homeRebuildsDuring(tester, () async {
      await tester.runAsync(() => service.renameProject(id, '新しい名前'));
      final scene = service.scenesOf(id).first;
      service.addFrame(id, scene.id);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    });
    expect(rebuilds, 0, reason: '見えない間は組み立て直さない');

    appRouter.pop();
    // 戻る動きの最初のフレームで、ホームはもう新しい名前を出している。
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(h.shownNames(), contains('新しい名前'));
    expect(h.shownNames(), isNot(contains('作品2')));
    await settleReal(tester);
    expect(h.shownNames(), contains('新しい名前'));
    await h.close();
  });

  testWidgets('ダイアログの下のホームは見えているので、すぐ新しい名前を出す', (tester) async {
    final h = HomeAppHarness.prepare(tester);
    late String id;
    final service = await h.open(
      seed: (s) async => id = (await HomeAppHarness.work(s, '前の名前')).id,
    );
    showDialog<void>(
      context: tester.element(find.byType(HomeScreen)),
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await h.settle();
    expect(find.text('dialog'), findsOneWidget);

    final rebuilds = await homeRebuildsDuring(tester, () async {
      await tester.runAsync(() => service.renameProject(id, '後の名前'));
      await tester.pump();
    });
    expect(rebuilds, greaterThan(0));
    expect(h.shownNames(), contains('後の名前'));
    await h.close();
  });
}
