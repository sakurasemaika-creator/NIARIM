import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/autofill_engine.dart';
import 'package:niarim/engine/premultiplied.dart';
import 'package:niarim/models/autofill_preset.dart';

const _size = 96;
const _radius = 30.0;

/// A black ring with a soft edge: fully opaque within 1.5 px of the circle,
/// fading to nothing over the next 5 px on both sides.
Uint8List _softRing() {
  final out = Uint8List(_size * _size * 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final r = math.sqrt(
        math.pow(x + 0.5 - 48, 2) + math.pow(y + 0.5 - 48, 2),
      );
      final d = (r - _radius).abs();
      final a = d <= 1.5 ? 255 : (255 * (1 - (d - 1.5) / 5)).round();
      if (a <= 0) continue;
      out[(y * _size + x) * 4 + 3] = a.clamp(0, 255);
    }
  }
  return out;
}

/// The Auto Fill part's 「線画との隙間を埋める」 setting decides how far the
/// fill reaches under the line art's soft edge: the gap between the line and
/// the fill narrows as it goes up (small → medium → large), it is saved and
/// restored, and 50 is the old fixed threshold. The three are also drawn to
/// PNG (line in the fill's colour with an outline, where the gap shows).
void main() {
  final engine = AutofillEngine();
  final line = _softRing();

  /// Soft-edge pixels inside the ring that the fill left empty.
  int gapPixels(Uint8List fill) {
    var gap = 0;
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        final r = math.sqrt(
          math.pow(x + 0.5 - 48, 2) + math.pow(y + 0.5 - 48, 2),
        );
        final i = (y * _size + x) * 4;
        if (r >= _radius || line[i + 3] == 0 || line[i + 3] == 255) continue;
        if (fill[i + 3] == 0) gap++;
      }
    }
    return gap;
  }

  AutofillPart part(double gap, {bool outline = false}) => AutofillPart(
    id: 'p',
    name: 'p',
    color: 0xFFE04040,
    lineColorMode: AutofillLineColorMode.sameAsFill,
    outlineEnabled: outline,
    outlineColor: 0xFF202060,
    outlineWidth: 3,
    lineGapFill: gap,
  );

  test('the gap narrows from small to medium to large', () {
    final gaps = {
      for (final g in [0.0, 50.0, 100.0])
        g: gapPixels(
          engine.repaint(
            lineartData: line,
            width: _size,
            height: _size,
            part: part(g),
          ),
        ),
    };
    expect(gaps[0.0], greaterThan(gaps[50.0]!));
    expect(gaps[50.0], greaterThan(gaps[100.0]!));
    expect(gaps[100.0], 0, reason: 'fills right up to the solid line');
    expect(gaps[0.0], greaterThan(100), reason: 'the whole soft edge');
  });

  test('50 is the old fixed threshold; the setting is saved', () {
    expect(part(50).lineAlphaLimit, 128);
    expect(const AutofillPart(id: 'd', name: 'd', color: 0).lineGapFill, 50);
    final restored = AutofillPart.fromJson(part(73).toJson());
    expect(restored.lineGapFill, 73);
    // Saved before the setting existed: the old behaviour.
    final legacy = part(73).toJson()..remove('lineGapFill');
    expect(AutofillPart.fromJson(legacy).lineGapFill, 50);
  });

  test('small, medium and large drawn with the line in the fill colour', () {
    final dir = Directory('build/autofill-line-gap')
      ..createSync(recursive: true);
    for (final (name, g) in const [
      ('small', 0.0),
      ('medium', 50.0),
      ('large', 100.0),
    ]) {
      final p = part(g, outline: true);
      final fill = engine.repaint(
        lineartData: line,
        width: _size,
        height: _size,
        part: p,
      );
      final lineLayer = engine.recolorLineart(
        lineartData: line,
        width: _size,
        height: _size,
        part: p,
      );
      // White paper, the fill, then the line above it (as the layers are
      // stacked), scaled up 3× to see the edge.
      const scale = 3;
      final image = img.Image(width: _size * scale, height: _size * scale);
      for (var y = 0; y < _size; y++) {
        for (var x = 0; x < _size; x++) {
          final i = (y * _size + x) * 4;
          final rgb = [255, 255, 255];
          for (final layer in [fill, lineLayer]) {
            final a = layer[i + 3];
            for (var c = 0; c < 3; c++) {
              rgb[c] = (layer[i + c] + rgb[c] * (255 - a) / 255).round().clamp(
                0,
                255,
              );
            }
          }
          for (var dy = 0; dy < scale; dy++) {
            for (var dx = 0; dx < scale; dx++) {
              image.setPixelRgb(
                x * scale + dx,
                y * scale + dy,
                rgb[0],
                rgb[1],
                rgb[2],
              );
            }
          }
        }
      }
      File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
      // The line takes the fill colour, premultiplied by its own coverage.
      final edge = (48 * _size + (48 + _radius + 3).round()) * 4;
      expect(lineLayer[edge], premultipliedChannel(0xE0, line[edge + 3]));
    }
  });
}
