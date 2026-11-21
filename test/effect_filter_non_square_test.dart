import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effect filters preserve non-square frame geometry', () {
    const sizes = <(int, int)>[(31, 17), (17, 31)];
    const frames = <int>[0, 5, 10];

    for (final (width, height) in sizes) {
      for (final type in EffectFilterType.values) {
        test('${type.name} survives ${width}x$height frames', () {
          final source = _buildCoordinatePattern(width, height);
          final effect = EffectFilterInstance(
            id: 'non-square-${type.name}',
            type: type,
            startFrame: 0,
            endFrame: 10,
          );
          final engine = FilterEngine();

          for (final frame in frames) {
            late Uint8List output;
            try {
              output = engine.applyEffectFilters(
                Uint8List.fromList(source),
                width,
                height,
                <EffectFilterInstance>[effect],
                frame,
              );
            } catch (error, stackTrace) {
              fail(
                '${type.name} failed for ${width}x$height at frame $frame: '
                '$error\n$stackTrace',
              );
            }

            expect(
              output,
              hasLength(width * height * 4),
              reason:
                  '${type.name} changed RGBA geometry for ${width}x$height '
                  'at frame $frame',
            );
          }
        });
      }
    }
  });
}

Uint8List _buildCoordinatePattern(int width, int height) {
  final data = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      data[index] = (x * 17 + y * 3) & 0xff;
      data[index + 1] = (y * 29 + x * 5) & 0xff;
      data[index + 2] = ((x + y) * 11) & 0xff;
      data[index + 3] = 255;
    }
  }
  return data;
}
