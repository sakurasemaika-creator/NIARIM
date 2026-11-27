import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/tone.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes `assets/tones/<id>.png` for every built-in tone whose image no
/// longer matches the pattern its name makes (and for new built-ins that
/// have no image yet). Images that already match are left untouched.
///
/// Run with:
/// flutter test tool/build_builtin_tone_images_test.dart
///
/// The image is the ink coverage as the alpha of black (grey + alpha PNG),
/// which is exactly what the app reads back from a tone image.
/// `test/tone_seamless_tiling_test.dart` checks that image and name agree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build built-in tone images', () async {
    // A fresh install's built-ins (this file runs under flutter test).
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final service = ToneService();
    await service.init();
    final written = <String>[];
    for (final tone in service.tones) {
      final path = tone.texturePath;
      if (path == null || !path.startsWith('assets/tones/')) continue;
      // The 20 denier stocking image is antialiased by hand.
      if (tone.id == 'Tone0011') continue;
      final size = toneTileSize(tone);
      final pattern = generateBuiltInToneTexture(
        Tone(id: tone.id, name: tone.name),
        size: size,
      );
      final file = File(path);
      if (file.existsSync() && _same(file.readAsBytesSync(), pattern, size)) {
        continue;
      }
      // Grey 0 (black) and the coverage as alpha.
      final greyAlpha = Uint8List(size * size * 2);
      for (var p = 0; p < size * size; p++) {
        greyAlpha[p * 2 + 1] = pattern[p * 4 + 3];
      }
      final image = img.Image.fromBytes(
        width: size,
        height: size,
        bytes: greyAlpha.buffer,
        numChannels: 2,
      );
      file.writeAsBytesSync(img.encodePng(image, level: 9));
      written.add('${tone.id} ${tone.name} ${size}px');
    }
    service.dispose();
    // ignore: avoid_print
    print(written.isEmpty ? 'all images match' : written.join('\n'));
  });
}

bool _same(Uint8List png, Uint8List pattern, int size) {
  final image = img.decodePng(png);
  if (image == null || image.width != size || image.height != size) {
    return false;
  }
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final p = image.getPixel(x, y);
      final luminance = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
      final ink = ((255 - luminance) * p.a / 255).round();
      if (ink != pattern[(y * size + x) * 4 + 3]) return false;
    }
  }
  return true;
}
