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
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/frame_preview_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// The frame lists of the canvas and the timeline, and the timeline's
/// playback preview, show each project's own background colour (the one
/// chosen when the project was created or edited) behind its pictures, as
/// the canvas and the export do, and follow a change to it at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frame lists and previews show the project background', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('niarim_frame_bg_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    Future<void> settle([int rounds = 6]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
    }

    await settle();
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'frame-background',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFF000000,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;

    // Something drawn on the first two frames (a red disc, a blue bar) on
    // transparent layers, so the background shows around them.
    final scene = ps.scenesOf(project.id).first;
    final tm = ps.tileManagerOf(project.id);
    for (final frame in [0, 1]) {
      final layer = ps.layersOf(project.id, scene.id, frame).first;
      final rgba = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
      for (var y = 0; y < tm.canvasHeight; y++) {
        for (var x = 0; x < tm.canvasWidth; x++) {
          final dx = x - tm.canvasWidth / 2, dy = y - tm.canvasHeight / 2;
          final on = frame == 0
              ? dx * dx + dy * dy < 30 * 30
              : dx.abs() < 50 && dy.abs() < 10;
          if (!on) continue;
          rgba.setAll(
            (y * tm.canvasWidth + x) * 4,
            frame == 0 ? [220, 40, 50, 255] : [40, 80, 220, 255],
          );
        }
      }
      tm.replaceLayerPixels(
        ps.tileKeyFor(project.id, scene.id, frame, layer.id),
        rgba,
      );
    }
    final out = Directory('build/frame-preview-background')
      ..createSync(recursive: true);
    Future<void> capture(String name) async {
      await settle(4);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(
          '${out.path}/$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    /// The colour on screen at the middle of [finder]'s first match.
    Future<List<int>> colourAt(Finder finder) async {
      final rect = tester.getRect(finder.first);
      final pixels = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final width = image.width;
        image.dispose();
        final i = (rect.center.dy.round() * width + rect.center.dx.round()) * 4;
        return data!.buffer.asUint8List().sublist(i, i + 3);
      });
      return pixels!;
    }

    Finder backgroundsIn(Finder area) => find.descendant(
      of: area,
      matching: find.byType(FramePreviewBackground),
    );
    int colourOf(Finder area) => tester
        .widget<FramePreviewBackground>(backgroundsIn(area).first)
        .backgroundColor;
    Finder checkerIn(Finder area) => find.descendant(
      of: area,
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TransparencyCheckerPainter,
      ),
    );

    // ── Canvas mode ──
    appRouter.go('/canvas/${project.id}');
    await settle(10);
    final strip = find.byType(FrameStripWidget);
    expect(strip, findsOneWidget);
    expect(backgroundsIn(strip), findsWidgets);
    expect(colourOf(strip), 0xFF000000);
    await capture('canvas_black');
    expect(await colourAt(backgroundsIn(strip).at(2)), [0, 0, 0]);

    // Editing the project's background changes the frame list at once.
    ps.updateProjectBackgroundColor(project.id, 0xFFF5F5DC);
    await settle(2);
    expect(colourOf(strip), 0xFFF5F5DC);
    expect(await colourAt(backgroundsIn(strip).at(2)), [0xF5, 0xF5, 0xDC]);
    await capture('canvas_beige');

    // A transparent background shows the canvas's checkerboard.
    ps.updateProjectBackgroundColor(project.id, 0x00000000);
    await settle(2);
    expect(checkerIn(strip), findsWidgets);
    await capture('canvas_transparent');
    ps.updateProjectBackgroundColor(project.id, 0xFFF5F5DC);
    await settle(2);
    expect(checkerIn(strip), findsNothing);

    // Switching the canvas to show transparency switches the list too.
    final l10n = AppLocalizations.of(tester.element(strip))!;
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle(3);
    final toggle = find.text(l10n.canvasEditMenuBackgroundToggle);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await settle(3);
    expect(tester.widget<FrameStripWidget>(strip).showTransparency, isTrue);
    expect(checkerIn(strip), findsWidgets);

    // ── Timeline mode ──
    appRouter.go('/timeline/${project.id}');
    await settle(12);
    await capture('timeline_beige');
    final timeline = find.byType(Scaffold).last;
    final backgrounds = backgroundsIn(timeline);
    expect(backgrounds, findsWidgets);
    for (final element in backgrounds.evaluate()) {
      expect(
        (element.widget as FramePreviewBackground).backgroundColor,
        0xFFF5F5DC,
        reason: 'every frame cell and the playback preview',
      );
    }
    expect(
      find.byWidgetPredicate(
        (w) => w is FramePreviewBackground && w.checkerSize == 10,
      ),
      findsOneWidget,
      reason: 'the playback preview',
    );
    ps.updateProjectBackgroundColor(project.id, 0xFF000000);
    await settle(3);
    await capture('timeline_black');
    for (final element in backgroundsIn(timeline).evaluate()) {
      expect(
        (element.widget as FramePreviewBackground).backgroundColor,
        0xFF000000,
      );
    }

    appRouter.go('/');
    await settle();
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
