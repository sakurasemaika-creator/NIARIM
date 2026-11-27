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

/// [copies]: some entries hold the same bytes as an earlier one (copied
/// frames), so they are stored as the same compressed bytes.
Uint8List _archive(Random random, {bool copies = false}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile('manifest.json', 2, Uint8List.fromList('{}'.codeUnits)),
    );
  final written = <Uint8List>[];
  for (var i = 0; i < 6; i++) {
    final data = copies && i >= 2
        ? written[random.nextInt(2)]
        : i.isEven
        ? _tile(random)
        : Uint8List.fromList([
            for (var k = 0; k < 4000 + random.nextInt(4000); k++)
              random.nextInt(256),
          ]);
    written.add(data);
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
  for (final copies in [false, true]) {
    test('damaged and intact archives get the same verdict as with the Dart '
        'inflater alone${copies ? ' (entries copied from others)' : ''}', () {
      expectSameVerdicts(copies: copies);
    });
  }
}

/// Changes by [delta] the size the central directory declares for entry
/// [index] of [bytes].
void _changeDeclaredSize(Uint8List bytes, int index, int delta) {
  final directory = ZipDirectory.read(InputStream(Uint8List.fromList(bytes)));
  final view = ByteData.sublistView(bytes);
  var at = directory.centralDirectoryOffset;
  for (var i = 0; i < index; i++) {
    at +=
        46 +
        view.getUint16(at + 28, Endian.little) +
        view.getUint16(at + 30, Endian.little) +
        view.getUint16(at + 32, Endian.little);
  }
  final declared = view.getUint32(at + 24, Endian.little);
  view.setUint32(at + 24, max(0, declared + delta), Endian.little);
}

void expectSameVerdicts({required bool copies}) {
  final random = Random(20261127);
  final verdicts = <String>{};
  for (var sample = 0; sample < 12; sample++) {
    final intact = _archive(random, copies: copies);
    expect(_verdict(intact, dartOnly: false), _verdict(intact, dartOnly: true));
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
          _changeDeclaredSize(
            bytes,
            random.nextInt(entries.length),
            random.nextInt(7) - 3,
          );
      }
      final verdict = _verdict(bytes, dartOnly: false);
      expect(verdict, _verdict(bytes, dartOnly: true));
      verdicts.add(verdict.split(' ').first);
    }
  }
  // The samples reach both kinds of verdict.
  expect(verdicts, containsAll(['read', 'refused']));
  if (!copies) return;
  // A copy that declares another size than the entry it copies.
  final intact = _archive(random, copies: true);
  for (var index = 3; index <= 6; index++) {
    for (final delta in const [-1, 1]) {
      final bytes = Uint8List.fromList(intact);
      _changeDeclaredSize(bytes, index, delta);
      final verdict = _verdict(bytes, dartOnly: false);
      expect(verdict, startsWith('refused'));
      expect(verdict, _verdict(bytes, dartOnly: true));
    }
  }
}
