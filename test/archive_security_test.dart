import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/archive_security.dart';

Uint8List _zipWith(ArchiveFile file) {
  final archive = Archive()..addFile(file);
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('通常のZIPを読み込める', () {
    final zip = _zipWith(ArchiveFile('data.json', 2, utf8.encode('{}')));
    final decoded = ArchiveSecurity.decodeZip(zip);
    expect(decoded.findFile('data.json'), isNotNull);
  });

  test('親ディレクトリへ抜けるエントリを拒否する', () {
    final zip = _zipWith(ArchiveFile('Materials/../../outside', 1, [1]));
    expect(() => ArchiveSecurity.decodeZip(zip), throwsFormatException);
  });

  test('展開後サイズが単一ファイル上限を超えるZIPを拒否する', () {
    final oversized = ArchiveFile(
      'payload.bin',
      ArchiveSecurity.maxSingleEntryBytes + 1,
      const <int>[1],
    );
    final zip = _zipWith(oversized);
    expect(() => ArchiveSecurity.decodeZip(zip), throwsFormatException);
  });

  test('展開後サイズを小さく偽装したZIPを拒否する', () {
    final zip = _zipWith(
      ArchiveFile('payload.bin', 1024, List<int>.filled(1024, 0)),
    );
    const centralDirectorySignature = <int>[0x50, 0x4b, 0x01, 0x02];
    var offset = -1;
    for (var i = 0; i <= zip.length - centralDirectorySignature.length; i++) {
      if (zip.sublist(i, i + 4).toString() ==
          centralDirectorySignature.toString()) {
        offset = i;
        break;
      }
    }
    expect(offset, isNonNegative);
    // Central Directory File Headerのuncompressed size（offset + 24）を
    // 実際の1024 bytesより小さい1へ改ざんする。
    ByteData.sublistView(zip).setUint32(offset + 24, 1, Endian.little);
    expect(() => ArchiveSecurity.decodeZip(zip), throwsFormatException);
  });
}
