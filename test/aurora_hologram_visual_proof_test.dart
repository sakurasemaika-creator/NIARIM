import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wide grayscale ramp -> all aurora hologram presets visual proof', () {
    const width = 1024;
    const height = 256;
    final input = Uint8List(width * height * 4);

    // A deliberately broad luminance field: horizontal 0..255 ramp plus
    // stepped bands vertically. This exposes whether the gradient-map really
    // distributes color across dark/mid/bright values instead of tinting a
    // narrow gray range.
    for (var y = 0; y < height; y++) {
      final band = (y ~/ 32) * 8;
      for (var x = 0; x < width; x++) {
        final ramp = ((x / (width - 1)) * 255).round();
        final v = (ramp + band - 28).clamp(0, 255);
        final o = (y * width + x) * 4;
        input[o] = v;
        input[o + 1] = v;
        input[o + 2] = v;
        input[o + 3] = 255;
      }
    }

    final out = Directory('build/aurora-hologram-proof')..createSync(recursive: true);
    _writePng(out, '00_before.png', input, width, height);

    final engine = FilterEngine();
    var index = 1;
    for (final preset in AuroraHologramPreset.values) {
      final result = engine.applyAuroraHologram(
        input,
        width,
        height,
        strength: 100,
        brightness: 0,
        saturation: 0,
        preset: preset,
      );
      expect(result, isNot(equals(input)), reason: preset.name);
      _writePng(
        out,
        '${index.toString().padLeft(2, '0')}_${preset.name}.png',
        result,
        width,
        height,
      );
      index++;
    }
  });
}

void _writePng(
  Directory out,
  String name,
  Uint8List rgba,
  int width,
  int height,
) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    order: img.ChannelOrder.rgba,
  );
  File('${out.path}/$name').writeAsBytesSync(img.encodePng(image));
}
