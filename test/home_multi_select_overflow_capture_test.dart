// The owner's screenshot (an older build: three tabs, a selection bar with
// select all, deselect all, the count, two favourite stars, cut, copy and
// trash in one row) showed "RIGHT OVERFLOWED" when a card was long-pressed
// on a phone. Long-press a card on the current home at the screenshot's
// width (390) and narrower, in Japanese: nothing overflows and the bar's
// actions stay on screen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';

import 'helpers/home_matrix_harness.dart';

void main() {
  final run = HomeMatrixRun(Directory('build/home-multi-select'));
  setUpAll(run.prepare);

  for (final width in const [390.0, 360.0, 320.0]) {
    testWidgets('long-pressing a card on a ${width.toInt()}px phone does not '
        'overflow', (tester) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        await m.resize(Size(width, kHomeMatrixPhoneHeight));
        await m.show(HomeView.projects);
        // As in the screenshot: a folder card long-pressed.
        final folder = find.text('シリーズ').first;
        await tester.ensureVisible(folder);
        await m.frames(3);
        await tester.longPress(folder);
        await m.frames(8);
        expect(find.byType(HomeSelectionToolbar), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$width');
        final bar = tester.getRect(find.byType(HomeSelectionToolbar));
        for (final button
            in find
                .descendant(
                  of: find.byType(HomeSelectionToolbar),
                  matching: find.byType(IconButton),
                )
                .evaluate()) {
          final rect = tester.getRect(find.byWidget(button.widget));
          expect(rect.right, lessThanOrEqualTo(bar.right + .5));
          expect(rect.left, greaterThanOrEqualTo(bar.left - .5));
        }
        await m.capture('projects_${width.toInt()}');
        m.expectNoFailures();
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
