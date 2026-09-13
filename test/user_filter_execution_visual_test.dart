import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/prism_filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/user-filter-execution');

  setUpAll(() => out.createSync(recursive: true));

  test(
    'execute uploaded images through requested production filters',
    () async {
      final auroraInput = await _loadJpeg('test/fixtures/user_filter_execution/aurora_input.jpg');
      final lineInput = await _loadJpeg('test/fixtures/user_filter_execution/lineart_input.jpg');
      final prismInput = await _loadJpeg('test/fixtures/user_filter_execution/prism_input.jpg');

      for (final preset in AuroraHologramPreset.values) {
        final filter = FilterDef(
          id: 'user-aurora-${preset.name}',
          name: 'オーロラホログラム ${preset.name}',
          kind: FilterKind.auroraHologram,
          strength: 60,
          hologramPreset: preset,
        );
        final result = applyDrawFilterInIsolate((
          auroraInput.rgba,
          auroraInput.width,
          auroraInput.height,
          filter,
          null,
        ));
        expect(result, isNot(equals(auroraInput.rgba)), reason: preset.name);
        await _writePng(
          result,
          auroraInput.width,
          auroraInput.height,
          File('${out.path}/aurora_${preset.name}.png'),
        );
      }

      final analogExtraction = applyDrawFilterInIsolate((
        lineInput.rgba,
        lineInput.width,
        lineInput.height,
        const FilterDef(
          id: 'user-analog-line-extraction',
          name: 'アナログ線画抽出',
          kind: FilterKind.autoLineart,
          autoLineartRoughWidth: 12,
          autoLineartOutputWidth: 2,
          autoLineartTaperLength: 8,
          autoLineartSmoothing: 5,
          autoLineartColor: 0xFF000000,
        ),
        null,
      ));
      await _writePng(
        analogExtraction,
        lineInput.width,
        lineInput.height,
        File('${out.path}/analog_line_extraction.png'),
      );

      final digitalLine = applyDrawFilterInIsolate((
        analogExtraction,
        lineInput.width,
        lineInput.height,
        const FilterDef(
          id: 'user-digital-line-creation',
          name: 'デジタル線画作成',
          kind: FilterKind.outline,
          outlineColor: 0xFF000000,
          outlineWidth: 6,
        ),
        null,
      ));
      await _writePng(
        digitalLine,
        lineInput.width,
        lineInput.height,
        File('${out.path}/digital_line_creation_after_analog.png'),
      );

      final prism = PrismFilterEngine().apply(
        prismInput.rgba,
        prismInput.width,
        prismInput.height,
        blurPx: PrismFilterEngine.defaultBlurPx,
        gradientDirectionDegrees: PrismFilterEngine.defaultDirectionDegrees,
      );
      expect(prism, isNot(equals(prismInput.rgba)));
      await _writePng(
        prism,
        prismInput.width,
        prismInput.height,
        File('${out.path}/prism.png'),
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<({Uint8List rgba, int width, int height})> _loadJpeg(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('raw RGBA decode failed: $path');
      return (
        rgba: Uint8List.fromList(data.buffer.asUint8List()),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<void> _writePng(
  Uint8List rgba,
  int width,
  int height,
  File file,
) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encode failed: ${file.path}');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}
