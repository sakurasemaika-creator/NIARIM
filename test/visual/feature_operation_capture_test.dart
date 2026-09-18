// Reproducible, production-route UI captures. Only app storage/plugin boundaries
// and the input artwork are fixtures; every effect is selected and run by taps.
// CAPTURE_GROUP=filters|automation|autofill|extras can split the capture run.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/autofill_gradient.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/models/pixel_color_mode.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/pixel_art_palette_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/custom_automation_draft_sheet.dart';
import 'package:niarim/widgets/pixel_art_palette_picker_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';
import 'texture_filter_reference_fixtures.dart';

const _captureMatch = String.fromEnvironment('CAPTURE_MATCH');
const _textureFixture = String.fromEnvironment('TEXTURE_FIXTURE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const group = String.fromEnvironment('CAPTURE_GROUP', defaultValue: 'all');
  if (group == 'all' || group == 'filters') {
    testWidgets('all filter cards and preset choices apply through Canvas UI', (
      tester,
    ) async {
      final h = await _Harness.create(tester, 'filters');
      final filters = h.context.read<FilterService>().filters;
      for (final filter in filters) {
        final variants = filter.id == 'Filter0004'
            ? ToneCurvePreset.values.map((e) => e.name).toList()
            : filter.kind == FilterKind.auroraHologram
            ? AuroraHologramPreset.values.map((e) => e.name).toList()
            : filter.kind == FilterKind.pixelate
            ? PixelColorMode.values.map((e) => e.name).toList()
            : <String>['default'];
        for (final variant in variants) {
          final id = '${filter.id}_$variant';
          if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) continue;
          debugPrint('CAPTURE_CASE:$id');
          final textureReference =
              filter.kind == FilterKind.auroraHologram && _textureFixture.isNotEmpty;
          await h.project(
            id,
            fixture: textureReference
                ? _textureFixture
                : filter.kind == FilterKind.autoLineart || filter.kind == FilterKind.inkPool
                ? 'lineart'
                : 'color',
            mask: filter.kind == FilterKind.lensDistortion,
            background: filter.kind == FilterKind.backgroundBlend,
            exportWidth: textureReference && _textureFixture == 'textureReference3' ? 785 : 256,
            exportHeight: textureReference && _textureFixture == 'textureReference3' ? 455 : 256,
          );
          final before = await h.art('$id-before');
          final inputIds = h.layers.map((l) => l.id).toSet();
          await h.capture('$id-before-ui');
          await h.openMenu(h.l10n.filterPanelTitle);
          final panel = find.byType(FilterPanel);
          await h.tap(
            find
                .descendant(of: panel, matching: find.byIcon(Icons.search))
                .first,
          );
          await tester.enterText(
            find.descendant(of: panel, matching: find.byType(TextField)).first,
            _filterName(filter),
          );
          await h.settle();
          await h.tap(
            find.descendant(
              of: panel,
              matching: find.byWidgetPredicate(
                (w) => w is Text && w.data == _filterName(filter),
              ),
            ),
          );
          expect(h.context.read<FilterService>().currentFilter!.id, filter.id);
          if (filter.id == 'Filter0004' ||
              filter.kind == FilterKind.auroraHologram) {
            final index = filter.id == 'Filter0004'
                ? ToneCurvePreset.values.indexWhere((e) => e.name == variant)
                : AuroraHologramPreset.values.indexWhere(
                    (e) => e.name == variant,
                  );
            final chip = find
                .descendant(of: panel, matching: find.byType(ChoiceChip))
                .at(index);
            await tester.ensureVisible(chip);
            await h.tap(chip);
          } else if (filter.kind == FilterKind.pixelate) {
            final mode = PixelColorMode.values.firstWhere(
              (e) => e.name == variant,
            );
            final label = switch (mode) {
              PixelColorMode.none => h.l10n.pixelColorModeNone,
              PixelColorMode.palette => h.l10n.pixelColorModePalette,
              PixelColorMode.explicit => h.l10n.pixelColorModeExplicit,
              PixelColorMode.count => h.l10n.pixelColorModeCount,
            };
            final dropdown = find.descendant(
              of: panel,
              matching: find.byType(DropdownButton<PixelColorMode>),
            );
            await tester.ensureVisible(dropdown);
            await h.tap(dropdown);
            await h.tap(find.text(label).last);
            if (mode == PixelColorMode.palette) {
              await h.tap(find.text('比較用4色'));
              await h.capture('$id-palette');
              await h.tap(
                find.descendant(
                  of: find.byType(PixelArtPalettePickerDialog),
                  matching: find.text(h.l10n.pixelArtPalettePickerApplyButton),
                ),
              );
              expect(find.byType(PixelArtPalettePickerDialog), findsNothing);
            }
          }
          await h.settle(6);
          final settings = h.context.read<FilterService>().currentFilter!;
          await h.capture('$id-settings');
          await h.tap(find.text(h.l10n.filterApplyButton));
          await h.until(
            () => panel.evaluate().isEmpty,
            'filter apply must finish and close the panel',
          );
          final after = await h.art('$id-after');
          await h.capture('$id-after-ui');
          await h.generatedLayerView(id, inputIds);
          final changed = _changedPixels(before, after);
          final neutral =
              filter.id == 'Filter0005' ||
              (filter.id == 'Filter0004' && variant == 'linear');
          expect(
            changed,
            neutral ? 0 : greaterThan(0),
            reason: '$id must ${neutral ? 'preserve' : 'change'} artwork',
          );
          h.record(
            id,
            '${filter.name} / $variant',
            changed,
            settings: settings.toJson(),
            note: neutral
                ? '初期値は恒等変換。画素が変わらないことを確認。'
                : variant == 'palette'
                ? '選んだパレットの4色を複製して使用する仕様。'
                : null,
          );
        }
      }
      await h.finish();
    }, timeout: const Timeout(Duration(minutes: 25)));
  }
  if (group == 'all' || group == 'automation') {
    testWidgets(
      'every official automation executes through the Canvas manager',
      (tester) async {
        final h = await _Harness.create(tester, 'automation');
        final items = h.context.read<CustomAutomationService>().items;
        expect(items.length, 4);
        for (final item in items) {
          final id = item.id;
          if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) continue;
          debugPrint('CAPTURE_CASE:$id');
          await h.project(
            id,
            fixture: id.contains('aurora')
                ? 'color'
                : id.contains('analog')
                ? 'analog'
                : 'lineart',
            background: id.contains('color_trace'),
          );
          final before = await h.art('$id-before');
          final inputIds = h.layers.map((l) => l.id).toSet();
          await h.capture('$id-before-ui');
          await h.openMenu(h.l10n.customAutomationTitle);
          final title = find.text(item.name);
          await tester.ensureVisible(title);
          await h.capture('$id-settings');
          await h.tap(title);
          await h.tap(find.text(h.l10n.customAutomationRunAction));
          await h.capture('$id-confirm');
          await tester.tap(find.text(h.l10n.customAutomationYes));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('custom-automation-progress')),
            findsOneWidget,
          );
          await h.until(
            () => find
                .byKey(const ValueKey('custom-automation-progress'))
                .evaluate()
                .isEmpty,
            'automation must finish without an error',
          );
          expect(
            find.text(h.l10n.customAutomationExecutionFailed),
            findsNothing,
          );
          final after = await h.art('$id-after');
          await h.capture('$id-after-ui');
          await h.generatedLayerView(id, inputIds);
          final changed = _changedPixels(before, after);
          expect(
            changed,
            greaterThan(0),
            reason: '${item.name} must affect pixels',
          );
          h.record(id, item.name, changed, settings: item.toJson());
        }
        await h.finish();
      },
      timeout: const Timeout(Duration(minutes: 12)),
    );
  }
  if (group == 'all' || group == 'autofill') {
    testWidgets(
      'all shipped auto-fill parts repaint via layer menu and assignment',
      (tester) async {
        final h = await _Harness.create(tester, 'autofill');
        final presets = h.context.read<AutofillPresetService>().presets;
        expect(presets.length, 3);
        expect(presets.fold<int>(0, (n, p) => n + p.parts.length), 55);
        for (final preset in presets) {
          for (final part in preset.parts) {
            final id = '${preset.id}_${part.id}';
            if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) {
              continue;
            }
            debugPrint('CAPTURE_CASE:$id');
            await h.project(id, fixture: 'empty');
            await h.tap(find.byIcon(Icons.layers).first);
            await h.tap(
              find.descendant(
                of: find.byType(LayerPanel),
                matching: find.byIcon(Icons.library_add),
              ),
            );
            await h.tap(find.text(h.l10n.layerPanelMenuLineartLayer));
            final layer = h.layers.firstWhere(
              (l) => l.type == model.LayerType.autoFillLineart,
            );
            await h.seed(layer.id, 'lineart');
            await h.closeLayers();
            final before = await h.art('$id-before');
            await h.capture('$id-before-ui');
            await h.assignPart(layer.id, preset, part);
            await h.layerMenu(layer.id);
            await h.tap(find.text(h.l10n.layerPanelMenuRunAutofill));
            await h.capture('$id-settings');
            await h.tap(find.text(h.l10n.layerPanelAutofillRepaintTitle));
            await h.tap(find.text(h.l10n.layerPanelExecuteButton));
            await h.until(
              () => h.layers.any((l) => l.type == model.LayerType.autoFill),
              'auto-fill must create its output layer',
            );
            await h.settle(4);
            await h.closeLayers();
            final after = await h.art('$id-after');
            await h.capture('$id-after-ui');
            final changed = _changedPixels(before, after);
            expect(
              changed,
              greaterThan(100),
              reason: '$id must fill closed areas',
            );
            final fillLayer = h.layers.firstWhere(
              (l) => l.type == model.LayerType.autoFill,
            );
            final fillPixels = await h.layerPixels(fillLayer.id);
            // A hand-selected interior point in the circular lineart is filled
            // with the actual assigned part color, including the white parts.
            final center = (95 * 256 + 115) * 4;
            expect(fillPixels.sublist(center, center + 4), [
              (part.color >> 16) & 255,
              (part.color >> 8) & 255,
              part.color & 255,
              255,
            ]);
            h.record(
              id,
              '${preset.name} / ${part.name}',
              changed,
              settings: part.toJson(),
            );
          }
        }
        await h.finish();
      },
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }
  if (group == 'all' || group == 'extras') {
    testWidgets('record, replay, auto-fill variants and updated Help/Tips', (
      tester,
    ) async {
      final h = await _Harness.create(tester, 'extras');
      const replayId = 'recorded_filter_replay';
      await h.project('recording', fixture: 'color');
      await h.openMenu(h.l10n.customAutomationTitle);
      await h.tap(find.text(h.l10n.customAutomationAdd));
      await tester.enterText(find.byType(TextField).last, '記録したぼかし');
      await h.tap(find.text(h.l10n.customAutomationStartRecording));
      await h.openMenu(h.l10n.filterPanelTitle);
      await h.tap(find.text(h.l10n.filterApplyButton));
      await h.until(
        () => find.byType(FilterPanel).evaluate().isEmpty,
        'recorded filter must complete',
      );
      final expectedReplay = await h.art('$replayId-original');
      await h.tap(find.text(h.l10n.customAutomationStopRecording));
      await h.capture('$replayId-review');
      await h.tap(
        find.descendant(
          of: find.byType(CustomAutomationDraftSheet),
          matching: find.text(h.l10n.commonSave),
        ),
      );
      final saved = h.context.read<CustomAutomationService>().items.last;
      expect(saved.steps.single.command, 'canvas.filterApply');
      await h.project(replayId, fixture: 'color');
      final replayBefore = await h.art('$replayId-before');
      await h.capture('$replayId-before-ui');
      await h.openMenu(h.l10n.customAutomationTitle);
      await h.tap(find.text(saved.name));
      await h.tap(find.text(h.l10n.customAutomationRunAction));
      await h.capture('$replayId-settings');
      await h.tap(find.text(h.l10n.customAutomationYes));
      await h.until(
        () => find
            .byKey(const ValueKey('custom-automation-progress'))
            .evaluate()
            .isEmpty,
        'recorded replay must complete',
      );
      expect(find.text(h.l10n.customAutomationExecutionFailed), findsNothing);
      final replayAfter = await h.art('$replayId-after');
      expect(replayAfter, expectedReplay);
      await h.capture('$replayId-after-ui');
      h.record(
        replayId,
        '操作記録 → 保存 → 再実行',
        _changedPixels(replayBefore, replayAfter),
        settings: saved.toJson(),
        note: '記録時と再実行後の全画素が一致。',
      );

      final parts = <AutofillPart>[
        const AutofillPart(id: 'flat', name: '単色で再塗り', color: 0xffcf5c83),
        const AutofillPart(
          id: 'color_update',
          name: '形を保って色更新',
          color: 0xff3a89b4,
        ),
        for (final type in AutofillGradientType.values)
          AutofillPart(
            id: type.name,
            name: 'グラデーション / ${type.name}',
            color: 0xffe9698c,
            gradient: AutofillGradient(
              type: type,
              colors: const [0xffe9698c, 0xff5e8bdf],
              stops: const [0, 1],
            ),
          ),
        const AutofillPart(
          id: 'outline',
          name: '縁取り＋塗り色と同じ線画色',
          color: 0xffbda5e0,
          outlineEnabled: true,
          outlineColor: 0xffe9698c,
          outlineWidth: 6,
          lineColorMode: AutofillLineColorMode.sameAsFill,
        ),
      ];
      final preset = AutofillPreset(
        id: 'capture_variants',
        name: '機能比較用',
        parts: parts,
      );
      await tester.runAsync(
        () => h.context.read<AutofillPresetService>().addPreset(preset),
      );
      await h.project('autofill_variants', fixture: 'empty');
      await h.tap(find.byIcon(Icons.layers).first);
      await h.tap(
        find.descendant(
          of: find.byType(LayerPanel),
          matching: find.byIcon(Icons.library_add),
        ),
      );
      await h.tap(find.text(h.l10n.layerPanelMenuLineartLayer));
      final lineart = h.layers.firstWhere(
        (l) => l.type == model.LayerType.autoFillLineart,
      );
      await h.seed(lineart.id, 'lineart');
      await h.closeLayers();
      for (final part in parts) {
        final id = 'autofill_${part.id}';
        debugPrint('CAPTURE_CASE:$id');
        final before = await h.art('$id-before');
        await h.capture('$id-before-ui');
        await h.assignPart(lineart.id, preset, part);
        await h.layerMenu(lineart.id);
        await h.tap(find.text(h.l10n.layerPanelMenuRunAutofill));
        final mode = part.id == 'flat' || part.id == 'outline'
            ? h.l10n.layerPanelAutofillRepaintTitle
            : h.l10n.layerPanelAutofillColorUpdateTitle;
        await h.tap(find.text(mode));
        await h.capture('$id-settings');
        await h.tap(find.text(h.l10n.layerPanelExecuteButton));
        await h.until(
          () => h.layers.any((l) => l.type == model.LayerType.autoFill),
          'auto-fill must create an output layer',
        );
        await h.settle(8);
        await h.closeLayers();
        expect(
          h.layers.where((l) => l.type == model.LayerType.autoFill).length,
          1,
        );
        final after = await h.art('$id-after');
        await h.capture('$id-after-ui');
        final changed = _changedPixels(before, after);
        expect(changed, greaterThan(100));
        h.record(
          id,
          part.name,
          changed,
          settings: part.toJson(),
          note: '機能比較用の設定。出荷時プリセット55パーツとは別に確認。',
        );
      }
      final l10n = h.l10n;
      final helpTopics = [
        ('help-custom-automation', '/help', l10n.helpCustomAutomationTitle),
        ('help-filters', '/help', l10n.helpDrawingFilterTitle),
        ('tips-automation', '/tips', l10n.tipsOfficialAutomationPresetsTitle),
        ('tips-texture', '/tips', l10n.tipsTexturePrismVhsTitle),
      ];
      for (final (id, route, title) in helpTopics) {
        appRouter.go('/');
        await h.settle();
        appRouter.go(route);
        await h.settle();
        await tester.enterText(find.byType(TextField).first, title);
        await h.settle();
        await h.tap(
          find.byWidgetPredicate((w) => w is Text && w.data == title),
        );
        await h.capture(id);
        if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
          await h.tap(find.byIcon(Icons.close).last);
        }
      }
      await h.finish();
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}

int _changedPixels(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] ||
        a[i + 1] != b[i + 1] ||
        a[i + 2] != b[i + 2] ||
        a[i + 3] != b[i + 3]) {
      count++;
    }
  }
  return count;
}

