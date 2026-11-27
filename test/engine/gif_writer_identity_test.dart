import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/gif_palette.dart';
import 'package:niarim/engine/gif_writer.dart';

/// [ExportGifWriter] writes the same bytes as the image package's
/// `GifEncoder` given the palette frames of [GifPaletteMapper]: the encoder
/// the GIF export used before, which read every pixel through `Pixel`
/// objects.
class _ReferenceEncoder extends img.GifEncoder {
  _ReferenceEncoder()
    : super(
        quantizerType: img.QuantizerType.octree,
        dither: img.DitherKernel.none,
      );

  final GifPaletteMapper _palette = GifPaletteMapper();

  @override
  void addFrame(img.Image image, {int? duration}) => super.addFrame(
    image.hasPalette ? image : _palette.paletteFrame(image),
    duration: duration,
  );
}

img.Image _image(
  int w,
  int h,
  int Function(int x, int y, int c) value, {
  int channels = 4,
}) {
  final image = img.Image(width: w, height: h, numChannels: channels);
  final data = (image.data! as img.ImageDataUint8).data;
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < channels; c++) {
        data[i++] = value(x, y, c) & 0xFF;
      }
    }
  }
  return image;
}

img.Image _noise(int w, int h, int seed, {int channels = 4, int levels = 256}) {
  final random = math.Random(seed);
  final step = 256 ~/ levels;
  return _image(
    w,
    h,
    (x, y, c) => random.nextInt(levels) * step,
    channels: channels,
  );
}

img.Image _fewColours(int w, int h, int count, int seed) {
  final random = math.Random(seed);
  final colours = List.generate(count, (_) => random.nextInt(1 << 24));
  final pick = List.generate(w * h, (_) => colours[random.nextInt(count)]);
  return _image(
    w,
    h,
    (x, y, c) => c == 3 ? 255 : pick[y * w + x] >> (16 - 8 * c),
  );
}

img.Image _drawing(int w, int h, int t) => _image(w, h, (x, y, c) {
  if (c == 3) return 255;
  final dx = x - w / 2 - t * 3, dy = y - h / 2;
  final d = math.sqrt(dx * dx + dy * dy);
  final ring = (d - h / 4).abs();
  if (ring < 2) return const [40, 30, 30][c];
  if (ring < 3) return const [120, 110, 110][c];
  if (d < h / 4) return const [250, 200, 170][c];
  if (y < h / 3) return [120 + y * 100 ~/ h, 170 + y * 60 ~/ h, 240][c];
  return const [252, 250, 245][c];
});

img.Image _paletteImage(
  int w,
  int h,
  int colours,
  int channels,
  int seed, {
  int transparentAt = -1,
}) {
  final random = math.Random(seed);
  final palette = img.PaletteUint8(colours, channels);
  final bytes = palette.toUint8List();
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = 1 + random.nextInt(255);
  }
  if (transparentAt >= 0) {
    bytes[transparentAt * channels + channels - 1] = 0;
  }
  final image = img.Image(
    width: w,
    height: h,
    numChannels: 1,
    palette: palette,
  );
  final data = (image.data! as img.ImageDataUint8).data;
  for (var i = 0; i < data.length; i++) {
    data[i] = random.nextInt(colours);
  }
  return image;
}

void _expectSameGif(List<(img.Image, int?)> frames) {
  final reference = _ReferenceEncoder();
  final writer = ExportGifWriter();
  for (final (frame, duration) in frames) {
    reference.addFrame(frame, duration: duration);
    writer.addFrame(frame, duration: duration);
  }
  final expected = reference.finish()!;
  expect(writer.finish(), expected);
  if (frames.every(
    (f) =>
        !f.$1.hasPalette &&
        f.$1.numChannels == 4 &&
        f.$1.format == img.Format.uint8,
  )) {
    final raw = ExportGifWriter();
    for (final (frame, duration) in frames) {
      raw.addRgbaFrame(
        (frame.data! as img.ImageDataUint8).data,
        frame.width,
        frame.height,
        duration: duration,
      );
    }
    expect(raw.finish(), expected);
  }
}

