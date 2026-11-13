import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_preview_layout.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  testWidgets('artwork pane follows its aspect and actions remain reachable', (
    tester,
  ) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const artwork = Key('artwork');
    var actions = 0;
    var conditions = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in [
        const Size(320, 844),
        const Size(320, 220),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        for (final ratio in [9 / 16, 1.0, 16 / 9, 4.0, .1]) {
          for (final scale in [1.0, 2.0]) {
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ExportedWorkPreviewLayout(
                          contentAspectRatio: ratio,
                          content: const SizedBox.expand(key: artwork),
                          shareLabel: l10n.homeShareOpenWith,
                          closeLabel: l10n.commonClose,
                          onShare: () => actions++,
                          onClose: () => actions++,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final pane = tester.getSize(find.byKey(artwork));
            final width = math.min(size.width - 32, 720) - 24;
            final height = math.min(width / ratio, (size.height - 32) * .6);
            expect(pane.width, closeTo(width, .001));
            expect(pane.height, closeTo(height, .001));
            final context = tester.element(
              find.byType(ExportedWorkPreviewLayout),
            );
            final l10n = AppLocalizations.of(context)!;
            for (final label in [l10n.homeShareOpenWith, l10n.commonClose]) {
              final button = find.ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate((w) => w is TextButton),
              );
              await tester.ensureVisible(button);
              await tester.pumpAndSettle();
              final rect = tester.getRect(button);
              expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
              expect(rect.top, greaterThanOrEqualTo(16 - 1e-9));
              expect(rect.bottom, lessThanOrEqualTo(size.height - 16 + 1e-9));
              await tester.tap(button);
              await tester.pumpAndSettle();
            }
            conditions++;
            expect(actions, conditions * 2);
            expect(tester.takeException(), isNull);
          }
        }
      }
    }
    expect(conditions, 210);
  });

  testWidgets('invalid artwork dimensions retain a bounded loading pane', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ExportedWorkPreviewLayout(
                contentAspectRatio: ratio,
                content: const SizedBox.expand(key: Key('pane')),
                shareLabel: 'Share',
                closeLabel: 'Close',
                onShare: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('pane'))),
        const Size(264, 148.5),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
