import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';

import 'helpers/home_clipboard_harness.dart';

void main() {
  testWidgets('20,034 exports can be opened, long-pressed and selected', (
    tester,
  ) async {
    const count = 20034;
    final gif = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
    );
    final home = await HomeClipboardHarness.open(
      tester,
      size: const Size(390, 844),
      beforeBoot: (dir) {
        for (var i = 0; i < count; i++) {
          File(
            '${dir.path}/exports/Fixture ${i.toString().padLeft(5, '0')}.gif',
          ).writeAsBytesSync(gif);
        }
      },
    );
    final scan = Stopwatch()..start();
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    scan.stop();

    final watch = Stopwatch();
    Future<int> measure(Future<void> Function() operation) async {
      watch
        ..reset()
        ..start();
      await operation();
      watch.stop();
      return watch.elapsedMilliseconds;
    }

    final first = find.byType(ExportedWorkCard).hitTestable().first;
    final toolbar = find.byType(HomeSelectionToolbar);
    for (var sample = 0; sample < 3; sample++) {
      final tab = await measure(() => home.showTab(1));
      expect(first, findsOneWidget);
      final hold = await measure(() async {
        await tester.longPress(first);
        await home.settle();
      });
      expect(tester.widget<HomeSelectionToolbar>(toolbar).selectedCount, 1);
      final selectAll = await measure(() async {
        await tester.tap(find.byTooltip(home.l10n.homeSelectionAllSelect));
        await home.settle();
      });
      final selected = tester.widget<HomeSelectionToolbar>(toolbar);
      expect(selected.selectedCount, count);
      expect(selected.onCut, isNull);
      expect(selected.onCopy, isNull);
      expect(selected.cutUnavailableReason, home.l10n.homeSelectionOneAtATime);
      expect(selected.copyUnavailableReason, home.l10n.homeSelectionOneAtATime);
      debugPrint(
        'WORKS $count scan=${scan.elapsedMilliseconds}ms '
        'sample=${sample + 1} tab=${tab}ms hold=${hold}ms '
        'all=${selectAll}ms',
      );
      await home.showTab(0);
    }
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
