import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Codec for a single fully self-contained NIARIM asset share-card PNG.
///
/// The visually readable PNG is also the transport; no adjacent .nia* file or
/// QR payload is necessary. Source asset bytes are packed in the private PNG
/// ancillary chunk `niAR` and remain intact until an image service re-encodes
/// the PNG. A screenshot of a card is deliberately not an importable card.
class SharedAssetCardCodec {
  SharedAssetCardCodec._();

  static const int version = 1;
  static const int maxPngBytes = 48 * 1024 * 1024;
  static const int maxAssetBytes = 32 * 1024 * 1024;
  static const int maxHeaderBytes = 64 * 1024;
  static const String _chunkName = 'niAR';
  static const List<int> _pngMagic = [137, 80, 78, 71, 13, 10, 26, 10];

  /// Append a private PNG chunk immediately before IEND while preserving all
  /// original display pixels and PNG data chunks byte-for-byte.
  static Uint8List embed({
    required Uint8List png,
    required String kind,
    required String name,
    required Uint8List data,
  }) {
    if (!const {'brush', 'tone', 'stamp'}.contains(kind)) {
      throw const FormatException('Unsupported asset card kind');
    }
    if (data.isEmpty || data.length > maxAssetBytes) {
      throw const FormatException('Invalid source asset payload size');
    }
    final chunks = _scanPng(png);
    if (chunks.any((c) => c.type == _chunkName)) {
      throw const FormatException('PNG already has an asset card payload');
    }
    final iend = chunks.last;
    final header = utf8.encode(jsonEncode({
      'format': 'niarim.asset-card',
      'version': version,
      'kind': kind,
      'name': name,
      'sha256': sha256.convert(data).toString(),
      'length': data.length,
    }));
    if (header.length > maxHeaderBytes) {
      throw const FormatException('Asset card header too large');
    }
    final binary = BytesBuilder(copy: false)
      ..add(_u32(header.length))
      ..add(header)
      ..add(data);
    final chunk = _encodeChunk(_chunkName, binary.takeBytes());
    final result = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(png, 0, iend.offset))
      ..add(chunk)
      ..add(Uint8List.sublistView(png, iend.offset));
    final bytes = result.takeBytes();
    if (bytes.length > maxPngBytes) {
      throw const FormatException('Asset share card exceeds the size limit');
    }
    return bytes;
  }

  static SharedAssetCardPayload extract(Uint8List png) {
    final chunks = _scanPng(png);
    final cards = chunks.where((c) => c.type == _chunkName).toList();
    if (cards.length != 1) {
      throw const FormatException('Not a NIARIM share card PNG');
    }
    final raw = Uint8List.sublistView(png, cards.single.dataStart,
        cards.single.dataStart + cards.single.length);
    if (raw.length < 5) {
      throw const FormatException('Truncated asset card');
    }
    final headerLength = _readU32(raw, 0);
    if (headerLength <= 0 || headerLength > maxHeaderBytes ||
        headerLength > raw.length - 4) {
      throw const FormatException('Invalid card header');
    }
    final decoded = jsonDecode(
      utf8.decode(Uint8List.sublistView(raw, 4, 4 + headerLength)),
    );
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'niarim.asset-card' ||
        decoded['version'] != version ||
        !const {'brush', 'tone', 'stamp'}.contains(decoded['kind']) ||
        decoded['name'] is! String || decoded['sha256'] is! String ||
        decoded['length'] is! int) {
      throw const FormatException('Unsupported or corrupt asset card');
    }
    final data = Uint8List.fromList(raw.sublist(4 + headerLength));
    if (data.length != decoded['length'] || data.isEmpty ||
        data.length > maxAssetBytes ||
        sha256.convert(data).toString() != decoded['sha256']) {
      throw const FormatException('Damaged asset card content');
    }
    return SharedAssetCardPayload(
      kind: decoded['kind'] as String,
      name: decoded['name'] as String,
      data: data,
      digest: decoded['sha256'] as String,
    );
  }

  static List<_PngChunk> _scanPng(Uint8List png) {
    if (png.length < 20 || png.length > maxPngBytes ||
        !_pngMagic.asMap().entries.every((e) => png[e.key] == e.value)) {
      throw const FormatException('Invalid PNG signature or size');
    }
    final chunks = <_PngChunk>[];
    var pos = 8;
    var foundIhdr = false;
    while (pos + 12 <= png.length) {
      final length = _readU32(png, pos);
      final maxLen = png.length - pos - 12;
      if (length > maxLen || length > maxPngBytes) {
        throw const FormatException('Truncated or oversized PNG chunk');
      }
      final type = ascii.decode(png.sublist(pos + 4, pos + 8),
          allowInvalid: false);
      if (!RegExp(r'^[A-Za-z]{4}$').hasMatch(type)) {
        throw const FormatException('Invalid PNG chunk type');
      }
      if (chunks.isEmpty && (type != 'IHDR' || length != 13)) {
        throw const FormatException('PNG IHDR is missing');
      }
      if (type == 'IHDR') foundIhdr = true;
      final crcExpected = _readU32(png, pos + 8 + length);
      // Validate the card chunk itself; ordinary PNG chunks are decoded by
      // Flutter's PNG image codec and may be validated there as needed.
      if (type == _chunkName &&
          _crc32(png, pos + 4, pos + 8 + length) != crcExpected) {
        throw const FormatException('Asset card CRC mismatch');
      }
      chunks.add(_PngChunk(type, pos, pos + 8, length));
      pos += 12 + length;
      if (type == 'IEND') {
        if (length != 0 || pos != png.length || !foundIhdr) {
          throw const FormatException('Invalid PNG IEND');
        }
        return chunks;
      }
    }
    throw const FormatException('Incomplete PNG image');
  }

  static Uint8List _encodeChunk(String type, Uint8List content) {
    final tag = ascii.encode(type);
    final b = BytesBuilder(copy: false)
      ..add(_u32(content.length))
      ..add(tag)
      ..add(content);
    final prefix = b.takeBytes();
    return (BytesBuilder(copy: false)
      ..add(prefix)
      ..add(_u32(_crc32(prefix, 4, prefix.length))))
        .takeBytes();
  }

  static Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);
  static int _readU32(Uint8List b, int off) =>
      ByteData.sublistView(b, off, off + 4).getUint32(0);

  static int _crc32(Uint8List bytes, int start, int end) {
    var crc = 0xffffffff;
    for (var i = start; i < end; i++) {
      crc ^= bytes[i];
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}

class SharedAssetCardPayload {
  final String kind;
  final String name;
  final Uint8List data;
  final String digest;
  const SharedAssetCardPayload({
    required this.kind,
    required this.name,
    required this.data,
    required this.digest,
  });
}

class _PngChunk {
  final String type;
  final int offset;
  final int dataStart;
  final int length;
  const _PngChunk(this.type, this.offset, this.dataStart, this.length);
}