import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all stocking/1px tones and spaced inverse grid exist, no redundant checker inverse', () async {
    SharedPreferences.setMockInitialValues({});
    final tones = ToneService();
    await tones.init();
    final byId = {for (final tone in tones.tones) tone.id: tone};
    for (final id in [
      'Tone0007', 'Tone0008', 'Tone0009',
      'Tone0010', 'Tone0011', 'Tone0012', 'Tone0013',
      'Tone0014', 'Tone0015', 'Tone0048', 'Tone0049',
      'Tone0063',
    ]) {
      expect(byId.containsKey(id), true, reason: 'missing original tone $id');
    }
    expect(byId['Tone0048']!.name, contains('ボーダー'));
    expect(byId['Tone0049']!.name, contains('ストライプ'));
    expect(byId['Tone0063']!.name, contains('反転'));
    expect(byId.containsKey('Tone0064'), isFalse,
        reason: 'Inverting a 1px checkerboard is only a phase shift');

    final grid = generateBuiltInToneTexture(byId['Tone0008']!, size: 16);
    final gridInv = generateBuiltInToneTexture(byId['Tone0063']!, size: 16);
    for (var i = 3; i < checker.length; i += 4) {
      expect(grid[i] + gridInv[i], 255, reason: 'grid pixel $i');
    }
    // The inverted grid is a single-pixel dot with one clear pixel to
    // the left/right and above/below. It is not a checkerboard.
    int dotAlpha(int x, int y) => gridInv[(y * 16 + x) * 4 + 3];
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        expect(dotAlpha(x, y), (x.isOdd && y.isOdd) ? 255 : 0,
            reason: '1px dot spacing at ($x, $y)');
      }
    }
    // An earlier "pixel scatter" preset already had the same 2x2 dot
    // spacing, shifted one pixel along each axis. Preserve that user data.
    final scatter = generateBuiltInToneTexture(byId['Tone0009']!, size: 16);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        expect(scatter[(y * 16 + x) * 4 + 3],
            (x.isEven && y.isEven) ? 255 : 0);
      }
    }
    final stripe = generateBuiltInToneTexture(byId['Tone0049']!, size: 16);
    final border = generateBuiltInToneTexture(byId['Tone0048']!, size: 16);
    int alpha(List<int> image, int x, int y) => image[(y * 16 + x) * 4 + 3];
    expect(alpha(stripe, 0, 0), isNot(alpha(stripe, 1, 0)));
    expect(alpha(stripe, 0, 0), alpha(stripe, 0, 1));
    expect(alpha(border, 0, 0), isNot(alpha(border, 0, 1)));
    expect(alpha(border, 0, 0), alpha(border, 1, 0));
  });

  test('renaming a duplicated procedural tone retains its raster pattern', () {
    const edited = Tone(
      id: 'my-renamed-tone',
      name: '自由に付けた名前',
      patternName: 'ピクセル格子反転（1px）',
    );
    final restored = Tone.fromJson(edited.toJson());
    expect(restored.name, edited.name);
    expect(restored.patternName, edited.patternName);
    final expected = generateBuiltInToneTexture(
      const Tone(id: 'original', name: 'ピクセル格子反転（1px）'),
      size: 16,
    );
    expect(generateBuiltInToneTexture(restored, size: 16), expected);
  });

  test('existing tone storage is augmented instead of replaced', () async {
    SharedPreferences.setMockInitialValues({
      'tones': ['{"id":"my-tone","name":"オリジナル","tags":["custom"],"isFavorite":true}'],
    });
    final tones = ToneService();
    await tones.init();
    expect(tones.tones.any((t) => t.id == 'my-tone' && t.isFavorite), true);
    expect(tones.tones.any((t) => t.id == 'Tone0063'), true);
    expect(tones.tones.any((t) => t.id == 'Tone0015'), true);
  });

  test('analog media have editable and persistent real-grain parameters', () {
    final brushes = {for (final b in BrushService.builtInBrushes) b.id: b};
    for (final id in [
      'Brush0007', // Original pencil.
      'Brush0012', // Original chalk.
      'Brush0026', // Charcoal.
      'Brush0027', // Gouache.
      'Brush0028', // 4B graphite.
      'Brush0029', // Pastel.
    ]) {
      expect(brushes.containsKey(id), true, reason: 'missing media $id');
    }
    for (final id in ['Brush0026', 'Brush0027', 'Brush0028', 'Brush0029']) {
      final brush = brushes[id]!;
      expect(brush.grainStrength, greaterThan(0), reason: brush.name);
      final copy = brush.copyWith(
        id: '$id-user',
        name: 'My mixed brush',
        grainStrength: 37,
      );
      final roundTrip = Brush.fromJson(copy.toJson());
      expect(roundTrip.grainStrength, 37);
      expect(roundTrip.name, 'My mixed brush');
    }
  });

  test('old dock selections restore as only one managed pen subtool dock', () async {
    SharedPreferences.setMockInitialValues({
      'default_docked_panels': [
        'brush', 'tone', 'stamp', 'colorPicker', 'layer',
      ],
      'tool_option_dock_order': [
        'stamp', 'tone', 'brush', 'onionSkin', 'filter',
      ],
      'right_dock_order': ['colorPicker', 'layer'],
    });
    final settings = SettingsService();
    await settings.init();
    expect(settings.defaultDockedPanels.contains(CanvasDockPanel.penSubTool), true);
    expect(settings.defaultDockedPanels.any(isLegacyMaterialDock), false);
    expect(
      settings.toolOptionDockOrder
          .where((p) => p == CanvasDockPanel.penSubTool).length,
      1,
    );
    expect(settings.toolOptionDockOrder.any(isLegacyMaterialDock), false);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush, CanvasDockPanel.tone,
    });
    expect(settings.defaultDockedPanels, {CanvasDockPanel.penSubTool});
  });
}
