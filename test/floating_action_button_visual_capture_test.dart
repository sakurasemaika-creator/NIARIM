import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture seven real bottom floating action surfaces', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('niarim-fab-ui-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final captureKey = GlobalKey();
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    // App previews schedule ongoing frames; pumpAndSettle may never resolve.
    Future<void> advanceUi() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 35)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await advanceUi();

    Future<void> capture(String filename, {int minFabs = 1}) async {
      await advanceUi();
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsAtLeastNWidgets(minFabs), reason: filename);
      final theme = Theme.of(tester.element(fabFinder.first));
      expect(theme.floatingActionButtonTheme.elevation, 0, reason: filename);
      expect(
        theme.floatingActionButtonTheme.highlightElevation,
        0,
        reason: filename,
      );
      for (final button in tester.widgetList<FloatingActionButton>(fabFinder)) {
        expect(button.elevation, isNull, reason: filename);
        expect(button.highlightElevation, isNull, reason: filename);
        final materials = tester
            .widgetList<Material>(
              find.descendant(
                of: find.byWidget(button),
                matching: find.byType(Material),
              ),
            )
            .toList();
        expect(materials, isNotEmpty, reason: filename);
        expect(
          materials.every((m) => m.elevation == 0),
          isTrue,
          reason: filename,
        );
      }
      expect(tester.takeException(), isNull, reason: filename);
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      final dir = Directory('build/floating-button-captures')
        ..createSync(recursive: true);
      await tester.runAsync(
        () => File('${dir.path}/$filename.png').writeAsBytes(png!, flush: true),
      );
    }

    await capture('01_home_projects_two_fabs', minFabs: 2);
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await capture('02_home_exported_works_fab');
    for (final item in <(String, String, int)>[
      ('/shared', '03_shared_received_folder_fab', 1),
      ('/community', '04_community_two_fabs', 2),
      ('/autofill-presets', '05_autofill_presets_fab', 1),
      ('/settings/watermark', '06_watermark_fab', 1),
      ('/settings/shortcuts', '07_shortcuts_extended_fab', 1),
    ]) {
      appRouter.go(item.$1);
      await advanceUi();
      await capture(item.$2, minFabs: item.$3);
    }
  });
}
