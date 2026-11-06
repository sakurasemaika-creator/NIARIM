import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/models/pixel_color_mode.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pick_filter_card.dart';

const _blackAndWhite = [0xFF000000, 0xFFFFFFFF];

/// A 32 x 32 opaque mid grey: no single colour of black and white comes
/// close, so with dithering it is a mix of both, without it one of them.
Uint8List _grey() {
  final data = Uint8List(32 * 32 * 4);
  for (var i = 0; i < data.length; i += 4) {
    data
      ..[i] = 128
      ..[i + 1] = 128
      ..[i + 2] = 128
      ..[i + 3] = 255;
  }
  return data;
}

Set<int> _colours(Uint8List out) => {
  for (var i = 0; i < out.length; i += 4)
    (out[i] << 16) | (out[i + 1] << 8) | out[i + 2],
};

/// ドット絵's dithering can be switched on and off, in the draw filter and
/// the effect filter alike: on (the default, also for settings saved before
/// the switch existed), a colour no single allowed colour comes close to is
/// a pattern of a few; off, it is filled with the nearest one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the setting', () {
    test('is on by default, and on for settings saved without it', () {
      const filter = FilterDef(
        id: 'Filter0018',
        name: 'ドット絵',
        kind: FilterKind.pixelate,
      );
      expect(filter.pixelDither, isTrue);
      final json = filter.toJson()..remove('pixelDither');
      expect(FilterDef.fromJson(json).pixelDither, isTrue);
      expect(
        const EffectFilterInstance(
          id: 'e',
          type: EffectFilterType.pixelate,
          startFrame: 0,
          endFrame: 0,
        ).pixelDither,
        isTrue,
      );
    });

    test('off is saved and restored with the filter', () {
      const filter = FilterDef(
        id: 'Filter0018',
        name: 'ドット絵',
        kind: FilterKind.pixelate,
        pixelDither: false,
      );
      expect(FilterDef.fromJson(filter.toJson()).pixelDither, isFalse);
      expect(filter.copyWith(strength: 4).pixelDither, isFalse);
      expect(filter.copyWith(pixelDither: true).pixelDither, isTrue);
    });

    test('off is saved and restored with the scene\'s effect filter', () async {
      final dir = await Directory.systemTemp.createTemp('niarim-dither-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 1, 1);
      final project = Project(
        id: 'dither',
        name: 'Dither',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        createdAt: now,
        updatedAt: now,
        totalWorkSeconds: 0,
      );
      final scene = Scene(
        id: 'Scene0001',
        index: 0,
        frames: const [Frame(index: 0, layers: [])],
        effectFilters: const [
          EffectFilterInstance(
            id: 'off',
            type: EffectFilterType.pixelate,
            startFrame: 0,
            endFrame: 0,
            pixelDither: false,
          ),
          EffectFilterInstance(
            id: 'on',
            type: EffectFilterType.pixelate,
            startFrame: 0,
            endFrame: 0,
          ),
        ],
      );
      final path = '${dir.path}/dither.niapro';
      await NiaproSerializer.saveToPath(
        filePath: path,
        project: project,
        scenes: [scene],
        tileManager: TileManager(canvasWidth: 16, canvasHeight: 16),
      );
      final loaded = await NiaproSerializer.load(path);
      final effects = loaded.scenes.single.effectFilters;
      expect(effects.firstWhere((e) => e.id == 'off').pixelDither, isFalse);
      expect(effects.firstWhere((e) => e.id == 'on').pixelDither, isTrue);
    });
  });

  group('the result', () {
    for (final dither in [true, false]) {
      test('draw filter, dithering ${dither ? 'on' : 'off'}', () {
        final out = applyDrawFilterInIsolate((
          _grey(),
          32,
          32,
          FilterDef(
            id: 'Filter0018',
            name: 'ドット絵',
            kind: FilterKind.pixelate,
            strength: 4,
            pixelColorMode: PixelColorMode.explicit,
            pixelExplicitColors: _blackAndWhite,
            pixelDither: dither,
          ),
          null,
        ));
        expect(_colours(out).length, dither ? 2 : 1);
      });

      test('effect filter, dithering ${dither ? 'on' : 'off'}', () {
        final out = FilterEngine().applyEffectFilters(_grey(), 32, 32, [
          EffectFilterInstance(
            id: 'e',
            type: EffectFilterType.pixelate,
            startFrame: 0,
            endFrame: 0,
            param1: 4,
            pixelColorMode: PixelColorMode.explicit,
            pixelExplicitColors: _blackAndWhite,
            pixelDither: dither,
          ),
        ], 0);
        expect(_colours(out).length, dither ? 2 : 1);
      });
    }
  });

  testWidgets('the filter panel shows the switch while colours are limited, '
      'and it turns dithering off and on', (tester) async {
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => '${Directory.systemTemp.path}/niarim_dither_toggle',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null),
    );
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
        name: 'dither-toggle',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 96,
        exportHeight: 60,
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
    await pickFilterCard(tester, 'Filter0018');
    await tester.pump();
    final context = tester.element(find.byType(FilterPanel));
    final service = context.read<FilterService>();
    final l10n = AppLocalizations.of(context)!;

    // The built-in ドット絵 limits colours by count: the switch is there,
    // on, with its label.
    final toggle = find.byKey(const ValueKey('pixel-art-dither-toggle'));
    expect(service.currentFilter!.pixelColorMode, PixelColorMode.count);
    await tester.ensureVisible(toggle);
    await tester.pump();
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(
        of: toggle,
        matching: find.text(l10n.filterPixelateDither),
      ),
      findsOneWidget,
    );
    expect(service.currentFilter!.pixelDither, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(service.currentFilter!.pixelDither, isFalse);
    await tester.tap(toggle);
    await tester.pump();
    expect(service.currentFilter!.pixelDither, isTrue);

    // Without a limit on the colours there is nothing to dither.
    service.updateFilterParams(
      service.currentFilter!.id,
      pixelColorMode: PixelColorMode.none,
    );
    await tester.pump();
    expect(toggle, findsNothing);
  });

  testWidgets('the timeline\'s effect filter has the switch too', (
    tester,
  ) async {
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final temp = Directory.systemTemp.createTempSync('niarim_dither_timeline');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async => temp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle({int rounds = 6}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
      }
    }

    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await settle();
    final projects = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'dither-timeline',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    final sceneId = projects.scenesOf(project.id).first.id;
    projects.addEffectFilter(
      project.id,
      sceneId,
      const EffectFilterInstance(
        id: 'pixel',
        type: EffectFilterType.pixelate,
        startFrame: 0,
        endFrame: 11,
      ),
    );
    appRouter.go('/timeline/${project.id}');
    await settle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;

    await tester.tap(find.byTooltip(l10n.timelineEffectFilterLabel).first);
    await settle(rounds: 3);
    await tester.tap(find.text(l10n.filterNamePixelate).last);
    await settle(rounds: 3);
    final toggle = find.byKey(const ValueKey('effect-pixel-art-dither-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pump();
    expect(toggle, findsOneWidget);
    bool dither() => projects
        .effectFiltersOf(project.id, sceneId)
        .firstWhere((e) => e.id == 'pixel')
        .pixelDither;
    expect(dither(), isTrue);
    await tester.tap(toggle);
    await settle(rounds: 2);
    expect(dither(), isFalse);
    await tester.tap(toggle);
    await settle(rounds: 2);
    expect(dither(), isTrue);
  });
}
