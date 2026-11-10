import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture current Create Works home and drawer across SP and PC widths', (tester) async {
    final temp = Directory.systemTemp.createTempSync('niarim-home-drawer-matrix-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    var workingDirectory = temp.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => workingDirectory);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('build/home-drawer-multiwidth')..createSync(recursive: true);
    final rows = <String>[];

    for (final width in <int>[320, 360, 390, 430, 600, 760, 1024, 1440]) {
      final pc = width >= 760;
      final height = pc ? 900 : 844;
      await tester.pumpWidget(const SizedBox.shrink());
      workingDirectory =
          (Directory('${temp.path}/width_$width')..createSync(recursive: true)).path;
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': pc ? 1 : 0,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
      appRouter.go('/home');
      final key = GlobalKey();
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MultiProvider(
            providers: providers!,
            child: const NiarimApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'width $width');
      // Keep a realistic project tile visible instead of presenting only an
      // empty-state mockup. These sample projects never leave the CI runner.
      final service = tester.element(find.byType(HomeScreen)).read<ProjectService>();
      await tester.runAsync(
        () => service.createProject(
          name: 'サンプルアニメーション',
          fps: 12,
          durationSeconds: 3,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 1920,
          exportHeight: 1080,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 200));

      Future<void> shot(String name) async {
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'width $width, $name');
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        await tester.runAsync(
          () => File('${output.path}/${width}dp-$name.png').writeAsBytes(bytes!),
        );
      }

      expect(find.byKey(const ValueKey('home_tab_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_tab_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_tab_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_tab_3')), findsOneWidget);
      await shot('01-projects');

      // Shared library now has two explicit, mutually exclusive collections.
      await tester.ensureVisible(find.byKey(const ValueKey('home_tab_2')));
      await tester.tap(find.byKey(const ValueKey('home_tab_2')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const Key('sharedReceivedFilter')), findsOneWidget);
      expect(find.byKey(const Key('sharedOutgoingFilter')), findsOneWidget);
      await shot('04-shared-received');
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await tester.pump(const Duration(milliseconds: 350));
      await shot('05-shared-created');
      await tester.tap(find.byKey(const Key('sharedReceivedFilter')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.byKey(const ValueKey('home_tab_0')));
      await tester.tap(find.byKey(const ValueKey('home_tab_0')));
      await tester.pump(const Duration(milliseconds: 350));

      final menuButton = find.byKey(const Key('homeMenuButton'));
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);
      await shot('02-drawer-top');

      // Capture the bottom even when all five entries fit on screen.
      await tester.drag(drawer, const Offset(0, -540));
      await tester.pump(const Duration(milliseconds: 300));
      await shot('03-drawer-bottom');

      rows.add('$width x $height dp; mode=${pc ? 'PC' : 'SP'}; home-tabs=4; drawer=5; shared=received+created');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    File('${output.path}/matrix.txt')
        .writeAsStringSync(rows.join('\n') + '\n');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