String _filterName(FilterDef filter) => switch (filter.id) {
  'Filter0013' => '単色化フィルター',
  'Filter0014' => '二値化フィルター',
  'Filter0015' => '魚眼レンズフィルター',
  'Filter0016' => '色収差フィルター',
  'Filter0017' => '眼鏡断層フィルター',
  'Filter0018' => 'ドット絵フィルター',
  _ => filter.name,
};

class _Harness {
  final WidgetTester tester;
  final String group;
  final GlobalKey boundaryKey;
  final Directory out;
  final List<Map<String, Object?>> records = [];
  late String projectId;
  late String sceneId;
  _Harness(this.tester, this.group, this.boundaryKey, this.out);

  BuildContext get context => tester.element(find.byType(MaterialApp).first);
  ProjectService get ps => context.read<ProjectService>();
  AppLocalizations get l10n =>
      AppLocalizations.of(tester.element(find.byType(CanvasArea)))!;
  List<model.Layer> get layers => ps.layersOf(projectId, sceneId, 0);

  static Future<_Harness> create(WidgetTester tester, String group) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final docs = Directory.systemTemp.createTempSync('niarim_ui_capture_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => docs.path);
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    final h = _Harness(
      tester,
      group,
      key,
      Directory('build/feature-captures/$group')..createSync(recursive: true),
    );
    await h.settle(6);
    await tester.runAsync(
      () => h.context.read<PixelArtPaletteService>().addPalette('比較用4色', [
        0xff182746,
        0xffe36b87,
        0xfff8d7a4,
        0xffffffff,
      ]),
    );
    return h;
  }

