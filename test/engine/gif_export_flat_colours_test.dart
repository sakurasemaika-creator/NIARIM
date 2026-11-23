import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';

/// Exported GIFs keep flat areas flat. The default encoder (neural quantizer
/// + Floyd–Steinberg dithering) turned the white paper of a drawn frame into
/// streaks of 252/255 (39% of a 480×360 frame), visible on the work list's
/// GIF covers too.
void main() {
  test('flat paper stays exactly white and colours stay close to the PNG', () {
    const w = 480, h = 360;
    final frame = img.Image(width: w, height: h, numChannels: 4);
    img.fill(frame, color: img.ColorRgba8(255, 255, 255, 255));
    img.fillCircle(
      frame,
      x: 240,
      y: 160,
      radius: 90,
      color: img.ColorRgba8(220, 40, 60, 255),
      antialias: true,
    );
    img.drawLine(
      frame,
      x1: 20,
      y1: 20,
      x2: 460,
      y2: 280,
      color: img.ColorRgba8(20, 20, 20, 255),
      thickness: 6,
      antialias: true,
    );
    // A gradient band, as a shaded drawing has.
    for (var y = 300; y < h; y++) {
      for (var x = 0; x < w; x++) {
        frame.setPixelRgba(x, y, x * 255 ~/ w, 128, 255 - x * 255 ~/ w, 255);
      }
    }
    final encoder = newExportGifEncoder()..addFrame(frame);
    final decoded = img.decodeGif(Uint8List.fromList(encoder.finish()!))!;

    // The paper in the top-right corner, away from the drawing.
    for (var y = 0; y < 40; y++) {
      for (var x = 380; x < 470; x++) {
        final p = decoded.getPixel(x, y);
        expect([p.r, p.g, p.b], [255, 255, 255], reason: 'at $x,$y');
      }
    }
    final red = decoded.getPixel(240, 110);
    expect([red.r, red.g, red.b], [220, 40, 60]);

    var error = 0;
    var samples = 0;
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < w; x += 2) {
        final a = frame.getPixel(x, y);
        final b = decoded.getPixel(x, y);
        error +=
            (a.r - b.r).abs().toInt() +
            (a.g - b.g).abs().toInt() +
            (a.b - b.b).abs().toInt();
        samples++;
      }
    }
    expect(error / samples, lessThan(2.0));
  });
}
