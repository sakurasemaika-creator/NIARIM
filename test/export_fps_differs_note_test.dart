import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/export/export_screen.dart';
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
    int fps,
  ) async {
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
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    );
    appRouter.go('/export/${project!.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
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
}