  Future<void> settle([int rounds = 3]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> until(bool Function() done, String reason) async {
    for (var i = 0; i < 500; i++) {
      if (done()) {
        await settle();
        return;
      }
      await settle(1);
    }
    fail(reason);
  }

  Future<void> tap(Finder finder) async {
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle();
  }

  Future<void> project(
    String name, {
    required String fixture,
    bool mask = false,
    bool background = false,
    int exportWidth = 256,
    int exportHeight = 256,
  }) async {
    appRouter.go('/');
    await settle();
    final p = (await tester.runAsync(
      () => ps.createProject(
        name: name,
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xffffffff,
        exportWidth: exportWidth,
        exportHeight: exportHeight,
      ),
    ))!;
    projectId = p.id;
    sceneId = ps.scenesOf(projectId).first.id;
    final source = layers.firstWhere((l) => l.type == model.LayerType.normal);
    await seed(source.id, fixture);
    if (background) {
      final bg = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: model.LayerType.normal,
        name: '比較用の背景',
        insertIndex: layers.length,
      );
      await seed(bg.id, 'background');
    }
    if (mask) {
      final selection = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: model.LayerType.selection,
        name: '中央の選択範囲',
        insertIndex: layers.length,
      );
      await seed(selection.id, 'mask');
    }
    appRouter.go('/canvas/$projectId');
    await settle(8);
    expect(
      tester.widget<CanvasArea>(find.byType(CanvasArea)).currentLayerId,
      source.id,
    );
  }

  Future<void> seed(String layerId, String fixture) async {
    final bytes = (await tester.runAsync(() => _fixture(
      fixture,
      width: ps.projects.firstWhere((p) => p.id == projectId).exportWidth,
      height: ps.projects.firstWhere((p) => p.id == projectId).exportHeight,
    )))!;
    final tm = ps.tileManagerOf(projectId);
    final key = ps.tileKeyFor(projectId, sceneId, 0, layerId);
    final project = ps.projects.firstWhere((p) => p.id == projectId);
    final width = project.exportWidth;
    final height = project.exportHeight;
    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final tile = tm.getOrCreateTile(key, tx, ty);
        for (var py = 0; py < TileManager.tileSize; py++) {
          final y = ty * TileManager.tileSize + py;
          if (y >= height) break;
          final copyWidth = math.min(TileManager.tileSize, width - tx * TileManager.tileSize);
          if (copyWidth <= 0) break;
          final srcOffset = (y * width + tx * TileManager.tileSize) * 4;
          final dstOffset = py * TileManager.tileSize * 4;
          tile.setRange(
            dstOffset,
            dstOffset + copyWidth * 4,
            bytes,
            srcOffset,
          );
        }
        tm.invalidateTile(key, tx, ty);
      }
    }
    await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      image.dispose();
    });
    final layer = layers.firstWhere((l) => l.id == layerId);
    ps.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layer: layer,
    );
    await settle();
  }

  Future<void> openMenu(String label) async {
    await tap(find.byIcon(Icons.settings).first);
    await tap(find.text(label).last);
  }

  Future<void> closeLayers() async {
    if (find.byType(LayerPanel).evaluate().isEmpty) return;
    await tap(
      find
          .descendant(
            of: find.byType(LayerPanel),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
  }

  Future<void> layerMenu(String layerId) async {
    if (find.byType(LayerPanel).evaluate().isEmpty) {
      await tap(find.byIcon(Icons.layers).first);
    }
    final tile = find.byWidgetPredicate(
      (w) => w is ListTile && w.key == ValueKey(layerId),
    );
    await tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.more_vert)),
    );
  }

  Future<void> generatedLayerView(String id, Set<String> inputIds) async {
    if (!layers.any((l) => !inputIds.contains(l.id))) return;
    final visibleInputs = layers
        .where(
          (l) =>
              inputIds.contains(l.id) &&
              l.isVisible &&
              pixelLayerTypes.contains(l.type),
        )
        .map((l) => l.id)
        .toList();
    Future<void> toggle(bool visible) async {
      await tap(find.byIcon(Icons.layers).first);
      for (final layerId in visibleInputs) {
        final tile = find.byWidgetPredicate(
          (w) => w is ListTile && w.key == ValueKey(layerId),
        );
        await tap(
          find.descendant(
            of: tile,
            matching: find.byIcon(
              visible ? Icons.visibility_off : Icons.visibility,
            ),
          ),
        );
      }
      await closeLayers();
    }

    await toggle(false);
    await art('$id-generated');
    await capture('$id-generated-ui');
    await toggle(true);
  }

  Future<void> assignPart(
    String layerId,
    AutofillPreset preset,
    AutofillPart part,
  ) async {
    await ps.setEnabledAutofillPresetIds(projectId, [preset.id]);
    await layerMenu(layerId);
    await tap(find.text(l10n.layerPanelMenuPartAssign));
    final sheet = find.byType(BottomSheet).last;
    final tile = find.descendant(
      of: sheet,
      matching: find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.title is Text &&
            (w.title as Text).data == part.name,
      ),
    );
    await tester.scrollUntilVisible(
      tile,
      230,
      scrollable: find
          .descendant(of: sheet, matching: find.byType(Scrollable))
          .last,
      maxScrolls: 25,
    );
    await tap(tile);
    expect(layers.firstWhere((l) => l.id == layerId).partId, part.id);
  }

  Future<Uint8List> layerPixels(String layerId) async => (await tester.runAsync(
    () async {
      final image = await ps
          .tileManagerOf(projectId)
          .compositeLayerToImage(ps.tileKeyFor(projectId, sceneId, 0, layerId));
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    },
  ))!;

  Future<Uint8List> art(String name) async => (await tester.runAsync(() async {
    final project = ps.projects.firstWhere((p) => p.id == projectId);
    final image = await LayerCompositor.composite(
      ps.tileManagerOf(projectId),
      layers,
      (l) => ps.tileKeyFor(projectId, sceneId, 0, l.id),
      project.exportWidth,
      project.exportHeight,
    );
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${out.path}/$name.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
    return rgba!.buffer.asUint8List();
  }))!;

  Future<void> capture(String name) async {
    await settle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
    });
  }

  void record(
    String id,
    String name,
    int changed, {
    required Map<String, Object?> settings,
    String? note,
  }) {
    records.add({
      'id': id,
      'name': name,
      'group': group,
      'changedPixels': changed,
      'totalPixels': ps.projects.firstWhere((p) => p.id == projectId).exportWidth *
          ps.projects.firstWhere((p) => p.id == projectId).exportHeight,
      'status': 'passed',
      'settings': settings,
      'note': note,
      'layers': layers
          .map((l) => {'id': l.id, 'name': l.name, 'type': l.type.name})
          .toList(),
      'before': '$id-before.png',
      'after': '$id-after.png',
      'beforeUI': '$id-before-ui.png',
      'afterUI': '$id-after-ui.png',
      'configurationUI': '$id-settings.png',
      if (File('${out.path}/$id-generated.png').existsSync()) ...{
        'generated': '$id-generated.png',
        'generatedUI': '$id-generated-ui.png',
      },
    });
    File('${out.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'environment': 'Flutter production UI / Linux renderer',
        'logicalViewport': '480x960',
        'pixelRatio': 2,
        'cases': records,
      }),
    );
    debugPrint('CAPTURE_PASS:$id changedPixels=$changed');
  }

  Future<void> finish() async {
    appRouter.go('/');
    await settle();
    await tester.pumpWidget(const SizedBox());
    await settle();
  }
}

