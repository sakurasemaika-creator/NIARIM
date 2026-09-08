import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void _drawRough(Uint8List bytes, int width, int height) {
  void dot(int cx, int cy, int radius) {
    for (var y = cy - radius; y <= cy + radius; y++) {
      for (var x = cx - radius; x <= cx + radius; x++) {
        if (x < 0 || x >= width || y < 0 || y >= height) continue;
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy > radius * radius) continue;
        final i = (y * width + x) * 4;
        bytes[i] = 35;
        bytes[i + 1] = 35;
        bytes[i + 2] = 35;
        bytes[i + 3] = 255;
      }
    }
  }

  for (var x = 24; x <= width - 24; x++) {
    final y = height ~/ 2 + ((x - width ~/ 2) * (x - width ~/ 2) / 900).round() - 10;
    dot(x, y.clamp(12, height - 12), 5);
  }
  for (var i = 0; i < 75; i++) {
    final t = i / 74;
    dot(
      (width * .50 + width * .30 * t).round(),
      (height * .52 - height * .28 * t).round(),
      4,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'actual Canvas applies auto line art above source and Undo/Redo preserves order and pixels',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('niarim_lineart_e2e_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null),
      );

      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final providers = (await tester.runAsync(buildAppProviders))!;
      BuildContext? providerContext;
      final activeProject = ValueNotifier<String?>(null);
      addTearDown(activeProject.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) {
              providerContext = context;
              return ValueListenableBuilder<String?>(
                valueListenable: activeProject,
                builder: (context, id, _) => MaterialApp(
                  theme: context.watch<ThemeService>().themeData,
                  locale: const Locale('ja'),
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: id == null
                      ? const Scaffold(body: SizedBox.expand())
                      : CanvasScreen(projectId: id),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      final context = providerContext!;
      final ps = context.read<ProjectService>();
      final fs = context.read<FilterService>();
      final undo = context.read<UndoManager>();

      final project = await tester.runAsync(
        () => ps.createProject(
          name: 'Auto line art E2E',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 256,
          exportHeight: 256,
        ),
      );
      final scene = ps.scenesOf(project.id).first;
      final source = scene.frames.first.layers.first;
      final tm = ps.tileManagerOf(project.id);
      final rough = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
      _drawRough(rough, tm.canvasWidth, tm.canvasHeight);
      tm.replaceLayerPixels(
        ps.tileKeyFor(project.id, scene.id, 0, source.id),
        rough,
      );

      fs.selectFilter('Filter0023');
      fs.updateFilterParams(
        'Filter0023',
        autoLineartSmoothing: 5,
        autoLineartColor: 0xFF2E62D5,
      );
      activeProject.value = project.id;
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);

      // Open the actual Canvas "settings/edit" menu, then its real FilterPanel.
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pump(const Duration(milliseconds: 250));
      final filterMenuEntry = find.byIcon(Icons.blur_on);
      expect(filterMenuEntry, findsOneWidget);
      await tester.tap(filterMenuEntry);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(FilterPanel), findsOneWidget);
      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);

      final apply = find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byType(FilledButton),
      );
      expect(apply, findsOneWidget);
      await tester.tap(apply);
      await tester.pump(const Duration(milliseconds: 100));
      // Full-resolution centerline analysis runs in compute(); let real async work finish.
      await tester.runAsync(() async {
        for (var i = 0; i < 80; i++) {
          if (ps.layersOf(project.id, scene.id, 0).length >= 2) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump(const Duration(milliseconds: 400));

      var layers = ps.layersOf(project.id, scene.id, 0);
      expect(layers, hasLength(2));
      final generated = layers.singleWhere((l) => l.id != source.id);
      expect(generated.type, LayerType.normal);
      expect(layers.indexOf(generated), layers.indexOf(source) + 1);
      expect(undo.canUndo, isTrue);

      final generatedKey = ps.tileKeyFor(
        project.id,
        scene.id,
        0,
        generated.id,
      );
      final generatedImage = await tm.compositeLayerToImage(generatedKey);
      final generatedBytes = await generatedImage.toByteData();
      generatedImage.dispose();
      expect(generatedBytes, isNotNull);
      final data = generatedBytes!.buffer.asUint8List();
      expect(
        Iterable<int>.generate(data.length ~/ 4).any((n) => data[n * 4 + 3] > 0),
        isTrue,
      );

      // Use the real Canvas top-bar Undo / Redo controls.
      await tester.tap(find.byIcon(Icons.undo).first);
      await tester.pump(const Duration(milliseconds: 150));
      layers = ps.layersOf(project.id, scene.id, 0);
      expect(layers, hasLength(1));
      expect(layers.single.id, source.id);

      await tester.tap(find.byIcon(Icons.redo).first);
      await tester.pump(const Duration(milliseconds: 150));
      layers = ps.layersOf(project.id, scene.id, 0);
      expect(layers, hasLength(2));
      final redone = layers.singleWhere((l) => l.id != source.id);
      expect(redone.id, generated.id);
      expect(layers.indexOf(redone), layers.indexOf(source) + 1);

      final redoneImage = await tm.compositeLayerToImage(
        ps.tileKeyFor(project.id, scene.id, 0, redone.id),
      );
      final redoneBytes = await redoneImage.toByteData();
      redoneImage.dispose();
      expect(redoneBytes, isNotNull);
      expect(
        Iterable<int>.generate(redoneBytes!.lengthInBytes ~/ 4)
            .any((n) => redoneBytes.getUint8(n * 4 + 3) > 0),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
