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
import 'package:niarim/engine/autofill_batch_runner.dart';
import 'package:niarim/engine/autofill_engine.dart';
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
import 'package:niarim/utils/filter_display_name.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/widgets/custom_automation_draft_sheet.dart';
import 'package:niarim/widgets/pixel_art_palette_picker_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/pick_filter_card.dart';

const _captureMatch = String.fromEnvironment('CAPTURE_MATCH');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const group = String.fromEnvironment('CAPTURE_GROUP', defaultValue: 'all');
  if (group == 'all' || group == 'filters' || group == 'filters-core') {
    testWidgets('all filter cards and preset choices apply through Canvas UI', (
      tester,
    ) async {
      final h = await _Harness.create(tester, 'filters');
      final filters = h.context.read<FilterService>().filters;
      for (final filter in filters) {
        if (group == 'filters-core' &&
            filter.kind == FilterKind.auroraHologram) {
          continue;
        }
        final variants = filter.id == 'Filter0004'
            ? ToneCurvePreset.values.map((e) => e.name).toList()
            : filter.kind == FilterKind.auroraHologram
            ? AuroraHologramPreset.values.map((e) => e.name).toList()
            : filter.kind == FilterKind.pixelate
            ? [
                // Each colour mode, then the same with the dithering switch
                // off (before the palette case, which copies its colours
                // over the specified ones).
                for (final mode in PixelColorMode.values) ...[
                  mode.name,
                  if (mode != PixelColorMode.none) '${mode.name}_flat',
                ],
              ]
            : filter.kind == FilterKind.animeStyle
            // The initial settings, and the border lines dark and wide.
            ? ['default', 'bold']
            : <String>['default'];
        for (final variant in variants) {
          final id = '${filter.id}_$variant';
          if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) continue;
          debugPrint('CAPTURE_CASE:$id');
          await h.project(
            id,
            // 墨溜まり on 1 px line art, where nothing hides the pool: the
            // Olympic rings, crossing at sharp and wide angles alike.
            fixture: filter.kind == FilterKind.inkPool
                ? 'olympicRings'
                : filter.kind == FilterKind.autoLineart
                ? 'lineart'
                // Prism as it is drawn: small slender leaves of dark red on
                // their own layer, which become rainbow streaks.
                : filter.kind == FilterKind.prism
                ? 'prismLeaves'
                : 'color',
            mask: filter.kind == FilterKind.lensDistortion,
            // Prism adds light (Linear Dodge): over nothing it shows its own
            // dark colours, so it gets a picture to shine on, as in use.
            underlay: filter.kind == FilterKind.prism ? 'color' : null,
            background:
                filter.kind == FilterKind.backgroundBlend ||
                filter.kind == FilterKind.prism,
            backgroundFixture: filter.kind == FilterKind.prism
                ? 'grey'
                : 'background',
            // At three times the size, the leaves are as large next to the
            // default blur (17 px) as on a phone-sized canvas.
            exportWidth: filter.kind == FilterKind.prism ? 768 : 256,
            exportHeight: filter.kind == FilterKind.prism ? 768 : 256,
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
            _filterSearchLabel(h, filter),
          );
          await h.settle();
          final filterCards = find.descendant(
            of: panel,
            matching: find.byWidgetPredicate(
              (w) => w is Text && w.data == _filterSearchLabel(h, filter),
            ),
          );
          await h.tap(filterCards);
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
              (e) => e.name == variant.split('_').first,
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
            if (mode != PixelColorMode.none) {
              // The dithering switch, set as the case asks (the filter keeps
              // it from the case before).
              final dither = !variant.endsWith('_flat');
              final toggle = find.byKey(
                const ValueKey('pixel-art-dither-toggle'),
              );
              await tester.ensureVisible(toggle);
              if (h.context.read<FilterService>().currentFilter!.pixelDither !=
                  dither) {
                await h.tap(toggle);
              }
              expect(
                h.context.read<FilterService>().currentFilter!.pixelDither,
                dither,
              );
            }
          }
          if (filter.kind == FilterKind.animeStyle) {
            final bold = variant == 'bold';
            h.context.read<FilterService>().updateFilterParams(
              filter.id,
              edgeStrength: bold ? 1 : filter.edgeStrength,
              animeBorderWidth: bold ? 3 : filter.animeBorderWidth,
            );
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
                : variant.startsWith('palette')
                ? '選んだパレットの4色を複製して使用する仕様。'
                : null,
          );
        }
      }
      await h.finish();
    }, timeout: const Timeout(Duration(minutes: 25)));
  }
  if (group == 'all' || group == 'pixel-compare') {
    testWidgets(
      'Pixel Art (blocks / canvas resolution) and Mosaic differ on the same '
      'production UI fixture',
      (tester) async {
        final h = await _Harness.create(tester, 'pixel-compare');
        final filters = h.context.read<FilterService>().filters;
        final pixelArt = filters.firstWhere(
          (f) => f.kind == FilterKind.pixelate,
        );
        final mosaic = filters.firstWhere((f) => f.kind == FilterKind.mosaic);
        const sixColours = [
          0xFF000000,
          0xFFFFFFFF,
          0xFFFF0000,
          0xFFFFFF00,
          0xFF0000FF,
          0xFF00FF00,
        ];
        // The block cases come first: they use the filter's default block
        // size, which the dot cases then change (the panel keeps it).
        final cases = [
          ('pixel_art_blocks_six_colours', pixelArt, false, 256, 256),
          // The colour-specified samples on a 320 x 240 canvas too.
          ('pixel_art_blocks_six_colours_320x240', pixelArt, false, 320, 240),
          ('pixel_art_dots_canvas_resolution', pixelArt, true, 256, 256),
          (
            'pixel_art_dots_canvas_resolution_320x240',
            pixelArt,
            true,
            320,
            240,
          ),
          ('mosaic_same_fixture', mosaic, false, 256, 256),
        ];
        final outputs = <String, Uint8List>{};
        Uint8List? original;
        for (final (id, filter, byDots, width, height) in cases) {
          debugPrint('CAPTURE_CASE:$id');
          final square = width == 256 && height == 256;
          await h.project(
            id,
            fixture: 'pixelArtSix',
            exportWidth: width,
            exportHeight: height,
          );
          final before = await h.art('$id-before');
          if (square) original ??= before;
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
            _filterName(h, filter),
          );
          await h.settle();
          await h.tap(
            find.descendant(
              of: panel,
              matching: find.byWidgetPredicate(
                (w) => w is Text && w.data == _filterName(h, filter),
              ),
            ),
          );
          FilterDef current() => h.context.read<FilterService>().currentFilter!;
          expect(current().kind, filter.kind);
          if (filter.kind == FilterKind.pixelate) {
            if (current().pixelColorMode != PixelColorMode.explicit) {
              await h.tap(
                find.descendant(
                  of: panel,
                  matching: find.byType(
                    DropdownButtonFormField<PixelColorMode>,
                  ),
                ),
              );
              await h.tap(find.text(h.l10n.pixelColorModeExplicit).last);
            }
            expect(current().pixelColorMode, PixelColorMode.explicit);
            expect(current().pixelExplicitColors, sixColours);
            await h.tap(
              find.descendant(
                of: panel,
                matching: find.text(
                  byDots
                      ? h.l10n.filterPixelateModeDots
                      : h.l10n.filterPixelateModeBlock,
                ),
              ),
            );
            expect(current().pixelArtByDots, byDots);
            if (byDots) {
              // Drag "dots across" to its right end: the canvas's own size.
              final across = find.descendant(
                of: find.byKey(const ValueKey('pixel-art-dots-wide')),
                matching: find.byType(Slider),
              );
              await tester.ensureVisible(across);
              await tester.pump();
              final rect = tester.getRect(across);
              // A frame between the moves, as on a device: the slider only
              // reports a value that differs from the one it was built
              // with, so a drag that never rebuilds it would lose the last
              // step when the thumb started at the end.
              final drag = await tester.startGesture(rect.center);
              await drag.moveBy(const Offset(kDragSlopDefault, 0));
              await tester.pump();
              await drag.moveBy(Offset(rect.width, 0));
              await tester.pump();
              await drag.up();
              await h.settle();
              for (final (key, size) in [
                ('pixel-art-dots-wide', width),
                ('pixel-art-dots-high', height),
              ]) {
                expect(
                  tester
                      .widget<Slider>(
                        find.descendant(
                          of: find.byKey(ValueKey(key)),
                          matching: find.byType(Slider),
                        ),
                      )
                      .value,
                  size,
                  reason: '$key follows, keeping the proportions',
                );
              }
            } else {
              expect(
                find.descendant(
                  of: panel,
                  matching: find.text(
                    h.l10n.filterPixelateDotsSummary(width ~/ 8, height ~/ 8),
                  ),
                ),
                findsOneWidget,
              );
            }
            expect(current().pixelArtCellSize(width, height), byDots ? 1 : 8);
          }
          await h.capture('$id-settings');
          await h.tap(find.text(h.l10n.filterApplyButton));
          await h.until(
            () => panel.evaluate().isEmpty,
            '$id apply must finish and close the panel',
          );
          final after = await h.art('$id-after');
          if (square) outputs[id] = after;
          await h.capture('$id-after-ui');
          final alphas = {for (var i = 3; i < after.length; i += 4) after[i]};
          if (filter.kind == FilterKind.pixelate) {
            expect(alphas, {0, 255}, reason: '$id leaves no soft edge');
            for (var i = 0; i < after.length; i += 4) {
              if (after[i + 3] == 0) continue;
              final argb =
                  0xFF000000 |
                  (after[i] << 16) |
                  (after[i + 1] << 8) |
                  after[i + 2];
              expect(sixColours, contains(argb), reason: '$id palette');
            }
            if (!byDots) {
              for (var y = 0; y < height; y++) {
                for (var x = 0; x < width; x++) {
                  final i = (y * width + x) * 4;
                  final j = ((y ~/ 8 * 8) * width + x ~/ 8 * 8) * 4;
                  expect(
                    after.sublist(i, i + 4),
                    after.sublist(j, j + 4),
                    reason: 'square 8px blocks at ($x, $y)',
                  );
                }
              }
            }
          } else {
            expect(
              alphas.where((a) => a != 0 && a != 255),
              isNotEmpty,
              reason: 'Mosaic averages alpha along soft edges',
            );
          }
          h.record(
            id,
            filter.name,
            _changedPixels(before, after),
            settings: {
              'kind': filter.kind.name,
              if (filter.kind == FilterKind.pixelate) ...{
                'pixelArtByDots': byDots,
                'cellSize': current().pixelArtCellSize(width, height),
                'canvas': '$width x $height',
                'colorMode': current().pixelColorMode.name,
                'colors': current().pixelExplicitColors,
                'dither': current().pixelDither,
              },
              if (filter.kind == FilterKind.mosaic)
                'blockSize': current().strength,
            },
            note: switch (id) {
              'pixel_art_blocks_six_colours' => '8pxの正方形ブロック・黒白赤黄青緑の6色・半透明なし。',
              'pixel_art_dots_canvas_resolution' =>
                '横のドット数のスライダーを右端（キャンバスの画素数256）まで動かし、縦も256に連動＝1画素1ドット・6色・半透明なし。',
              'pixel_art_blocks_six_colours_320x240' =>
                'キャンバス320×240。8pxの正方形ブロック（40×30ドット）・6色・半透明なし。',
              'pixel_art_dots_canvas_resolution_320x240' =>
                'キャンバス320×240。横のドット数を右端（320）まで動かし、縦も240に連動＝1画素1ドット・6色・半透明なし。',
              _ => 'ブロック内の色と不透明度を平均する別効果。',
            },
          );
        }
        final results = [original!, ...outputs.values];
        for (var a = 0; a < results.length; a++) {
          for (var b = a + 1; b < results.length; b++) {
            expect(
              results[a],
              isNot(orderedEquals(results[b])),
              reason:
                  'Original / Pixel Art (blocks) / Pixel Art (canvas) / '
                  'Mosaic must all differ ($a vs $b)',
            );
          }
        }
        await h.finish();
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  }

  if (group == 'all' || group == 'automation') {
    testWidgets(
      'every official automation executes through the Canvas manager',
      (tester) async {
        final h = await _Harness.create(tester, 'automation');
        final items = h.context.read<CustomAutomationService>().items;
        expect(items.length, 3);
        for (final item in items) {
          final id = item.id;
          if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) continue;
          debugPrint('CAPTURE_CASE:$id');
          // Line colour trace takes its colours from the character's fills
          // on the layer under the line art; nothing else is on the canvas.
          await h.project(
            id,
            fixture: id.contains('analog') ? 'analog' : 'lineart',
            underlay: id.contains('color_trace') ? 'fill' : null,
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
      'each shipped auto-fill preset paints all of its parts in one layered scene',
      (tester) async {
        final h = await _Harness.create(tester, 'autofill');
        final presets = h.context.read<AutofillPresetService>().presets;
        expect(presets.length, 3);
        expect(presets.fold<int>(0, (n, p) => n + p.parts.length), 55);
        for (final preset in presets) {
          final id = 'autofill_preset_${preset.id}';
          if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) continue;
          debugPrint('CAPTURE_CASE:$id');
          await h.project(id, fixture: 'empty');
          await h.ps.setEnabledAutofillPresetIds(h.projectId, [preset.id]);

          // One line-art layer per preset part. Each layer owns a separate
          // closed region so a single repaint pass demonstrates the complete
          // preset rather than producing one PDF page per part.
          for (var i = 0; i < preset.parts.length; i++) {
            final part = preset.parts[i];
            final lineart = h.ps.addLayer(
              projectId: h.projectId,
              sceneId: h.sceneId,
              frameIndex: 0,
              type: model.LayerType.autoFillLineart,
              name: '${part.name}（線画）',
              insertIndex: h.layers.length,
            );
            await h.seedAutofillRegion(
              lineart.id,
              index: i,
              count: preset.parts.length,
            );
            h.ps.assignAutofillPart(
              projectId: h.projectId,
              sceneId: h.sceneId,
              frameIndex: 0,
              lineartLayerId: lineart.id,
              partId: part.id,
              partName: part.name,
            );
          }
          await h.settle(4);
          final before = await h.art('$id-before');
          await h.capture('$id-before-ui');

          var applied = 0;
          for (final lineart
              in h.layers
                  .where((l) => l.type == model.LayerType.autoFillLineart)
                  .toList()) {
            // Filling decodes and composites images on the engine's real
            // clock, which FakeAsync never advances: awaited directly, this
            // never finished.
            final result = await tester.runAsync(
              () => runAutofillForLayer(
                projectService: h.ps,
                presetService: h.context.read<AutofillPresetService>(),
                toneService: h.context.read<ToneService>(),
                projectId: h.projectId,
                sceneId: h.sceneId,
                frameIndex: 0,
                lineartLayer: lineart,
                mode: AutofillMode.repaint,
              ),
            );
            if (result == AutofillBatchResult.applied) applied++;
          }
          expect(applied, preset.parts.length);
          await h.settle(6);
          final after = await h.art('$id-after');
          await h.capture('$id-after-ui');
          final changed = _changedPixels(before, after);
          expect(changed, greaterThan(100));
          expect(
            h.layers.where((l) => l.type == model.LayerType.autoFill).length,
            preset.parts.length,
          );
          h.record(
            id,
            '${preset.name} / 全${preset.parts.length}パーツ一括確認',
            changed,
            settings: {
              'presetId': preset.id,
              'presetName': preset.name,
              'partCount': preset.parts.length,
              'parts': preset.parts.map((p) => p.toJson()).toList(),
              'captureLayout': 'one layered scene per preset',
            },
            note: 'プリセット全パーツを別々の線画レイヤーへ割り当て、同一キャンバスで一括描画した最終結果。',
          );
        }
        await h.finish();
      },
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }
  if (group == 'all' || group == 'blend') {
    testWidgets(
      'all blend modes composite through the production LayerPanel UI',
      (tester) async {
        final h = await _Harness.create(tester, 'blend');
        for (final mode in model.LayerBlendMode.values) {
          final id = 'blend_${mode.name}';
          if (_captureMatch.isNotEmpty && !id.contains(_captureMatch)) continue;
          debugPrint('CAPTURE_CASE:$id');
          await h.project(id, fixture: 'background');
          final source = h.layers.firstWhere(
            (l) => l.type == model.LayerType.normal,
          );
          // Colour bars over the character: each mode's effect on light,
          // dark and coloured ground is visible, and the half-opaque lower
          // part tells Addition from Linear Dodge.
          await h.seed(source.id, 'blendSwatches');
          final backdrop = h.ps.addLayer(
            projectId: h.projectId,
            sceneId: h.sceneId,
            frameIndex: 0,
            type: model.LayerType.normal,
            name: 'Blend backdrop',
            insertIndex: h.layers.length,
          );
          await h.seed(backdrop.id, 'color');
          final before = await h.art('$id-before');
          await h.capture('$id-before-ui');

          await h.layerMenu(source.id);
          await h.tap(find.text(h.l10n.autofillPartBlendModeLabel));
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          final label = h.blendModeName(mode);
          final list = find.descendant(
            of: dialog,
            matching: find.byType(Scrollable),
          );
          expect(list, findsOneWidget);
          Finder choice() =>
              find.descendant(of: dialog, matching: find.text(label));
          for (var i = 0; i < 30 && choice().evaluate().isEmpty; i++) {
            await tester.drag(list, const Offset(0, -220));
            await h.settle(1);
          }
          expect(
            choice(),
            findsOneWidget,
            reason: '$id must be reachable in the blend dialog',
          );
          await h.capture('$id-settings');
          await h.tap(choice());
          await h.closeLayers();
          expect(
            h.layers.firstWhere((l) => l.id == source.id).blendMode,
            mode,
            reason: '$id must be selected through the production LayerPanel',
          );
          final after = await h.art('$id-after');
          await h.capture('$id-after-ui');
          final changed = _changedPixels(before, after);
          if (mode != model.LayerBlendMode.normal) {
            expect(
              changed,
              greaterThan(0),
              reason: '$id must change the composite',
            );
          }
          h.record(
            id,
            label,
            changed,
            settings: {'blendMode': mode.name},
            note: mode == model.LayerBlendMode.addition
                ? 'Porter-Duff Plus。Linear Dodgeとは別モード。'
                : mode == model.LayerBlendMode.linearDodge
                ? 'RGB Linear Dodge + source-over。Additionとは別モード。'
                : null,
          );
        }
        await h.finish();
      },
      timeout: const Timeout(Duration(minutes: 12)),
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
      await pickFilterCard(tester, 'Filter0001');
      await h.settle();
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

/// The filter's name as the panel shows it.
String _filterName(_Harness h, FilterDef filter) =>
    filterDisplayName(h.l10n, filter);

String _filterSearchLabel(_Harness h, FilterDef filter) {
  if (filter.id == FilterService.genericNoiseFilterId) {
    return h.l10n.filterNameGenericNoise;
  }
  return _filterName(h, filter);
}

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
    expect(finder, findsWidgets);
    final target = finder.first;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await settle();
  }

  Future<void> project(
    String name, {
    required String fixture,
    bool mask = false,
    bool background = false,
    String backgroundFixture = 'background',
    String? underlay,
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
    if (underlay != null) {
      final under = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: model.LayerType.normal,
        name: '塗り',
        insertIndex: layers.length,
      );
      await seed(under.id, underlay);
    }
    if (background) {
      final bg = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: model.LayerType.normal,
        name: '比較用の背景',
        insertIndex: layers.length,
      );
      await seed(bg.id, backgroundFixture);
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
    final bytes = (await tester.runAsync(
      () => _fixture(
        fixture,
        width: ps.projects.firstWhere((p) => p.id == projectId).exportWidth,
        height: ps.projects.firstWhere((p) => p.id == projectId).exportHeight,
      ),
    ))!;
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
          final copyWidth = math.min(
            TileManager.tileSize,
            width - tx * TileManager.tileSize,
          );
          if (copyWidth <= 0) break;
          final srcOffset = (y * width + tx * TileManager.tileSize) * 4;
          final dstOffset = py * TileManager.tileSize * 4;
          tile.setRange(dstOffset, dstOffset + copyWidth * 4, bytes, srcOffset);
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

  Future<void> seedAutofillRegion(
    String layerId, {
    required int index,
    required int count,
  }) async {
    final project = ps.projects.firstWhere((p) => p.id == projectId);
    final w = project.exportWidth;
    final h = project.exportHeight;
    final int columns = math.max(1, math.sqrt(count).ceil());
    final int rows = math.max(1, (count / columns).ceil());
    final cellW = w / columns;
    final cellH = h / rows;
    final int col = index % columns;
    final int row = index ~/ columns;
    final inset = math.max(3.0, math.min(cellW, cellH) * .12);
    final rect = Rect.fromLTWH(
      col * cellW + inset,
      row * cellH + inset,
      math.max(4.0, cellW - inset * 2),
      math.max(4.0, cellH - inset * 2),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xff242739)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final picture = recorder.endRecording();
    final data = await tester.runAsync(() async {
      final image = await picture.toImage(w, h);
      picture.dispose();
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return rgba;
    });
    final bytes = data!.buffer.asUint8List();
    final tm = ps.tileManagerOf(projectId);
    final key = ps.tileKeyFor(projectId, sceneId, 0, layerId);
    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final tile = tm.getOrCreateTile(key, tx, ty);
        for (var py = 0; py < TileManager.tileSize; py++) {
          final y = ty * TileManager.tileSize + py;
          if (y >= h) break;
          final copyWidth = math.min(
            TileManager.tileSize,
            w - tx * TileManager.tileSize,
          );
          if (copyWidth <= 0) break;
          final srcOffset = (y * w + tx * TileManager.tileSize) * 4;
          final dstOffset = py * TileManager.tileSize * 4;
          tile.setRange(dstOffset, dstOffset + copyWidth * 4, bytes, srcOffset);
        }
        tm.invalidateTile(key, tx, ty);
      }
    }
    ps.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layer: layers.firstWhere((l) => l.id == layerId),
    );
    await settle();
  }

  Future<void> openMenu(String label) async {
    await tap(find.byIcon(Icons.settings).first);
    await tap(find.text(label).last);
  }

  String blendModeName(model.LayerBlendMode mode) => switch (mode) {
    model.LayerBlendMode.normal => l10n.blendModeNormal,
    model.LayerBlendMode.multiply => l10n.blendModeMultiply,
    model.LayerBlendMode.screen => l10n.blendModeScreen,
    model.LayerBlendMode.overlay => l10n.blendModeOverlay,
    model.LayerBlendMode.addition => l10n.blendModeAddition,
    model.LayerBlendMode.subtract => l10n.blendModeSubtract,
    model.LayerBlendMode.darken => l10n.blendModeDarken,
    model.LayerBlendMode.lighten => l10n.blendModeLighten,
    model.LayerBlendMode.colorBurn => l10n.blendModeColorBurn,
    model.LayerBlendMode.colorDodge => l10n.blendModeColorDodge,
    model.LayerBlendMode.hardLight => l10n.blendModeHardLight,
    model.LayerBlendMode.softLight => l10n.blendModeSoftLight,
    model.LayerBlendMode.difference => l10n.blendModeDifference,
    model.LayerBlendMode.hue => l10n.blendModeHue,
    model.LayerBlendMode.saturation => l10n.blendModeSaturation,
    model.LayerBlendMode.color => l10n.blendModeColor,
    model.LayerBlendMode.luminosity => l10n.blendModeLuminosity,
    model.LayerBlendMode.linearBurn => l10n.blendModeLinearBurn,
    model.LayerBlendMode.linearDodge => l10n.blendModeLinearDodge,
    model.LayerBlendMode.vividLight => l10n.blendModeVividLight,
    model.LayerBlendMode.linearLight => l10n.blendModeLinearLight,
    model.LayerBlendMode.pinLight => l10n.blendModePinLight,
    model.LayerBlendMode.hardMix => l10n.blendModeHardMix,
    model.LayerBlendMode.exclusion => l10n.blendModeExclusion,
    model.LayerBlendMode.divide => l10n.blendModeDivide,
  };

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
    // Blend modes act on the paper too (as on the canvas): give it when a
    // layer is not in the normal mode.
    final image = await LayerCompositor.composite(
      ps.tileManagerOf(projectId),
      layers,
      (l) => ps.tileKeyFor(projectId, sceneId, 0, l.id),
      project.exportWidth,
      project.exportHeight,
      paperColor: LayerCompositor.paperForBlendModes(
        layers,
        project.backgroundColor,
      ),
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
      'totalPixels':
          ps.projects.firstWhere((p) => p.id == projectId).exportWidth *
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
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // The pictures are drawn for 256 x 256; on another canvas size they are
  // scaled to fit, centred.
  final fit = math.min(width / 256, height / 256);
  canvas
    ..translate((width - 256 * fit) / 2, (height - 256 * fit) / 2)
    ..scale(fit);
  if (kind == 'fill') {
    // The character's fills alone, without lines: what line colour trace
    // takes its colours from.
    canvas.drawPath(
      Path()
        ..moveTo(64, 145)
        ..lineTo(165, 145)
        ..lineTo(194, 217)
        ..quadraticBezierTo(115, 240, 35, 217)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(30, 140),
          const Offset(195, 235),
          [const Color(0xffdc7295), const Color(0xff653a9e)],
        ),
    );
    canvas.drawOval(
      const Rect.fromLTWH(55, 33, 120, 120),
      Paint()..color = const Color(0xffffd8b4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(55, 95)
        ..quadraticBezierTo(48, 20, 115, 27)
        ..quadraticBezierTo(186, 20, 178, 98)
        ..lineTo(145, 66)
        ..lineTo(114, 86)
        ..lineTo(94, 63)
        ..close(),
      Paint()..color = const Color(0xff36455e),
    );
  } else if (kind == 'colorTranslucent') {
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.62),
    );
  }
  if (kind == 'blendSwatches') {
    const colours = [
      Color(0xffe63a3a),
      Color(0xfff2d23c),
      Color(0xff3a5ee6),
      Color(0xffffffff),
      Color(0xff000000),
    ];
    for (var i = 0; i < colours.length; i++) {
      final left = 16.0 + i * 46;
      canvas.drawRect(
        Rect.fromLTWH(left, 20, 38, 140),
        Paint()..color = colours[i],
      );
      canvas.drawRect(
        Rect.fromLTWH(left, 160, 38, 76),
        Paint()..color = colours[i].withValues(alpha: 0.5),
      );
    }
  } else if (kind == 'pixelArtSix') {
    // Black, white, red, yellow, blue and green strokes, anti-aliased, on a
    // transparent layer: thick and thin, slanted and round.
    void stroke(Offset a, Offset b, double width, Color color) =>
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        );
    canvas.drawCircle(
      const Offset(78, 82),
      52,
      Paint()..color = const Color(0xff141414),
    );
    canvas.drawCircle(
      const Offset(78, 82),
      38,
      Paint()..color = const Color(0xfff4f4f0),
    );
    stroke(
      const Offset(150, 20),
      const Offset(236, 120),
      14,
      const Color(0xffe0262c),
    );
    stroke(
      const Offset(140, 132),
      const Offset(240, 150),
      3,
      const Color(0xff1e2ad0),
    );
    stroke(
      const Offset(24, 236),
      const Offset(120, 160),
      2,
      const Color(0xff101010),
    );
    stroke(
      const Offset(130, 240),
      const Offset(230, 180),
      22,
      const Color(0xffe8d424),
    );
    canvas.drawOval(
      const Rect.fromLTWH(40, 170, 70, 40),
      Paint()..color = const Color(0xff2cbc44),
    );
  } else if (kind == 'olympicRings') {
    final line = Paint()
      ..color = const Color(0xff242739)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final centre in const [
      Offset(54.8, 100),
      Offset(128, 100),
      Offset(201.2, 100),
      Offset(91.4, 130.9),
      Offset(164.6, 130.9),
    ]) {
      canvas.drawCircle(centre, 30, line);
    }
  } else if (kind == 'prismLeaves') {
    // Slender leaves of dark red (HSV value 30%), the way a prism is drawn:
    // a large one over the paper, small ones over the face and clothes.
    void leaf(Offset centre, double length, double width, double degrees) {
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(degrees * math.pi / 180);
      final half = length / 2;
      canvas
        ..drawPath(
          Path()
            ..moveTo(0, -half)
            ..quadraticBezierTo(width, 0, 0, half)
            ..quadraticBezierTo(-width, 0, 0, -half)
            ..close(),
          Paint()..color = const Color(0xff4d0000),
        )
        ..restore();
    }

    leaf(const Offset(28, 92), 110, 26, 14);
    leaf(const Offset(92, 112), 44, 12, -26);
    leaf(const Offset(142, 118), 36, 10, 32);
    leaf(const Offset(116, 194), 56, 13, 22);
    leaf(const Offset(80, 64), 40, 11, 10);
  } else if (kind == 'grey') {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()..color = const Color(0xffa9a5a6),
    );
  } else if (kind == 'mask') {
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
    if (kind == 'color' || kind == 'colorTranslucent') {
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
    if (kind == 'color' || kind == 'colorTranslucent') {
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
    if (kind == 'color' || kind == 'colorTranslucent') {
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
  if (kind == 'colorTranslucent') canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}
