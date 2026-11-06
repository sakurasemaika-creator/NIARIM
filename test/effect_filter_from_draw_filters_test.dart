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
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

const _w = 40, _h = 30;

/// An opaque picture of every shade: a grey ramp across, a colour ramp
/// down, as a whole frame reaches the effect filters.
Uint8List _frame() {
  final rgba = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      rgba.setAll((y * _w + x) * 4, [
        (x * 255 / (_w - 1)).round(),
        (y * 255 / (_h - 1)).round(),
        ((x + y) * 255 / (_w + _h - 2)).round(),
        255,
      ]);
    }
  }
  return rgba;
}

EffectFilterInstance _effect(
  EffectFilterType type, {
  double param1 = 5,
  double param2 = 50,
  double param3 = 2,
  double param4 = 0,
  double param5 = 255,
  Color fadeColor = const Color(0xFF000000),
}) => EffectFilterInstance(
  id: type.name,
  type: type,
  startFrame: 0,
  endFrame: 3,
  param1: param1,
  param2: param2,
  param3: param3,
  param4: param4,
  param5: param5,
  fadeColor: fadeColor,
);

/// The drawing filters that look right applied to many frames at once are
/// effect filters too: トーンカーブ, レベル補正, シャープ, アンシャープマスク and
/// 周辺減光 give a frame exactly what the drawing filter gives a layer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = FilterEngine();
  Uint8List effect(EffectFilterInstance e, {int frame = 1}) =>
      engine.applyEffectFilters(_frame(), _w, _h, [e], frame);

  group('the same as the drawing filter', () {
    test('トーンカーブ: the preset, at full strength', () {
      for (final preset in ToneCurvePreset.values) {
        expect(
          effect(
            _effect(
              EffectFilterType.toneCurve,
              param1: preset.index.toDouble(),
              param2: 100,
            ),
          ),
          orderedEquals(
            engine.applyToneCurve(_frame(), _w, _h, toneCurvePoints(preset)),
          ),
          reason: preset.name,
        );
      }
    });

    test('トーンカーブ: half strength is halfway, none is no change', () {
      final full = engine.applyToneCurve(
        _frame(),
        _w,
        _h,
        toneCurvePoints(ToneCurvePreset.invert),
      );
      final half = effect(
        _effect(
          EffectFilterType.toneCurve,
          param1: ToneCurvePreset.invert.index.toDouble(),
          param2: 50,
        ),
      );
      final before = _frame();
      for (var i = 0; i < before.length; i++) {
        expect(half[i], closeTo((before[i] + full[i]) / 2, 1));
      }
      expect(
        effect(
          _effect(
            EffectFilterType.toneCurve,
            param1: ToneCurvePreset.invert.index.toDouble(),
            param2: 0,
          ),
        ),
        orderedEquals(before),
      );
    });

    test('レベル補正: all five values', () {
      expect(
        effect(
          _effect(
            EffectFilterType.levels,
            param1: 20,
            param2: 230,
            param3: 1.4,
            param4: 10,
            param5: 240,
          ),
        ),
        orderedEquals(
          engine.applyLevels(
            _frame(),
            _w,
            _h,
            inputBlack: 20,
            inputWhite: 230,
            inputGamma: 1.4,
            outputBlack: 10,
            outputWhite: 240,
          ),
        ),
      );
    });

    test('シャープ and アンシャープマスク', () {
      expect(
        effect(_effect(EffectFilterType.sharpen, param1: 70)),
        orderedEquals(engine.applySharpen(_frame(), _w, _h, 70)),
      );
      expect(
        effect(_effect(EffectFilterType.unsharpMask, param1: 3, param2: 1.5)),
        orderedEquals(engine.applyUnsharpMask(_frame(), _w, _h, 3, 1.5)),
      );
    });

    test('周辺減光: colour, range and density', () {
      final out = effect(
        _effect(
          EffectFilterType.vignette,
          param1: 60,
          param2: 80,
          fadeColor: const Color(0xFF203040),
        ),
      );
      expect(
        out,
        orderedEquals(
          engine.applyVignette(
            _frame(),
            _w,
            _h,
            80,
            color: 0xFF203040,
            range: 60,
          ),
        ),
      );
      expect(out, isNot(orderedEquals(_frame())));
    });

    test('only within the frames it is set for', () {
      final e = _effect(EffectFilterType.sharpen, param1: 70);
      expect(effect(e, frame: 4), orderedEquals(_frame()));
      expect(effect(e, frame: 3), isNot(orderedEquals(_frame())));
    });
  });

  test('saved and restored with the scene, the levels output white too, '
      'and 255 for older files', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-effects-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final now = DateTime.utc(2026, 1, 1);
    final project = Project(
      id: 'effects',
      name: 'Effects',
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
      effectFilters: [
        _effect(
          EffectFilterType.levels,
          param1: 12,
          param2: 220,
          param3: .8,
          param4: 6,
          param5: 200,
        ),
        _effect(
          EffectFilterType.vignette,
          param1: 70,
          param2: 30,
          fadeColor: const Color(0xFF102030),
        ),
        _effect(EffectFilterType.toneCurve, param1: 5, param2: 40),
      ],
    );
    final path = '${dir.path}/effects.niapro';
    await NiaproSerializer.saveToPath(
      filePath: path,
      project: project,
      scenes: [scene],
      tileManager: TileManager(canvasWidth: 16, canvasHeight: 16),
    );
    final loaded = await NiaproSerializer.load(path);
    final effects = {
      for (final e in loaded.scenes.single.effectFilters) e.type: e,
    };
    final levels = effects[EffectFilterType.levels]!;
    expect(
      [
        levels.param1,
        levels.param2,
        levels.param3,
        levels.param4,
        levels.param5,
      ],
      [12, 220, .8, 6, 200],
    );
    final vignette = effects[EffectFilterType.vignette]!;
    expect(vignette.fadeColor.toARGB32(), 0xFF102030);
    expect([vignette.param1, vignette.param2], [70, 30]);
    expect(effects[EffectFilterType.toneCurve]!.param1, 5);
    expect(
      const EffectFilterInstance(
        id: 'old',
        type: EffectFilterType.levels,
        startFrame: 0,
        endFrame: 0,
      ).param5,
      255,
    );
  });

  testWidgets('each can be added from the timeline and shows its settings', (
    tester,
  ) async {
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final temp = Directory.systemTemp.createTempSync('niarim_new_effects');
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
        name: 'new-effects',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    final sceneId = projects.scenesOf(project.id).first.id;
    appRouter.go('/timeline/${project.id}');
    await settle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;
    await tester.tap(find.byTooltip(l10n.timelineEffectFilterLabel).first);
    await settle(rounds: 3);

    final cases = {
      EffectFilterType.toneCurve: (
        l10n.filterNameToneCurve,
        l10n.filterToneCurveHighContrast,
      ),
      EffectFilterType.levels: (
        l10n.filterNameLevels,
        l10n.filterLevelsOutputWhite,
      ),
      EffectFilterType.sharpen: (
        l10n.filterNameSharpen,
        l10n.filterSharpenStrength,
      ),
      EffectFilterType.unsharpMask: (
        l10n.filterNameUnsharpMask,
        l10n.filterUnsharpAmount,
      ),
      EffectFilterType.vignette: (
        l10n.filterNameVignette,
        l10n.filterVignetteDensity,
      ),
    };
    for (final MapEntry(key: type, value: (name, setting)) in cases.entries) {
      await tester.tap(find.text(l10n.commonAdd).last);
      await settle(rounds: 3);
      final option = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(name),
      );
      await tester.scrollUntilVisible(
        option,
        120,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(option);
      await tester.pump();
      await tester.tap(
        find.ancestor(of: option, matching: find.byType(ListTile)),
      );
      await settle(rounds: 3);
      final added = projects
          .effectFiltersOf(project.id, sceneId)
          .where((e) => e.type == type);
      expect(added, hasLength(1), reason: type.name);
      // The new filter starts with a visible effect.
      final out = FilterEngine().applyEffectFilters(_frame(), _w, _h, [
        added.single,
      ], added.single.startFrame);
      expect(out, isNot(orderedEquals(_frame())), reason: type.name);
      // Its settings open with the tile.
      final title = find
          .descendant(of: find.byType(ExpansionTile), matching: find.text(name))
          .last;
      await tester.ensureVisible(title);
      await tester.pump();
      await tester.tap(title);
      await settle(rounds: 3);
      expect(
        find.text(setting, skipOffstage: false),
        findsWidgets,
        reason: type.name,
      );
      await tester.tap(title);
      await settle(rounds: 3);
    }
    // Five effect filters, one row each on the timeline: each row has its
    // own scroll (one shared controller threw once a second was added).
    expect(tester.takeException(), isNull);
    expect(projects.effectFiltersOf(project.id, sceneId), hasLength(5));
  });
}
