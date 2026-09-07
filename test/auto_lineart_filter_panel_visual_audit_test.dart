import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> makePreview() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 220, 220),
      Paint()..color = const Color(0xFFF7F7F7),
    );
    final rough = Paint()
      ..color = const Color(0xFF242424)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(18, 118);
    for (var x = 18; x <= 195; x += 3) {
      final y =
          112 + 34 * math.sin((x - 18) / 19) + 9 * math.sin((x - 18) / 5.5);
      path.lineTo(x.toDouble(), y);
    }
    canvas.drawPath(path, rough);
    canvas.drawLine(const Offset(105, 116), const Offset(184, 42), rough);
    canvas.drawLine(const Offset(105, 116), const Offset(185, 186), rough);
    return recorder.endRecording().toImage(220, 220);
  }

  AutoLineartGraph baseGraph() {
    final main = <AutoLineartPoint>[];
    for (var x = 18; x <= 195; x += 3) {
      final y =
          112 + 34 * math.sin((x - 18) / 19) + 9 * math.sin((x - 18) / 5.5);
      main.add(AutoLineartPoint(x.toDouble(), y));
    }
    final up = <AutoLineartPoint>[];
    final down = <AutoLineartPoint>[];
    for (var i = 0; i <= 24; i++) {
      final t = i / 24.0;
      up.add(AutoLineartPoint(105 + 79 * t, 116 - 74 * t));
      down.add(AutoLineartPoint(105 + 80 * t, 116 + 70 * t));
    }
    return AutoLineartGraph(
      width: 220,
      height: 220,
      paths: [
        AutoLineartPath(
          points: main,
          startIsJunction: false,
          endIsJunction: false,
          persistence: 1,
        ),
        AutoLineartPath(
          points: up,
          startIsJunction: true,
          endIsJunction: false,
          persistence: 1,
        ),
        AutoLineartPath(
          points: down,
          startIsJunction: true,
          endIsJunction: false,
          persistence: 1,
        ),
      ],
    );
  }

  Future<void> pumpAudit(
    WidgetTester tester, {
    required Size physicalSize,
    required double dpr,
    required int smoothing,
    required String golden,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final image = await makePreview();
    addTearDown(image.dispose);
    final graph = AutoLineartEngine.prepareEditableGraph(
      baseGraph(),
      smoothingLevel: smoothing,
    );
    final rootKey = GlobalKey();
    var filterConfigured = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            if (!filterConfigured) {
              filterConfigured = true;
              final fs = context.read<FilterService>();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                fs.selectFilter('Filter0023');
                fs.updateFilterParams(
                  'Filter0023',
                  autoLineartSmoothing: smoothing.toDouble(),
                );
              });
            }
            return MaterialApp(
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RepaintBoundary(
                key: rootKey,
                child: Scaffold(
                  backgroundColor: const Color(0xFFE8E8E8),
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: AutoLineartControlOverlay(
                          image: image,
                          graph: graph,
                          onPointMoved: (_, __, ___) {},
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilterPanel(
                          projectId: 'visual-audit',
                          sceneId: 'scene',
                          layerId: null,
                          frameIndex: 0,
                          onClose: () {},
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface
                                .withValues(alpha: .92),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text('なめらか補正 $smoothing / 100'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(find.byType(AutoLineartControlOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(rootKey), matchesGoldenFile(golden));
  }

  testWidgets('SP actual FilterPanel + production overlay smoothing 45', (
    tester,
  ) async {
    await pumpAudit(
      tester,
      physicalSize: const Size(1170, 2532),
      dpr: 3,
      smoothing: 45,
      golden: 'goldens/auto_lineart_sp_45.png',
    );
  });

  testWidgets('SP actual FilterPanel + production overlay smoothing 85', (
    tester,
  ) async {
    await pumpAudit(
      tester,
      physicalSize: const Size(1170, 2532),
      dpr: 3,
      smoothing: 85,
      golden: 'goldens/auto_lineart_sp_85.png',
    );
  });

  testWidgets('desktop actual FilterPanel + production overlay smoothing 45', (
    tester,
  ) async {
    await pumpAudit(
      tester,
      physicalSize: const Size(1200, 800),
      dpr: 1,
      smoothing: 45,
      golden: 'goldens/auto_lineart_desktop_45.png',
    );
  });
}
