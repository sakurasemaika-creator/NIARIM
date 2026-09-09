import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/aurora-hologram');

  setUpAll(() => out.createSync(recursive: true));

  test('aurora hologram palette identities remain distinct', () {
    final signatures = <String>{};
    for (final preset in AuroraHologramPreset.values) {
      final signature = auroraHologramStops(preset).join('|');
      expect(
        signatures.add(signature),
        isTrue,
        reason: '${preset.name} must not collapse into another preset palette',
      );
    }
    expect(signatures, hasLength(AuroraHologramPreset.values.length));
  });

  test('wide grayscale ramp -> all aurora hologram presets -> PNG', () async {
    const width = 1024;
    const height = 320;
    final source = _buildWideGrayRamp(width, height);
    final engine = FilterEngine();

    await _writeRgbaPng(
      source,
      width,
      height,
      File('${out.path}/00_input_grayscale.png'),
    );

    for (final preset in AuroraHologramPreset.values) {
      final result = engine.applyAuroraHologram(
        source,
        width,
        height,
        strength: 100,
        brightness: 0,
        saturation: 0,
        preset: preset,
      );
      await _writeRgbaPng(
        result,
        width,
        height,
        File('${out.path}/preset_${preset.name}.png'),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Uint8List _buildWideGrayRamp(int width, int height) {
  final data = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final base = (x / (width - 1) * 255).round();
      final band = ((y / (height - 1)) * 48 - 24).round();
      final shade = (base + band).clamp(0, 255);
      final i = (y * width + x) * 4;
      data[i] = shade;
      data[i + 1] = shade;
      data[i + 2] = shade;
      data[i + 3] = 255;
    }
  }
  return data;
}

Future<void> _writeRgbaPng(
  Uint8List rgba,
  int width,
  int height,
  File file,
) async {
  final image = await _imageFromRgba(rgba, width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encoding returned null');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
