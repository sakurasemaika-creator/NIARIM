import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 外部から受け取る .niashare/.niatra ZIP の共通防御。
///
/// archive 3.x はエントリを遅延展開するため、展開前に中央ディレクトリを
/// 検査すれば、圧縮爆弾・暗号化ZIP・シンボリックリンク・パストラバーサルを
/// アプリのモデルへ渡す前に拒否できる。
class ArchiveSecurity {
  static const int maxCompressedBytes = 128 * 1024 * 1024;
  static const int maxExpandedBytes = 256 * 1024 * 1024;
  static const int maxSingleEntryBytes = 128 * 1024 * 1024;
  static const int maxMetadataEntryBytes = 16 * 1024 * 1024;
  static const int maxEntries = 20000;
  static const int maxEntryNameChars = 512;

  static Archive decodeZip(List<int> bytes) {
    if (bytes.length > maxCompressedBytes) {
      throw const FormatException('アーカイブのファイルサイズが上限を超えています');
    }

    ZipDirectory directory;
    try {
      final inputBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      directory = ZipDirectory.read(InputStream(inputBytes));
      _validateDirectory(directory);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('ZIPアーカイブとして不正です');
    }

    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('ZIPアーカイブを展開できません');
    }
  }

  static void validateFileSize(int bytes) {
    if (bytes > maxCompressedBytes) {
      throw const FormatException('アーカイブのファイルサイズが上限を超えています');
    }
  }

  static void _validateDirectory(ZipDirectory directory) {
    if (directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0 ||
        directory.totalCentralDirectoryEntriesOnThisDisk !=
            directory.totalCentralDirectoryEntries) {
      throw const FormatException('分割ZIPには対応していません');
    }

    final headers = directory.fileHeaders;
    if (headers.length > maxEntries ||
        headers.length != directory.totalCentralDirectoryEntries) {
      throw const FormatException('アーカイブ内のファイル数が上限を超えているか不正です');
    }

    var expandedBytes = 0;
    final names = <String>{};
    for (final header in headers) {
      final name = header.filename.replaceAll('\\', '/');
      _validateEntryName(name);
      if (!names.add(name)) {
        throw const FormatException('アーカイブ内に同名のファイルが重複しています');
      }

      // bit 0 は従来暗号化、bit 6 はstrong encryption。パスワード入力UIを
      // 持たないため、曖昧に処理せず拒否する。
      if ((header.generalPurposeBitFlag & 0x1) != 0 ||
          (header.generalPurposeBitFlag & 0x40) != 0) {
        throw const FormatException('暗号化ZIPには対応していません');
      }

      final mode = (header.externalFileAttributes ?? 0) >> 16;
      if ((mode & 0xF000) == 0xA000) {
        throw const FormatException('シンボリックリンクを含むZIPは読み込めません');
      }

      final size = header.uncompressedSize;
      if (size == null || size < 0 || size > maxSingleEntryBytes) {
        throw const FormatException('アーカイブ内のファイルサイズが上限を超えています');
      }
      if (_isMetadata(name) && size > maxMetadataEntryBytes) {
        throw const FormatException('アーカイブ内のメタデータが大きすぎます');
      }
      final file = header.file;
      if (file == null) throw const FormatException('ZIPエントリの実体がありません');
      final actualSize = switch (header.compressionMethod) {
        ZipFile.zipCompressionStore => file.rawContent?.length ?? 0,
        ZipFile.zipCompressionDeflate => _measureDeflated(
          file.rawContent,
          expandedBytes,
        ),
        _ => throw const FormatException('未対応のZIP圧縮方式です'),
      };
      if (actualSize != size) {
        throw const FormatException('ZIPエントリの展開後サイズが申告値と一致しません');
      }
      expandedBytes += actualSize;
      if (expandedBytes > maxExpandedBytes) {
        throw const FormatException('アーカイブの展開後サイズが上限を超えています');
      }
    }
  }

  static int _measureDeflated(InputStreamBase? rawContent, int expandedSoFar) {
    if (rawContent == null) throw const FormatException('ZIPエントリの圧縮データがありません');
    final remainingTotal = maxExpandedBytes - expandedSoFar;
    final sink = _LimitedOutputStream(
      remainingTotal < maxSingleEntryBytes
          ? remainingTotal
          : maxSingleEntryBytes,
    );
    Inflate.stream(rawContent, sink);
    return sink.length;
  }

  static void _validateEntryName(String name) {
    if (name.isEmpty ||
        name.length > maxEntryNameChars ||
        name.contains('\u0000') ||
        name.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(name)) {
      throw const FormatException('アーカイブ内に不正なファイル名があります');
    }
    final segments = name.split('/');
    if (segments.any((segment) => segment == '.' || segment == '..')) {
      throw const FormatException('アーカイブ内に危険な相対パスがあります');
    }
  }

  static bool _isMetadata(String name) =>
      name == 'manifest.json' ||
      name == 'data.json' ||
      name.endsWith('/frames.json') ||
      name.endsWith('/materials.json') ||
      name.endsWith('/fonts.json');
}

