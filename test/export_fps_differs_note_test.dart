import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// The export's frame rate is not applied silently (spec 26 §7.1): when it
/// differs from the work's, the export screen says so (the preview plays at
/// the work's rate) and offers the work's rate.
void main() {
  Future<({ProjectService ps, String id})> open(
    WidgetTester tester,
    int fps, {
    int seconds = 1,
    bool fromTimeline = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('export-fps-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'fps',
        fps: fps,
        durationSeconds: seconds,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    );
    if (fromTimeline) {
      appRouter.go('/timeline/${project!.id}');
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('timelineExportButton')));
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
    } else {
      appRouter.go('/export/${project!.id}');
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
    }
    return (ps: ps, id: project.id);
  }

  testWidgets('a 12 fps work exported at 30 fps is told, and can use its '
      'own 12 fps', (tester) async {
    await open(tester, 12);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExportScreen)),
    )!;
    final note = find.byKey(const ValueKey('exportFpsDiffersNote'));
    expect(note, findsOneWidget);
    expect(tester.widget<Text>(note).data, l10n.exportFpsDiffersNote(12, 30));
    await tester.ensureVisible(find.byKey(const ValueKey('exportUseWorkFps')));
    await tester.tap(find.byKey(const ValueKey('exportUseWorkFps')));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    // The custom setting at 12 fps: nothing left to tell.
    expect(note, findsNothing);
    expect(find.text('160 × 90 px · ${l10n.pcStatusFps(12)}'), findsOneWidget);
  });

  testWidgets('a 30 fps work at the standard 30 fps says nothing', (
    tester,
  ) async {
    await open(tester, 30);
    expect(find.byKey(const ValueKey('exportFpsDiffersNote')), findsNothing);
  });

  test('an output frame shows the frame the export samples for it', () {
    for (final (source, output) in [(12, 30), (24, 30), (30, 24), (60, 12)]) {
      final timing = ExportTiming(sourceFps: source, outputFps: output);
      final scenes = [
        Scene(
          id: 'a',
          index: 0,
          frames: [for (var i = 0; i < 17; i++) Frame(index: i)],
        ),
        Scene(
          id: 'b',
          index: 1,
          frames: [for (var i = 0; i < 9; i++) Frame(index: i)],
        ),
      ];
      final sampled = [
        for (final s in timing.samples(scenes))
          (s.scene.id == 'a' ? 0 : 17) + s.frame.index,
      ];
      expect(
        [for (var k = 0; k < sampled.length; k++) timing.sourceFrameOf(k)],
        sampled,
        reason: '$source → $output',
      );
      for (var f = 0; f < 26; f++) {
        final k = timing.firstOutputFrom(f);
        expect(timing.sourceFrameOf(k), greaterThanOrEqualTo(f));
        if (k > 0) expect(timing.sourceFrameOf(k - 1), lessThan(f));
      }
    }
  });

  testWidgets('from the export screen, the timeline previews at the export '
      'rate, and goes back to the work\'s', (tester) async {
    await open(tester, 12, seconds: 3, fromTimeline: true);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExportScreen)),
    )!;
    // Standard: 30 fps.
    await tester.ensureVisible(
      find.byKey(const ValueKey('exportPreviewAtFps')),
    );
    expect(find.text(l10n.exportPreviewAtFps(30)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exportPreviewAtFps')));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(TimelineScreen), findsOneWidget);
    expect(find.byType(ExportScreen), findsNothing);
    final chip = find.byKey(const Key('timelinePreviewOutputFps'));
    expect(chip, findsOneWidget);
    expect(find.text(l10n.timelinePreviewOutputFps(30, 12)), findsOneWidget);

    String frame() => tester
        .widget<Text>(find.byKey(const Key('timelinePreviewFrameCount')))
        .data!;
    // One second at 30 fps: 30 output frames, the export's frame 12 shown.
    await tester.tap(find.byTooltip(l10n.commonPlay).first);
    await tester.pump(const Duration(seconds: 1));
    expect(frame(), '13/36');
    await tester.tap(find.byTooltip(l10n.commonPause).first);
    await tester.pump();

    // Back to the work's 12 fps: one second is 12 frames again.
    await tester.tap(find.byKey(const Key('timelinePreviewOutputFpsBack')));
    await tester.pump();
    expect(chip, findsNothing);
    await tester.tap(find.byTooltip(l10n.commonPlay).first);
    await tester.pump(const Duration(seconds: 1));
    expect(frame(), '25/36');
    await tester.tap(find.byTooltip(l10n.commonPause).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
  });

  testWidgets('opened on its own, the export screen has no timeline to '
      'preview on', (tester) async {
    await open(tester, 12);
    expect(find.byKey(const ValueKey('exportPreviewAtFps')), findsNothing);
  });
}
