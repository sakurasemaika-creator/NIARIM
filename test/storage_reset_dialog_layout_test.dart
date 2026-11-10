import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('reset confirmation remains usable across 42 layout profiles', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('storage-dialog-layout-');
    final docs = Directory('${root.path}/docs')..createSync();
    final cache = Directory('${root.path}/cache')..createSync();
    final protected = File('${docs.path}/niarim/keep-on-cancel.bin')
      ..createSync(recursive: true)
      ..writeAsStringSync('synthetic project preserved by cancel');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      root.deleteSync(recursive: true);
    });
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var profiles = 0;
    for (final language in ['ja', 'en', 'fr', 'es', 'ko', 'zh', 'zh_Hant']) {
      for (final size in [
        const Size(320, 844),
        const Size(390, 220),
        const Size(1440, 900),
      ]) {
        for (final scale in [1.0, 2.0]) {
          final profile = '$language/$size/text$scale';
          debugPrint('RESET DIALOG PROFILE $profile');
          await tester.pumpWidget(const SizedBox.shrink());
          SharedPreferences.setMockInitialValues({
            'first_launch': false,
            'language': language,
            'force_pc_mode': size.width >= 1000 ? 1 : 0,
            firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          });
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          appRouter.go('/storage');
          final providers = await tester.runAsync(buildAppProviders);
          await tester.pumpWidget(
            MultiProvider(providers: providers!, child: const NiarimApp()),
          );
          await pumpRealAsync(tester, const Duration(milliseconds: 400));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(StorageScreen)),
          )!;
          final erase = find.text(l10n.storageEraseAllButton);
          await tester.scrollUntilVisible(erase, 180, maxScrolls: 30);
          await tester.ensureVisible(erase);
          await tester.pumpAndSettle();
          await tester.tap(erase);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: profile);
          final confirm = find.widgetWithText(
            FilledButton,
            l10n.storageEraseAllButton,
          );
          final cancel = find.widgetWithText(TextButton, l10n.commonCancel);
          await tester.ensureVisible(confirm);
          await tester.pumpAndSettle();
          expect(confirm.hitTestable(), findsOneWidget, reason: profile);
          await tester.ensureVisible(cancel);
          await tester.pumpAndSettle();
          expect(cancel.hitTestable(), findsOneWidget, reason: profile);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing, reason: profile);
          expect(
            protected.readAsStringSync(),
            'synthetic project preserved by cancel',
            reason: profile,
          );
          expect(tester.takeException(), isNull, reason: profile);
          profiles++;
        }
      }
    }
    expect(profiles, 42);
  });
}