/// 展開結果をメモリへ保持せず、書き込まれた実バイト数だけを数える。
/// 上限を越えた時点で例外にするため、偽のuncompressedSizeを持つZIP爆弾にも
/// 巨大バッファを割り当てず対処できる。
class _LimitedOutputStream implements OutputStreamBase {
  static const int _windowSize = 32768;
  final int limit;
  final Uint8List _window = Uint8List(_windowSize);
  int _writeIndex = 0;
  int _windowLength = 0;
  @override
  int length = 0;

  _LimitedOutputStream(this.limit);

  void _reserve(int count) {
    if (count < 0 || length + count > limit) {
      throw const FormatException('ZIPエントリの実展開サイズが上限を超えています');
    }
    length += count;
  }

  void _appendByte(int value) {
    _window[_writeIndex] = value & 0xff;
    _writeIndex = (_writeIndex + 1) % _windowSize;
    if (_windowLength < _windowSize) _windowLength++;
  }

  @override
  void flush() {}

  @override
  void writeByte(int value) {
    _reserve(1);
    _appendByte(value);
  }

  @override
  void writeBytes(List<int> bytes, [int? len]) {
    final count = len ?? bytes.length;
    if (count > bytes.length) throw const FormatException('ZIP展開データが不正です');
    _reserve(count);
    for (var i = 0; i < count; i++) {
      _appendByte(bytes[i]);
    }
  }

  @override
  void writeInputStream(InputStreamBase stream) =>
      writeBytes(stream.toUint8List());

  @override
  void writeUint16(int value) => writeBytes([value, value >> 8]);

  @override
  void writeUint32(int value) =>
      writeBytes([value, value >> 8, value >> 16, value >> 24]);

  @override
  void writeUint64(int value) => writeBytes([
    value,
    value >> 8,
    value >> 16,
    value >> 24,
    value >> 32,
    value >> 40,
    value >> 48,
    value >> 56,
  ]);

  /// package:archiveのDeflate実装がLZ77の後方参照に使う直近32 KiBを返す。
  List<int> subset(int start, [int? end]) {
    final absoluteStart = start < 0 ? length + start : start;
    final absoluteEnd = end == null
        ? length
        : end < 0
        ? length + end
        : end;
    final oldest = length - _windowLength;
    if (absoluteStart < oldest ||
        absoluteStart < 0 ||
        absoluteEnd < absoluteStart ||
        absoluteEnd > length) {
      throw const FormatException('ZIPの後方参照が不正です');
    }

    final result = Uint8List(absoluteEnd - absoluteStart);
    final oldestIndex = (_writeIndex - _windowLength) % _windowSize;
    for (var i = 0; i < result.length; i++) {
      final offsetFromOldest = absoluteStart - oldest + i;
      result[i] = _window[(oldestIndex + offsetFromOldest) % _windowSize];
    }
    return result;
  }
}
