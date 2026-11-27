import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'gif_palette.dart';

/// Writes the exported GIFs byte for byte as the image package's
/// `GifEncoder` (version 4.3.0, with the octree quantizer and no dithering)
/// writes them when every frame is first made a palette image by
/// [GifPaletteMapper]: the same header, loop and frame records, a 256-entry
/// local palette per frame, and the same LZW codes in 254-byte blocks.
///
/// The image package's encoder reads each frame pixel by pixel through
/// `Pixel` objects (one virtual call for each value) and spent most of a
/// GIF export there; this reads the palette indices straight from the bytes
/// [GifPaletteMapper] makes.
class ExportGifWriter {
  ExportGifWriter({this.delay = 80, this.repeat = 0});

  /// Frame delay (1/100 s) for a frame added without a duration.
  final int delay;

  /// Loop count (0: forever).
  final int repeat;

  final GifPaletteMapper _palette = GifPaletteMapper();

  _GifBytes? _out;

  /// The frame written when the next frame is added (or at [finish]): a
  /// palette image given by the caller, read when it is written as the
  /// image package does, or the palette made for another image when it was
  /// added.
  Object? _last;
  int? _lastDuration;
  int _width = 0;
  int _height = 0;
  int _encodedFrames = 0;

  /// Adds [image] (a palette image is used as it is). [duration] is in
  /// 1/100 s. After the last frame, [finish] gives the file.
  void addFrame(img.Image image, {int? duration}) {
    final Object frame;
    if (image.hasPalette) {
      frame = image;
    } else {
      final (:indices, :rgb, :colours, width: _, height: _) = _palette
          .paletteIndices(image);
      frame = _PaletteFrame(indices, rgb, colours);
    }
    _add(frame, image.width, image.height, duration);
  }

  /// [addFrame] of an 8-bit RGBA frame of [width]×[height] pixels, row by
  /// row, without making it an image first.
  void addRgbaFrame(Uint8List rgba, int width, int height, {int? duration}) {
    final (:indices, :rgb, :colours) = _palette.paletteIndicesOfBytes(
      rgba,
      width * height,
      4,
    );
    _add(_PaletteFrame(indices, rgb, colours), width, height, duration);
  }

  void _add(Object frame, int width, int height, int? duration) {
    final out = _out;
    if (out == null) {
      _out = _GifBytes();
      _width = width;
      _height = height;
      _last = frame;
      _lastDuration = duration;
      return;
    }
    if (_encodedFrames == 0) _writeStart(out);
    _writeFrame(out, _frameOf(_last!), _lastDuration);
    _encodedFrames++;
    _last = frame;
    _lastDuration = duration;
  }

  /// The GIF of the frames added, or null when none was.
  Uint8List? finish() {
    final out = _out;
    if (out == null) return null;
    if (_encodedFrames == 0) _writeStart(out);
    _writeFrame(out, _frameOf(_last!), _lastDuration);
    out.byte(0x3B);
    _out = null;
    _last = null;
    _encodedFrames = 0;
    return out.bytes();
  }

  static _PaletteFrame _frameOf(Object frame) => frame is img.Image
      ? _PaletteFrame.fromPaletteImage(frame)
      : frame as _PaletteFrame;

  void _writeStart(_GifBytes out) {
    // Header and logical screen (no global colour table).
    out
      ..bytes7Bit('GIF89a')
      ..uint16(_width)
      ..uint16(_height)
      ..byte(0)
      ..byte(0)
      ..byte(0);
    // NETSCAPE2.0 loop extension.
    out
      ..byte(0x21)
      ..byte(0xFF)
      ..byte(11)
      ..bytes7Bit('NETSCAPE2.0')
      ..byte(0x03)
      ..byte(0x01)
      ..uint16(repeat)
      ..byte(0);
  }

