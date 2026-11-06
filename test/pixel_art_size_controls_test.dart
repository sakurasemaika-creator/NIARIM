import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pick_filter_card.dart';

const _w = 96, _h = 60;

/// Pixel art's size can be set either with the block-size slider (100 steps)
/// or as a dot count across or down the canvas (1 up to its resolution), and
/// the two always describe the same size. Mosaic's slider has 100 steps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => '${Directory.systemTemp.path}/niarim_pixel_art_size',
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<(FilterService, AppLocalizations)> openPanel(
    WidgetTester tester,
    String filterId,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    Widget app(Widget home) => MultiProvider(
      providers: providers!,
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );
    await tester.pumpWidget(app(const SizedBox()));
    final projects = tester
        .element(find.byType(SizedBox).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'pixel-art-size',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final sceneId = projects.scenesOf(project.id).first.id;
    final layerId = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((layer) => layer.type == model.LayerType.normal)
        .id;
    await tester.pumpWidget(
      app(
        FilterPanel(
          projectId: project.id,
          sceneId: sceneId,
          layerId: layerId,
          frameIndex: 0,
          onClose: () {},
        ),
      ),
    );
    await pickFilterCard(tester, filterId);
    await tester.pump();
    final context = tester.element(find.byType(FilterPanel));
    return (context.read<FilterService>(), AppLocalizations.of(context)!);
  }

  Finder inPanel(Finder finder) =>
      find.descendant(of: find.byType(FilterPanel), matching: finder);

  Finder dotSlider(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(Slider),
  );

  /// The dot count a slider shows.
  int dots(WidgetTester tester, String key) =>
      tester.widget<Slider>(dotSlider(key)).value.round();

  /// Drags a dot slider all the way to one end, as a user would.
  Future<void> dragToEnd(
    WidgetTester tester,
    String key, {
    required bool right,
  }) async {
    final slider = dotSlider(key);
    await tester.ensureVisible(slider);
    await tester.pump();
    final rect = tester.getRect(slider);
    await tester.dragFrom(
      Offset(rect.center.dx, rect.center.dy),
      Offset(right ? rect.width : -rect.width, 0),
    );
    await tester.pump();
  }

  /// Sets a dot slider to an exact count through its own callback (dragging
  /// to an exact value on a 1 - 96 track is not reliable).
  Future<void> setTo(WidgetTester tester, String key, int count) async {
    tester.widget<Slider>(dotSlider(key)).onChanged!(count.toDouble());
    await tester.pump();
  }

  testWidgets('the block-size slider and the dot sliders stay in step, and the '
      'dot sliders keep the picture\'s proportions', (tester) async {
    final (service, l10n) = await openPanel(tester, 'Filter0018');
    FilterDef current() => service.currentFilter!;
    double cell() => current().pixelArtCellSize(_w, _h);
    void expectSummary(int wide, int high) => expect(
      inPanel(find.text(l10n.filterPixelateDotsSummary(wide, high))),
      findsOneWidget,
      reason: '$wide × $high dots',
    );
    void expectDots(int wide, int high) {
      expect(dots(tester, 'pixel-art-dots-wide'), wide, reason: 'across');
      expect(dots(tester, 'pixel-art-dots-high'), high, reason: 'down');
    }

    // Block size 8 on a 96 × 60 canvas: 12 × 8 dots.
    expect(current().pixelArtByDots, isFalse);
    final slider = tester.widget<Slider>(inPanel(find.byType(Slider)).first);
    expect(slider.min, 1);
    expect(slider.max, 100, reason: '100 steps');
    expectSummary(12, 8);

    // One step up on the slider: block 9 is 11 × 7 dots.
    final plus = inPanel(find.byIcon(Icons.add_circle_outline)).first;
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pump();
    expect(cell(), 9);
    // 10 whole dots and a narrower last one across, 6 + 1 down.
    expectSummary(11, 7);

    // Switch to the dot sliders: they show the same size.
    await tester.tap(inPanel(find.text(l10n.filterPixelateModeDots)));
    await tester.pump();
    expect(current().pixelArtByDots, isTrue);
    expect(cell(), 9, reason: 'switching changes nothing');
    expectDots(11, 7);
    final across = tester.widget<Slider>(dotSlider('pixel-art-dots-wide'));
    final down = tester.widget<Slider>(dotSlider('pixel-art-dots-high'));
    expect((across.min, across.max), (1, _w), reason: '1 px to the canvas');
    expect((down.min, down.max), (1, _h));

    // All the way right: the canvas's own size, one dot per pixel.
    await dragToEnd(tester, 'pixel-art-dots-wide', right: true);
    expect(cell(), 1);
    expectDots(_w, _h);

    // All the way left on "down": 1px tall, so the picture is one dot.
    await dragToEnd(tester, 'pixel-art-dots-high', right: false);
    expect(cell(), _h);
    expectDots(2, 1);

    // 24 across: dots of 4, so 15 down — the proportions are kept.
    await setTo(tester, 'pixel-art-dots-wide', 24);
    expect(cell(), 4);
    expectDots(24, 15);

    // 6 down: dots of 10, so 10 across.
    await setTo(tester, 'pixel-art-dots-high', 6);
    expect(cell(), 10);
    expectDots(10, 6);

    // The − button: 5 down, dots of 12, 8 across.
    final minus = find.descendant(
      of: find.byKey(const ValueKey('pixel-art-dots-high')),
      matching: find.byIcon(Icons.remove_rounded),
    );
    await tester.ensureVisible(minus);
    await tester.tap(minus);
    await tester.pump();
    expect(cell(), 12);
    expectDots(8, 5);

    // A count that doesn't divide the canvas: 7 down 60 pixels.
    await setTo(tester, 'pixel-art-dots-high', 7);
    expect(cell(), closeTo(60 / 7, 1e-9));
    expectDots(12, 7);

    // Back to the block-size slider: same size, and it shows it.
    await tester.tap(inPanel(find.text(l10n.filterPixelateModeBlock)));
    await tester.pump();
    expect(cell(), closeTo(60 / 7, 1e-9));
    expect(
      inPanel(find.textContaining('${l10n.filterPixelateBlockSize}: 8.6')),
      findsOneWidget,
    );
    expectSummary(12, 7);

    // Each change was one Undo step: the last one takes back "7 down".
    service.undoFilterEdit();
    await tester.pump();
    expect(current().pixelArtByDots, isTrue);
    service.undoFilterEdit();
    await tester.pump();
    expect(cell(), 12, reason: 'back to 5 down');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the mosaic slider has 100 steps, 1 leaving the picture as it '
      'is', (tester) async {
    await openPanel(tester, 'Filter0026');
    final slider = tester.widget<Slider>(inPanel(find.byType(Slider)).first);
    expect(slider.min, 1);
    expect(slider.max, 100);
    await tester.pumpWidget(const SizedBox());

    final rgba = Uint8List(_w * _h * 4);
    for (var i = 0; i < rgba.length; i++) {
      rgba[i] = (i * 37) % 256;
    }
    final engine = FilterEngine();
    expect(engine.applyMosaic(rgba, _w, _h, 1), orderedEquals(rgba));
    final big = engine.applyMosaic(rgba, _w, _h, 100);
    final first = big.sublist(0, 4);
    for (var i = 0; i < big.length; i += 4) {
      expect(big.sublist(i, i + 4), first, reason: 'one block covers it all');
    }
  });
}
