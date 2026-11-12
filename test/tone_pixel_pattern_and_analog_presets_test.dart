import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  int alpha(Uint8List pixels, int size, int x, int y) =>
      pixels[(y * size + x) * 4 + 3];

  test('Pixel scatter is isolated dots with one-pixel gaps on both axes', () {
    const size = 8;
    final pixels = generateBuiltInToneTexture(
      const Tone(id: 'Tone0009', name: 'ピクセル散らし（1px）'), size: size,
    );
    var filled = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final expected = x.isEven && y.isEven ? 255 : 0;
        expect(alpha(pixels, size, x, y), expected,
            reason: 'one-dot one-gap at pixel ($x, $y)');
        if (expected != 0) filled++;
      }
    }
    expect(filled, size * size ~/ 4);
  });

  test('Normal 1px grid, checker, border and stripe are distinct masks', () {
    const size = 8;
    final specs = [
      (name: 'ピクセル格子（1px）', matches: (int x, int y) => x.isEven || y.isEven),
      (name: 'ピクセル市松（1px）', matches: (int x, int y) => (x + y).isEven),
      (name: 'ピクセルボーダー（横1px）', matches: (int x, int y) => y.isEven),
      (name: 'ピクセルストライプ（縦1px）', matches: (int x, int y) => x.isEven),
    ];
    for (final spec in specs) {
      final pixels = generateBuiltInToneTexture(
        Tone(id: spec.name, name: spec.name), size: size,
      );
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          expect(alpha(pixels, size, x, y) != 0, spec.matches(x, y),
              reason: spec.name + ': (' + x.toString() + ',' + y.toString() + ')');
        }
      }
    }
  });

  test('All six stocking and tights deniers remain registered and distinct', () async {
    final service = ToneService();
    await service.init();
    final patterns = <String>{};
    for (final denier in [10, 20, 30, 40, 60, 80]) {
      final tone = service.tones.singleWhere((t) =>
          t.name.contains(denier.toString() + 'デニール'));
      final pixels = generateBuiltInToneTexture(tone, size: 64);
      patterns.add(String.fromCharCodes([
        for (var i = 3; i < pixels.length; i += 4) pixels[i] != 0 ? 49 : 48,
      ]));
    }
    expect(patterns.length, 6);
    expect(service.tones.any((t) => t.id == 'Tone0009'), isTrue);
    expect(service.tones.any((t) => t.id == 'Tone0063'), isFalse);
    expect(service.tones.any((t) => t.id == 'Tone0064'), isFalse);
    service.dispose();
  });

  test('Unedited legacy inverses retire but personalized copies survive', () async {
    for (final retired in [
      const Tone(id: 'Tone0063', name: 'ピクセル格子反転（1px）'),
      const Tone(id: 'Tone0064', name: 'ピクセル市松反転（1px）'),
    ]) {
      SharedPreferences.setMockInitialValues({
        'tones': [jsonEncode(retired.toJson())],
      });
      final stock = ToneService();
      await stock.init();
      expect(stock.tones.any((t) => t.id == retired.id), isFalse);
      expect(stock.tones.any((t) => t.id == 'Tone0009'), isTrue);
      stock.dispose();

      SharedPreferences.setMockInitialValues({
        'tones': [jsonEncode(retired.copyWith(isFavorite: true).toJson())],
      });
      final favorite = ToneService();
      await favorite.init();
      expect(favorite.tones.any((t) =>
          t.id == retired.id && t.isFavorite), isTrue);
      favorite.dispose();

      SharedPreferences.setMockInitialValues({
        'tones': [jsonEncode(retired.copyWith(
            name: 'カスタム反転模様', tags: ['custom']).toJson())],
      });
      final renamed = ToneService();
      await renamed.init();
      expect(renamed.tones.any((t) =>
          t.id == retired.id && t.name == 'カスタム反転模様'), isTrue);
      renamed.dispose();
    }
  });

  test('Charcoal, gouache, 4B pencil and pastel have real grain settings', () {
    final brushes = {for (final b in BrushService.builtInBrushes) b.id: b};
    final types = <String, int>{
      'Brush0026': 78,
      'Brush0027': 18,
      'Brush0028': 46,
      'Brush0029': 70,
    };
    for (final entry in types.entries) {
      final brush = brushes[entry.key];
      expect(brush, isNotNull, reason: entry.key);
      expect(brush!.grainStrength, entry.value, reason: brush.name);
      expect(brush.pressureOff.edgeJitter.enabled, isTrue);
    }
  });
}