  void _writeFrame(_GifBytes out, _PaletteFrame frame, int? duration) {
    // Graphic control extension: dispose 2 (clear), transparency from the
    // palette.
    out
      ..byte(0x21)
      ..byte(0xF9)
      ..byte(4)
      ..byte((2 << 2) | (frame.transparent ? 1 : 0))
      ..uint16(duration ?? delay)
      ..byte(frame.transparentIndex)
      ..byte(0);
    // Image descriptor at 0,0, the first frame's size, with a 256-entry
    // local colour table.
    out
      ..byte(0x2C)
      ..uint16(0)
      ..uint16(0)
      ..uint16(_width)
      ..uint16(_height)
      ..byte(0x87)
      ..addAll(frame.rgb)
      ..zeros((256 - frame.colours) * 3);
    _encodeLzw(out, frame.indices);
  }

  static const int _eof = -1;
  static const int _bits = 12;
  static const int _hSize = 5003;
  static const List<int> _masks = [
    0x0000,
    0x0001,
    0x0003,
    0x0007,
    0x000F,
    0x001F,
    0x003F,
    0x007F,
    0x00FF,
    0x01FF,
    0x03FF,
    0x07FF,
    0x0FFF,
    0x1FFF,
    0x3FFF,
    0x7FFF,
    0xFFFF,
  ];

  /// The image package's LZW (variable code size from 9 to 12 bits, a
  /// 5003-entry hash table with Knott's secondary probe, a clear code when
  /// the table is full), the same codes in the same order.
  void _encodeLzw(_GifBytes out, Uint8List pixels) {
    const initCodeSize = 8;
    out.byte(initCodeSize);

    final block = Uint8List(256);
    var blockSize = 0;
    var curAccum = 0;
    var curBits = 0;
    const initBits = initCodeSize + 1;
    var nBits = initBits;
    var maxCode = (1 << nBits) - 1;
    const clearCode = 1 << (initBits - 1);
    const eofCode = clearCode + 1;
    var clearFlag = false;
    var freeEnt = clearCode + 2;

    void writeBlock() {
      if (blockSize > 0) {
        out
          ..byte(blockSize)
          ..addRange(block, 0, blockSize);
        blockSize = 0;
      }
    }

    void output(int code) {
      curAccum &= _masks[curBits];
      if (curBits > 0) {
        curAccum |= code << curBits;
      } else {
        curAccum = code;
      }
      curBits += nBits;
      while (curBits >= 8) {
        block[blockSize++] = curAccum & 0xFF;
        if (blockSize >= 254) writeBlock();
        curAccum >>= 8;
        curBits -= 8;
      }
      if (freeEnt > maxCode || clearFlag) {
        if (clearFlag) {
          nBits = initBits;
          maxCode = (1 << nBits) - 1;
          clearFlag = false;
        } else {
          ++nBits;
          maxCode = nBits == _bits ? 1 << _bits : (1 << nBits) - 1;
        }
      }
      if (code == eofCode) {
        while (curBits > 0) {
          block[blockSize++] = curAccum & 0xFF;
          if (blockSize >= 254) writeBlock();
          curAccum >>= 8;
          curBits -= 8;
        }
        writeBlock();
      }
    }

    final hTab = Int32List(_hSize)..fillRange(0, _hSize, -1);
    final codeTab = Int32List(_hSize);
    final count = pixels.length;
    var next = 0;
    var hShift = 0;
    for (var fCode = _hSize; fCode < 65536; fCode *= 2) {
      hShift++;
    }
    hShift = 8 - hShift;

    var ent = count > 0 ? pixels[next++] : _eof;
    output(clearCode);
    var c = next < count ? pixels[next++] : _eof;
    while (c != _eof) {
      final fcode = (c << _bits) + ent;
      var i = (c << hShift) ^ ent;
      if (hTab[i] == fcode) {
        ent = codeTab[i];
        c = next < count ? pixels[next++] : _eof;
        continue;
      }
      if (hTab[i] >= 0) {
        // Secondary hash (after G. Knott).
        var disp = _hSize - i;
        if (i == 0) disp = 1;
        var found = false;
        do {
          if ((i -= disp) < 0) i += _hSize;
          if (hTab[i] == fcode) {
            ent = codeTab[i];
            found = true;
            break;
          }
        } while (hTab[i] >= 0);
        if (found) {
          c = next < count ? pixels[next++] : _eof;
          continue;
        }
      }
      output(ent);
      ent = c;
      if (freeEnt < (1 << _bits)) {
        codeTab[i] = freeEnt++;
        hTab[i] = fcode;
      } else {
        hTab.fillRange(0, _hSize, -1);
        freeEnt = clearCode + 2;
        clearFlag = true;
        output(clearCode);
      }
      c = next < count ? pixels[next++] : _eof;
    }
    output(ent);
    output(eofCode);
    out.byte(0);
  }
}

