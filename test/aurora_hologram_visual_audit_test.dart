import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/aurora-hologram');

  setUpAll(() => out.createSync(recursive: true));

  testWidgets('wide grayscale ramp -> all aurora hologram presets -> PNG', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const width = 1024;
    const height = 320;
    final source = _buildWideGrayRamp(width, height);
    final engine = FilterEngine();

    final images = <String, ui.Image>{};
    images['00_input_grayscale'] = await _imageFromRgba(source, width, height);

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
      images['preset_${preset.name}'] = await _imageFromRgba(result, width, height);
    }

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: RepaintBoundary(
            key: key,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'NIARIM Aurora Hologram Visual Audit',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 16),
                    for (final entry in images.entries) ...[
                      Text(entry.key, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 6),
                      RawImage(image: entry.value, fit: BoxFit.fitWidth),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in images.entries) {
      final bytes = await entry.value.toByteData(format: ui.ImageByteFormat.png);
      await File('${out.path}/${entry.key}.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final sheet = await boundary.toImage(pixelRatio: 1);
    final sheetBytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
    await File('${out.path}/contact_sheet.png').writeAsBytes(sheetBytes!.buffer.asUint8List());
  });
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
