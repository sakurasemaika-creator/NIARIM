import 'dart:io';
import 'dart:typed_data';

import 'fast_crc32.dart';

/// A rendered frame as a PNG for a video encoder to read back (the MP4, WebM
/// and AVI exports hand their frames over as PNG files): 8-bit RGBA (colour
/// type 6, as the image package writes it), every row after the first
/// "up"-filtered (the row above subtracted byte by byte, 8 bytes at a time)
/// and compressed by the platform's zlib at level 1. It decodes to exactly
/// [rgba]. The image package's encoder (Paeth in Dart and Dart deflate at
/// level 6) took 0.2 s to over 1 s for a 1920×1080 frame; this takes about
/// 10–60 ms for files 10–30% larger.
Uint8List encodeFramePng(Uint8List rgba, int width, int height) {
  final stride = width * 4;
  assert(rgba.length >= stride * height);
  final chunks = <List<int>>[];
  var compressedLength = 0;
  final sink = ZLibEncoder(level: 1).startChunkedConversion(
    _ChunkSink((chunk) {
      chunks.add(chunk);
      compressedLength += chunk.length;
    }),
  );
  if (height > 0) {
    // The first row has no row above: stored as it is (filter type 0).
    sink.add(const [0]);
    sink.addSlice(rgba, 0, stride, false);
  }
  // The filter type byte sits just before the 8-byte aligned row.
  final row = Uint8List(stride + 8);
  row[7] = 2;
  final words = stride ~/ 8;
  final wordWise = stride % 8 == 0 && rgba.offsetInBytes % 8 == 0;
  final source = wordWise
      ? Uint64List.view(rgba.buffer, rgba.offsetInBytes, words * height)
      : null;
  final target = wordWise ? Uint64List.view(row.buffer, 8, words) : null;
  for (var y = 1; y < height; y++) {
    if (source != null && target != null) {
      final above = (y - 1) * words;
      final here = y * words;
      for (var i = 0; i < words; i++) {
        // Byte-wise a − b (mod 256) in each of the 8 lanes.
        final a = source[here + i];
        final b = source[above + i];
        target[i] = ((a | _high) - (b & _low)) ^ ((a ^ ~b) & _high);
      }
    } else {
      final above = (y - 1) * stride;
      final here = y * stride;
      for (var x = 0; x < stride; x++) {
        row[8 + x] = (rgba[here + x] - rgba[above + x]) & 0xFF;
      }
    }
    sink.addSlice(row, 7, 8 + stride, false);
  }
  sink.close();

  final out = Uint8List(8 + 25 + 12 + compressedLength + 12);
  out.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  var at = 8;
  at = _chunk(out, at, const [0x49, 0x48, 0x44, 0x52], 13, (data) {
    final header = ByteData.sublistView(out, data, data + 13);
    header.setUint32(0, width);
    header.setUint32(4, height);
    out[data + 8] = 8; // bits per channel
    out[data + 9] = 6; // RGBA
    // Compression, filter and interlace methods 0.
  });
  at = _chunk(out, at, const [0x49, 0x44, 0x41, 0x54], compressedLength, (
    data,
  ) {
    var to = data;
    for (final chunk in chunks) {
      out.setAll(to, chunk);
      to += chunk.length;
    }
  });
  _chunk(out, at, const [0x49, 0x45, 0x4E, 0x44], 0, (_) {});
  return out;
}

const int _high = 0x8080808080808080;
const int _low = 0x7F7F7F7F7F7F7F7F;

/// Writes a chunk (length, [type], [length] bytes from [fill], CRC) at [at]
/// and returns where the next one starts.
int _chunk(
  Uint8List out,
  int at,
  List<int> type,
  int length,
  void Function(int dataStart) fill,
) {
  ByteData.sublistView(out, at, at + 4).setUint32(0, length);
  out.setAll(at + 4, type);
  fill(at + 8);
  final crc = crc32Of(Uint8List.sublistView(out, at + 4, at + 8 + length));
  ByteData.sublistView(
    out,
    at + 8 + length,
    at + 12 + length,
  ).setUint32(0, crc);
  return at + 12 + length;
}

class _ChunkSink implements Sink<List<int>> {
  _ChunkSink(this._onChunk);
  final void Function(List<int> chunk) _onChunk;

  @override
  void add(List<int> data) => _onChunk(data);

  @override
  void close() {}
}
