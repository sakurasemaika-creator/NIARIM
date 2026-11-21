import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/pixel_color_mode.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  testWidgets(
    'a pixel brush immediately displays the final palette across tile edges',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final providers = (await tester.runAsync(buildAppProviders))!;
      final projectId = ValueNotifier<String?>(null);
      addTearDown(projectId.dispose);
      late ProjectService projects;
      late BrushService brushes;

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                projects = context.read<ProjectService>();
                brushes = context.read<BrushService>();
                return ValueListenableBuilder(
                  valueListenable: projectId,
                  builder: (_, id, _) => id == null
                      ? const SizedBox()
                      : CanvasScreen(projectId: id),
                );
              },
            ),
          ),
        ),
      );
      final project = (await tester.runAsync(() async {
        final project = await projects.createProject(
          name: 'DISC513 pixel brush',
          exportWidth: 1920,
          exportHeight: 1080,
          fps: 1,
          durationSeconds: 2,
          backgroundColor: 0xffffffff,
        );
        final brush = brushes.currentBrush!.copyWith(
          id: 'disc513-brush',
          name: 'Black-only pixel brush',
          size: 24,
          opacity: 100,
          stabilization: false,
          pixelMode: true,
          pixelColorMode: PixelColorMode.explicit,
          pixelExplicitColors: [0xff000000],
        );
        brushes.addBrush(brush);
        brushes.selectBrush(brush.id);
        brushes.setCurrentColor(const Color(0xffff0000));
        return project;
      }))!;
      projectId.value = project.id;
      await pumpRealAsync(tester, const Duration(milliseconds: 350));

      final canvas = find.byType(CanvasArea);
      final bounds = tester.getRect(canvas);
      final paper = canvasDrawingRectFor(bounds.size, project);
      Offset position(double x, double y) =>
          bounds.topLeft +
          paper.topLeft +
          Offset(x * paper.width / 1920, y * paper.height / 1080);
      const samples = [606, 700, 757, 765, 767, 768, 769, 772, 781, 840, 902];

      Future<List<int>> displayedColors() async {
        final painters = tester.widgetList<CustomPaint>(
          find.descendant(of: canvas, matching: find.byType(CustomPaint)),
        );
        final dynamic painter = painters
            .map((widget) => widget.painter)
            .firstWhere(
              (painter) => painter.runtimeType.toString() == '_CanvasPainter',
            );
        final image = (painter.compositeImage as ui.Image).clone();
        return (await tester.runAsync(() async {
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return [
              for (final y in samples)
                pixels.getUint32((y * image.width + 960) * 4),
            ];
          } finally {
            image.dispose();
          }
        }))!;
      }

      for (final (index, x, interval) in [
        (0, 960.0, Duration.zero),
        (1, 960.0, const Duration(milliseconds: 16)),
      ]) {
        final stroke = await tester.startGesture(
          position(x, 600),
          kind: PointerDeviceKind.mouse,
        );
        // Start a rasterization while the stroke is still red. Fast moves
        // cross the seam before the first rasterization has to finish.
        for (final y in [641.0, 726.0, 767.0, 768.0, 821.0, 916.0]) {
          await stroke.moveTo(position(x, y));
          if (interval > Duration.zero) await tester.pump(interval);
        }
        await stroke.up();
        await pumpRealAsync(tester, const Duration(milliseconds: 520));
        expect(
          await displayedColors(),
          everyElement(0x000000ff),
          reason: 'after lifting the pen, frame ${index + 1}',
        );
        final next = 1 - index;
        await tester.tap(find.byKey(ValueKey('frameStripCell$next')));
        await pumpRealAsync(tester, const Duration(milliseconds: 320));
        if (index == 1) {
          expect(await displayedColors(), everyElement(0x000000ff));
        }
      }

      await tester.tap(find.byKey(const ValueKey('frameStripCell1')));
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(await displayedColors(), everyElement(0x000000ff));
      expect(tester.takeException(), isNull);
    },
  );
}
