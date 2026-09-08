import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _rough(Uint8List data, int w, int h) {
  void dot(int cx, int cy, int r) {
    for (var y = cy - r; y <= cy + r; y++) {
      for (var x = cx - r; x <= cx + r; x++) {
        if (x < 0 || x >= w || y < 0 || y >= h) continue;
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > r * r) continue;
        final i = (y * w + x) * 4;
        data[i] = 25;
        data[i + 1] = 25;
        data[i + 2] = 25;
        data[i + 3] = 255;
      }
    }
  }

  for (var x = 16; x < w - 16; x++) {
    final y = (h / 2 + 20 * math.sin(x / 15)).round();
    dot(x, y, 5);
  }
  for (var i = 0; i <= 80; i++) {
    final t = i / 80.0;
    dot((w * .5 + w * .32 * t).round(), (h * .5 - h * .3 * t).round(), 4);
  }
}

List<(double, double)> _points(AutoLineartGraph graph) => [
      for (final path in graph.paths)
        for (final p in path.points) (p.x, p.y),
    ];

double _graphDistance(AutoLineartGraph a, AutoLineartGraph b) {
  final ap = _points(a);
  final bp = _points(b);
  if (ap.isEmpty || bp.isEmpty) return 0;
  var total = 0.0;
  for (final p in ap) {
    var best = double.infinity;
    for (final q in bp) {
      final dx = p.$1 - q.$1;
      final dy = p.$2 - q.$2;
      best = math.min(best, math.sqrt(dx * dx + dy * dy));
    }
    total += best;
  }
  return total / ap.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'manual controls persist across sliders but reset on close/reopen; bulk hides controls',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('niarim_lineart_state_');
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
      SharedPreferences.setMockInitialValues({});
      final providers = (await tester.runAsync(buildAppProviders))!;
      BuildContext? providerContext;
      final show = ValueNotifier(true);
      final bulk = ValueNotifier<Set<int>?>(null);
      addTearDown(show.dispose);
      addTearDown(bulk.dispose);
      String? projectId;
      String? sceneId;
      String? layerId;

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) {
              providerContext = context;
              return MaterialApp(
                theme: context.watch<ThemeService>().themeData,
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: show,
                      builder: (_, visible, __) => ValueListenableBuilder<Set<int>?>(
                        valueListenable: bulk,
                        builder: (_, bulkFrames, __) {
                          if (!visible || projectId == null) return const SizedBox();
                          return FilterPanel(
                            projectId: projectId!,
                            sceneId: sceneId!,
                            layerId: layerId,
                            frameIndex: 0,
                            bulkFrameIndices: bulkFrames,
                            onClose: () => show.value = false,
                          );
                        },
                      ),
                    ),
                  ),
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
      final project = await tester.runAsync(
        () => ps.createProject(
          name: 'lineart-state',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 220,
          exportHeight: 220,
        ),
      );
      projectId = project.id;
      final scene = ps.scenesOf(project.id).first;
      sceneId = scene.id;
      layerId = scene.frames.first.layers.first.id;
      final tm = ps.tileManagerOf(project.id);
      final data = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
      _rough(data, tm.canvasWidth, tm.canvasHeight);
      tm.replaceLayerPixels(ps.tileKeyFor(project.id, scene.id, 0, layerId!), data);
      fs.selectFilter('Filter0023');
      fs.updateFilterParams(
        'Filter0023',
        autoLineartSmoothing: 5,
        autoLineartRoughWidth: 12,
      );
      show.notifyListeners();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);

      AutoLineartGraph graph() => tester
          .widget<AutoLineartControlOverlay>(find.byType(AutoLineartControlOverlay))
          .graph;

      var before = graph();
      final pathIndex = before.paths.indexWhere((p) => p.points.length >= 3);
      expect(pathIndex, greaterThanOrEqualTo(0));
      final path = before.paths[pathIndex];
      final pointIndex = path.points.length ~/ 2;
      final point = path.points[pointIndex];
      final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
      final start = Offset(
        rect.left + point.x / before.width * rect.width,
        rect.top + point.y / before.height * rect.height,
      );
      await tester.dragFrom(start, const Offset(0, -28));
      await tester.pump(const Duration(milliseconds: 300));
      final edited5 = graph();
      expect(_graphDistance(edited5, before), greaterThan(.3));

      // Output width, taper and color must never rebuild the editable graph.
      final stableBefore = _points(edited5);
      fs.updateFilterParams(
        'Filter0023',
        autoLineartOutputWidth: 6,
        autoLineartTaperLength: 20,
        autoLineartColor: 0xFFE04080,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(_points(graph()), stableBefore);

      // Smoothing 5 -> 7 may reduce controls, but the manually edited curve must
      // remain measurably different from a fresh level-7 panel.
      fs.updateFilterParams('Filter0023', autoLineartSmoothing: 7);
      await tester.pump(const Duration(milliseconds: 450));
      final edited7 = graph();

      // Rough-width refresh also retains edit influence while accepting fresh topology.
      fs.updateFilterParams('Filter0023', autoLineartRoughWidth: 18);
      await tester.pump(const Duration(milliseconds: 450));
      final editedWide = graph();

      // Close/cancel: no generated layer and no manual/cache state survives a new panel.
      show.value = false;
      await tester.pump(const Duration(milliseconds: 100));
      expect(ps.layersOf(project.id, scene.id, 0), hasLength(1));
      show.value = true;
      await tester.pump(const Duration(milliseconds: 900));
      final freshWide = graph();
      expect(_graphDistance(editedWide, freshWide), greaterThan(.15));

      // Return to level 7 and verify the earlier manual shape also differed from fresh.
      fs.updateFilterParams('Filter0023', autoLineartRoughWidth: 12);
      await tester.pump(const Duration(milliseconds: 400));
      final fresh7 = graph();
      expect(_graphDistance(edited7, fresh7), greaterThan(.15));

      // Multi-frame application deliberately hides manual controls so frame 0 edits
      // cannot be copied to frame 1. The regular preview image is still present.
      ps.addFrame(project.id, scene.id);
      bulk.value = {0, 1};
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FilterPanel), findsOneWidget);
      expect(find.byType(AutoLineartControlOverlay), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
