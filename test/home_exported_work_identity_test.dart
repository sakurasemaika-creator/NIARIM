import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('exported works remain identifiable at 320px and text scale 2', (
    tester,
  ) async {
    final palette = AppThemePreset.defaultLight.copyWith(
      textColor: const Color(0xFF163A5F),
      menuTextColor: const Color(0xFF153E6F),
      panelBgColor: const Color(0xFFF5DFAF),
      menuBgColor: const Color(0xFFFFD6BC),
    );
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
      'force_pc_mode': 0,
      'theme_current_json': jsonEncode(palette.toJson()),
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final dir = Directory.systemTemp.createTempSync('works-identity-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
    final names = [for (var i = 0; i < 3; i++) 'AUDIT_${i}_animation.gif'];
    final exports = Directory('${dir.path}/exports')..createSync();
    for (final name in names) {
      File('${exports.path}/$name').writeAsBytesSync(
        base64Decode(
          'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        ),
      );
    }
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('home_tab_1'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    for (final name in names) {
      final label = find.text(name);
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'The distinguishing filename must be visible: $name',
      );
      expect(paragraph.text.style?.color, palette.menuTextColor);
      final card = tester.widget<Card>(
        find.ancestor(of: label, matching: find.byType(Card)).first,
      );
      expect(card.color, palette.menuBgColor);
    }
    final previewName = find.text(names.first);
    await tester.ensureVisible(previewName);
    await tester.pumpAndSettle();
    await tester.tap(previewName);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'GIF preview controls must fit',
    );
    final close = find.text('Fermer');
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    expect(tester.getCenter(close).dx, inInclusiveRange(0, 320));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