// Synthetic source assets use precise closed regions, color/gray ramps and
// transparent margins. They are generated before the operation under test.
Future<Uint8List> _fixture(
  String kind, {
  int width = 256,
  int height = 256,
}) async {
  if (kind == 'textureReference3' || kind == 'textureReference4') {
    return Future.value(textureReferenceRgba(kind, width: width, height: height));
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (kind == 'mask') {
    canvas.drawOval(
      const Rect.fromLTWH(44, 28, 165, 190),
      Paint()..color = Colors.white,
    );
  } else if (kind == 'background') {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(256, 256), [
          const Color(0xffdd8443),
          const Color(0xff54359e),
        ]),
    );
  } else if (kind != 'empty') {
    if (kind == 'analog') {
      canvas.drawColor(Colors.white, BlendMode.src);
    }
    final line = Paint()
      ..color = const Color(0xff242739)
      ..style = PaintingStyle.stroke
      ..strokeWidth = kind == 'lineart' || kind == 'analog' ? 8 : 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final head = const Rect.fromLTWH(55, 33, 120, 120);
    final body = Path()
      ..moveTo(64, 145)
      ..lineTo(165, 145)
      ..lineTo(194, 217)
      ..quadraticBezierTo(115, 240, 35, 217)
      ..close();
    if (kind == 'color') {
      canvas.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(30, 140),
            const Offset(195, 235),
            [const Color(0xffdc7295), const Color(0xff653a9e)],
          ),
      );
      canvas.drawOval(head, Paint()..color = const Color(0xffffd8b4));
    }
    canvas.drawPath(body, line);
    canvas.drawOval(head, line);
    final hair = Path()
      ..moveTo(55, 95)
      ..quadraticBezierTo(48, 20, 115, 27)
      ..quadraticBezierTo(186, 20, 178, 98)
      ..lineTo(145, 66)
      ..lineTo(114, 86)
      ..lineTo(94, 63)
      ..close();
    if (kind == 'color') {
      canvas.drawPath(hair, Paint()..color = const Color(0xff36455e));
    }
    canvas.drawPath(hair, line);
    canvas.drawCircle(const Offset(91, 104), 4, Paint()..color = line.color);
    canvas.drawCircle(const Offset(141, 104), 4, Paint()..color = line.color);
    canvas.drawArc(
      const Rect.fromLTWH(102, 111, 27, 22),
      0.2,
      2.7,
      false,
      line,
    );
    if (kind == 'color') {
      canvas.drawRect(
        const Rect.fromLTWH(212, 24, 24, 152),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 24),
            const Offset(0, 176),
            [const Color(0xff101010), const Color(0xffeeeeee)],
          ),
      );
      for (var i = 0; i < 6; i++) {
        canvas.drawRect(
          Rect.fromLTWH(207 + (i % 2) * 17, 188 + (i ~/ 2) * 15, 16, 14),
          Paint()
            ..color = [
              Colors.red,
              Colors.cyan,
              Colors.green,
              Colors.purple,
              Colors.blue,
              Colors.yellow,
            ][i],
        );
      }
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}