/// A frame's palette indices (every pixel of the frame, row by row) and its
/// local palette as written.
class _PaletteFrame {
  _PaletteFrame(
    this.indices,
    this.rgb,
    this.colours, {
    this.transparent = false,
    this.transparentIndex = 0,
  });

  /// A palette image given by the caller, read as the image package reads
  /// it: the first palette entry with alpha 0 is the transparent colour,
  /// grey palettes are written as grey RGB.
  factory _PaletteFrame.fromPaletteImage(img.Image image) {
    final palette = image.palette!;
    final colours = palette.numColors;
    final channels = palette.numChannels;
    final bytes = palette.toUint8List();
    // A three-channel palette is written as its bytes, the others one RGB
    // entry per colour.
    final rgb = channels == 3
        ? Uint8List.fromList(bytes)
        : Uint8List(colours * 3);
    var transparent = false;
    var transparentIndex = 0;
    if (channels == 4 || channels == 2) {
      for (var i = 0, pi = channels - 1; i < colours; ++i, pi += channels) {
        if (bytes[pi] == 0) {
          transparent = true;
          transparentIndex = i;
          break;
        }
      }
    }
    if (channels == 4) {
      for (var i = 0, pi = 0; i < colours; ++i, pi += 4) {
        rgb[i * 3] = bytes[pi];
        rgb[i * 3 + 1] = bytes[pi + 1];
        rgb[i * 3 + 2] = bytes[pi + 2];
      }
    } else if (channels == 1 || channels == 2) {
      for (var i = 0, pi = 0; i < colours; ++i, pi += channels) {
        rgb[i * 3] = rgb[i * 3 + 1] = rgb[i * 3 + 2] = bytes[pi];
      }
    }
    final data = image.data;
    final Uint8List indices;
    if (data is img.ImageDataUint8 && data.numChannels == 1) {
      indices = Uint8List.fromList(data.data);
    } else {
      indices = Uint8List(image.width * image.height);
      var at = 0;
      for (final pixel in image) {
        indices[at++] = pixel.index as int;
      }
    }
    return _PaletteFrame(
      indices,
      rgb,
      colours,
      transparent: transparent,
      transparentIndex: transparentIndex,
    );
  }

  final Uint8List indices;

  /// The palette bytes written before the padding to 256 entries.
  final Uint8List rgb;
  final int colours;
  final bool transparent;
  final int transparentIndex;
}

/// A growing byte buffer.
class _GifBytes {
  Uint8List _data = Uint8List(1 << 16);
  int _length = 0;

  void _room(int more) {
    if (_length + more <= _data.length) return;
    var size = _data.length * 2;
    while (size < _length + more) {
      size *= 2;
    }
    _data = Uint8List(size)..setRange(0, _length, _data);
  }

  void byte(int value) {
    _room(1);
    _data[_length++] = value & 0xFF;
  }

  void uint16(int value) {
    _room(2);
    _data[_length++] = value & 0xFF;
    _data[_length++] = (value >> 8) & 0xFF;
  }

  void bytes7Bit(String text) {
    _room(text.length);
    for (var i = 0; i < text.length; i++) {
      _data[_length++] = text.codeUnitAt(i);
    }
  }

  void addAll(Uint8List bytes) => addRange(bytes, 0, bytes.length);

  void addRange(Uint8List bytes, int start, int end) {
    _room(end - start);
    _data.setRange(_length, _length + end - start, bytes, start);
    _length += end - start;
  }

  void zeros(int count) {
    if (count <= 0) return;
    _room(count);
    _data.fillRange(_length, _length + count, 0);
    _length += count;
  }

  Uint8List bytes() => Uint8List.sublistView(_data, 0, _length);
}
