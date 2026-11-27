import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/archive_security.dart';

/// Every compressed entry is checked by expanding it. The platform zlib does
/// that pass now (the Dart inflater took about a minute at each start for 200
/// works); the verdict (the entries read, or the message of the refusal) must
/// stay what the Dart inflater alone gives, also for damaged archives.
String _verdict(Uint8List bytes, {required bool dartOnly}) {
  ArchiveSecurity.debugDartInflateOnly = dartOnly;
  try {
    final archive = ArchiveSecurity.decodeZip(bytes);
    return 'read ${[for (final f in archive.files) '${f.name}:${f.size}']}';
  } on FormatException catch (error) {
    return 'refused ${error.message}';
  } finally {
    ArchiveSecurity.debugDartInflateOnly = false;
  }
}

Uint8List _tile(Random random) {
  // A line-art tile: transparent with a few dark strokes (like a canvas tile).
  final tile = Uint8List(64 * 64 * 4);
  for (var line = 0; line < 3; line++) {
    final y = random.nextInt(64);
    for (var x = random.nextInt(32); x < 64; x++) {
      final i = (y * 64 + x) * 4;
      tile[i + 3] = 128 + random.nextInt(128);
    }
  }
  return tile;
}

Uint8List _archive(Random random) {
  final archive = Archive()
    ..addFile(
      ArchiveFile('manifest.json', 2, Uint8List.fromList('{}'.codeUnits)),
    );
  for (var i = 0; i < 6; i++) {
    final data = i.isEven
        ? _tile(random)
        : Uint8List.fromList([
            for (var k = 0; k < 4000 + random.nextInt(4000); k++)
              random.nextInt(256),
          ]);
    archive.addFile(ArchiveFile('Tiles/t$i.bin', data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Where each entry's compressed bytes are in [zip].
List<(int, int)> _entryData(Uint8List zip) {
  final view = ByteData.sublistView(zip);
  return [
    for (final header in ZipDirectory.read(InputStream(zip)).fileHeaders)
      (
        header.localHeaderOffset! +
            30 +
            view.getUint16(header.localHeaderOffset! + 26, Endian.little) +
            view.getUint16(header.localHeaderOffset! + 28, Endian.little),
        header.compressedSize!,
      ),
  ];
}

void main() {
  test('damaged and intact archives get the same verdict as with the Dart '
      'inflater alone', () {
    final random = Random(20261127);
    final verdicts = <String>{};
    for (var sample = 0; sample < 12; sample++) {
      final intact = _archive(random);
      expect(
        _verdict(intact, dartOnly: false),
        _verdict(intact, dartOnly: true),
      );
      final entries = _entryData(intact);
      for (var round = 0; round < 40; round++) {
        final bytes = Uint8List.fromList(intact);
        final (start, length) = entries[1 + random.nextInt(entries.length - 1)];
        switch (round % 4) {
          case 0:
            bytes[start + random.nextInt(length)] ^= 1 << random.nextInt(8);
          case 1:
            for (var k = 0; k < 4; k++) {
              bytes[start + random.nextInt(length)] = random.nextInt(256);
            }
          case 2:
            bytes.fillRange(start + random.nextInt(length), start + length, 0);
          case 3:
            // The declared size in the central directory.
            final directory = ZipDirectory.read(InputStream(intact));
            final header = directory
                .fileHeaders[random.nextInt(directory.fileHeaders.length)];
            var at = directory.centralDirectoryOffset;
            for (final h in directory.fileHeaders) {
              if (identical(h, header)) break;
              final view = ByteData.sublistView(bytes);
              at +=
                  46 +
                  view.getUint16(at + 28, Endian.little) +
                  view.getUint16(at + 30, Endian.little) +
                  view.getUint16(at + 32, Endian.little);
            }
            final view = ByteData.sublistView(bytes);
            final declared = view.getUint32(at + 24, Endian.little);
            view.setUint32(
              at + 24,
              max(0, declared + random.nextInt(7) - 3),
              Endian.little,
            );
        }
        final verdict = _verdict(bytes, dartOnly: false);
        expect(verdict, _verdict(bytes, dartOnly: true));
        verdicts.add(verdict.split(' ').first);
      }
    }
    // The samples reach both kinds of verdict.
    expect(verdicts, containsAll(['read', 'refused']));
  });
}
