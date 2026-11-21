import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'capture existing PC/DeX canvas palette without modifying visuals',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'force_pc_mode': 1,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final temp = Directory.systemTemp.createTempSync('niarim-pc-palette-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => temp.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        temp.deleteSync(recursive: true);
      });
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);

      final providers = (await tester.runAsync(buildAppProviders))!;
      final boundaryKey = GlobalKey();
      ProjectService? projectService;
      StateSetter? rebuild;
      String? id;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MultiProvider(
            providers: providers,
            child: Builder(
              builder: (providerContext) => MaterialApp(
                theme: providerContext.watch<ThemeService>().themeData,
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: StatefulBuilder(
                  builder: (context, setState) {
                    projectService ??= context.read<ProjectService>();
                    rebuild = setState;
                    return id == null
                        ? const SizedBox.expand()
                        : CanvasScreen(projectId: id);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(projectService, isNotNull);
      final project = (await tester.runAsync(
        () => projectService!.createProject(
          name: 'PC-DeX actual palette evidence',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 320,
        ),
      ))!;
      id = project.id;
      rebuild!(() {});
      await tester.pump(const Duration(milliseconds: 1600));

      Future<void> settleForCapture() async {
        for (var i = 0; i < 9; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 45)),
          );
          await tester.pump(const Duration(milliseconds: 75));
        }
      }

      Future<void> capture(String name) async {
        await settleForCapture();
        expect(find.byType(CanvasScreen), findsOneWidget);
        final tools = find.byType(CanvasIconButton);
        final toolbar = find.byType(ToolbarWidget);
        expect(toolbar, findsWidgets);
        expect(tools, findsWidgets);
        final image = await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return bytes!.buffer.asUint8List();
        });
        final directory = Directory('build/pc-canvas-palette-evidence')
          ..createSync(recursive: true);
        await tester.runAsync(
          () => File(
            '${directory.path}/$name.png',
          ).writeAsBytes(image!, flush: true),
        );
        expect(tester.takeException(), isNull, reason: name);
      }

      await capture('01_pc_dex_canvas_default');
      final brush = find
          .descendant(
            of: find.byType(ToolbarWidget),
            matching: find.byIcon(Icons.tune),
          )
          .first;
      await tester.ensureVisible(brush);
      await tester.tap(brush);
      await tester.pump(const Duration(milliseconds: 500));
      // The brush dock is already open in the first capture. Tapping its
      // toolbar icon closes it; the second screenshot verifies both states.
      expect(find.byType(BrushPanel), findsNothing);
      await capture('02_pc_dex_brush_palette_closed');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
