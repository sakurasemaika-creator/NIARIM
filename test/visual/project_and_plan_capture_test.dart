import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [390, 1280]) {
    testWidgets('project creation and plan comparison at width $width', (
      tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync(
        'niarim-project-visual-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => temp.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        temp.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': width >= 760 ? 1 : 0,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width.toDouble(), 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await loadAppFonts(tester);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(providers: providers!, child: const NiarimApp()),
        ),
      );
      await tester.pumpAndSettle();
      final words = AppLocalizations.of(
        tester.element(find.byType(HomeScreen)),
      )!;
      final output = Directory('build/project-and-plan/$width')
        ..createSync(recursive: true);
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull, reason: '$width / $name');
        final root =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await root.toImage();
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('${output.path}/$name.png');
            await file.writeAsBytes(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      final create = find.widgetWithText(
        FilledButton,
        words.homeAddSheetNewProject,
      );
      expect(create.hitTestable(), findsOneWidget);
      await capture('home');
      await tester.tap(create);
      await tester.pumpAndSettle();
      final transparent = find.byKey(const ValueKey<Color>(Colors.transparent));
      await tester.ensureVisible(transparent);
      await tester.tap(transparent);
      await tester.pumpAndSettle();
      final preview = find.byType(FramePreviewBackground);
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(tester.widget<FramePreviewBackground>(preview).backgroundColor, 0);
      await capture('paper-preview');

      appRouter.go('/premium');
      await tester.pumpAndSettle();
      await capture('premium');
      if (width == 390) {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
      }
      final feature = find.text(words.premiumFeatureWatermark);
      await tester.ensureVisible(feature);
      await tester.pumpAndSettle();
      expect(feature.hitTestable(), findsOneWidget);
      await capture('comparison');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, skip: !const bool.fromEnvironment('NIARIM_CAPTURE_PROJECT_AND_PLAN'));
  }
}