void main() {
  test('no frames gives no file', () {
    expect(ExportGifWriter().finish(), isNull);
  });

  test('single frames of every size and kind of content', () {
    for (final (w, h) in const [(1, 1), (2, 1), (1, 3), (17, 5), (64, 48)]) {
      _expectSameGif([(_noise(w, h, w * 31 + h), null)]);
      _expectSameGif([(_noise(w, h, w + h, channels: 3), 7)]);
      _expectSameGif([(_image(w, h, (x, y, c) => 255), null)]);
      _expectSameGif([(_fewColours(w, h, 5, w), 3)]);
    }
    // At, under and over the 255 colours of a frame's palette.
    for (final n in const [1, 2, 255, 256, 300]) {
      _expectSameGif([(_fewColours(120, 90, n, n), 4)]);
    }
    // Enough distinct codes to fill the LZW table and start it again.
    _expectSameGif([(_noise(400, 300, 9), null)]);
    _expectSameGif([(_noise(400, 300, 9, levels: 16), null)]);
    _expectSameGif([(_drawing(480, 270, 0), null)]);
  });

  test('several frames, their durations and sizes', () {
    _expectSameGif([
      for (var t = 0; t < 5; t++)
        (_drawing(160, 90, t), const [null, 5, 0, 70000, 12][t]),
    ]);
    // Later frames of other sizes keep the first frame's size in their
    // descriptors, as the image package writes them.
    _expectSameGif([
      (_noise(50, 40, 1), 5),
      (_noise(120, 90, 2), 5),
      (_fewColours(10, 10, 3, 1), 5),
    ]);
    _expectSameGif([(_noise(120, 90, 2), null), (_noise(50, 40, 1), null)]);
  });

  test('grey, 16-bit and palette frames', () {
    _expectSameGif([(_noise(40, 30, 5, channels: 1), 3)]);
    _expectSameGif([(_noise(40, 30, 5, channels: 2), 3)]);
    final deep = img.Image(
      width: 30,
      height: 20,
      format: img.Format.uint16,
      numChannels: 4,
    );
    final random = math.Random(4);
    for (final p in deep) {
      p
        ..r = random.nextInt(65536)
        ..g = random.nextInt(65536)
        ..b = random.nextInt(65536)
        ..a = 65535;
    }
    _expectSameGif([(deep, 2)]);
    for (final channels in const [1, 2, 3, 4]) {
      for (final colours in const [1, 16, 256]) {
        _expectSameGif([
          (_paletteImage(60, 40, colours, channels, channels * colours), 6),
        ]);
      }
    }
    _expectSameGif([
      (_noise(60, 40, 1), 4),
      (_paletteImage(60, 40, 20, 4, 3, transparentAt: 7), 4),
      (_paletteImage(60, 40, 30, 2, 3, transparentAt: 0), 4),
      (_fewColours(60, 40, 7, 3), null),
    ]);
  });

  test('a palette frame is read when it is written', () {
    final first = _paletteImage(30, 20, 16, 3, 1);
    final second = _paletteImage(30, 20, 16, 3, 2);
    final reference = _ReferenceEncoder()..addFrame(first);
    final writer = ExportGifWriter()..addFrame(first);
    (first.data! as img.ImageDataUint8).data.fillRange(0, 100, 3);
    reference.addFrame(second);
    writer.addFrame(second);
    expect(writer.finish(), reference.finish());
  });

  test('one writer writes file after file', () {
    final reference = _ReferenceEncoder();
    final writer = ExportGifWriter();
    for (var round = 0; round < 3; round++) {
      for (var f = 0; f <= round; f++) {
        final frame = _noise(40 + round, 30, round * 10 + f);
        reference.addFrame(frame, duration: f);
        writer.addFrame(frame, duration: f);
      }
      expect(writer.finish(), reference.finish(), reason: 'file $round');
    }
  });

  test('palette indices of bytes are those of the palette frame', () {
    final mapper = GifPaletteMapper();
    for (final frame in [
      _drawing(200, 120, 1),
      _noise(80, 60, 3),
      _fewColours(90, 70, 400, 2),
    ]) {
      final image = mapper.paletteFrame(frame);
      final bytes = mapper.paletteIndicesOfBytes(
        (frame.data! as img.ImageDataUint8).data,
        frame.width * frame.height,
        4,
      );
      expect(bytes.indices, (image.data! as img.ImageDataUint8).data);
      expect(bytes.colours, image.palette!.numColors);
      expect(bytes.rgb, Uint8List.fromList(image.palette!.toUint8List()));
    }
  });
}
