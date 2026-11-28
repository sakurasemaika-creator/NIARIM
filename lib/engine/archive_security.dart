import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'same_bytes.dart';

/// How large a ZIP may be. Every compressed entry is still inflated once
/// (counted, not kept; an entry stored as the same bytes as an earlier one
/// expands to the same size) to check that it expands to the size it
/// declares, so a forged size cannot get a ZIP bomb or a damaged entry past
/// the check.
class ArchiveLimits {
  const ArchiveLimits._({
    required this.compressedBytes,
    required this.expandedBytes,
    required this.singleEntryBytes,
    required this.metadataEntryBytes,
    required this.entries,
  });

  final int compressedBytes;
  final int expandedBytes;
  final int singleEntryBytes;
  final int metadataEntryBytes;
  final int entries;

  /// An archive received from outside the app (.niashare, .niatra, cards).
  static const received = ArchiveLimits._(
    compressedBytes: 128 * 1024 * 1024,
    expandedBytes: 256 * 1024 * 1024,
    singleEntryBytes: 128 * 1024 * 1024,
    metadataEntryBytes: 16 * 1024 * 1024,
    entries: 20000,
  );

  /// A work file, autosave or save the app itself wrote into its own
  /// storage. Whatever the app can write it must read back: a long or large
  /// work (a 1080×1080 canvas fills 6.25 MiB a layer per frame) passed the
  /// limits for received archives, saved fine and then could not be opened
  /// again, and disappeared from the list. Everything else is checked as
  /// for a received archive (each entry expands to its declared size, so a
  /// damaged work file is still found when the works are listed).
  static const ownWork = ArchiveLimits._(
    compressedBytes: _unbounded,
    expandedBytes: _unbounded,
    singleEntryBytes: _unbounded,
    metadataEntryBytes: _unbounded,
    entries: _unbounded,
  );

  /// A work received from outside (a .niashare, a .niatra and the works in
  /// it). Importing holds the whole work in memory, so how large it may
  /// expand is tied to what this device can hold
  /// ([ArchiveSecurity.receivedWorkBudget], a quarter of its memory), never
  /// less than [received]: a work the size its author could paint and open
  /// on a phone like this one is read, a ZIP bomb expands past it and is
  /// refused with the same messages as before.
  static ArchiveLimits get receivedWork {
    final budget = ArchiveSecurity.receivedWorkBudget();
    int atLeast(int floor) => budget > floor ? budget : floor;
    return ArchiveLimits._(
      compressedBytes: atLeast(received.compressedBytes),
      expandedBytes: atLeast(received.expandedBytes),
      singleEntryBytes: atLeast(received.singleEntryBytes),
      metadataEntryBytes: budget ~/ 8 > received.metadataEntryBytes
          ? budget ~/ 8
          : received.metadataEntryBytes,
      entries: received.entries,
    );
  }

  static const int _unbounded = 1 << 62;
}

/// 外部から受け取る .niashare/.niatra ZIP の共通防御（アプリ自身が書いた作品の
/// ファイルは[ArchiveLimits.ownWork]で、大きさの上限なしに同じ検査をする）。
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

  /// Measures every compressed entry with the Dart inflater only (tests
  /// compare it with the platform zlib pass).
  @visibleForTesting
  static bool debugDartInflateOnly = false;

  /// The largest [receivedWorkBudget].
  static const int maxReceivedWorkBudget = 4 * 1024 * 1024 * 1024;

  /// Replaces [receivedWorkBudget] (tests).
  @visibleForTesting
  static int? debugReceivedWorkBudget;

  static int? _deviceBudget;

  /// How large a received work may expand ([ArchiveLimits.receivedWork]): a
  /// quarter of this device's memory (`MemTotal` in `/proc/meminfo`), between
  /// [maxExpandedBytes] and [maxReceivedWorkBudget]; [maxExpandedBytes] when
  /// the memory cannot be read.
  static int receivedWorkBudget() =>
      debugReceivedWorkBudget ?? (_deviceBudget ??= _budgetFromMemory());

  static int _budgetFromMemory() {
    try {
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        final match = RegExp(r'^MemTotal:\s+(\d+)\s+kB').firstMatch(line);
        if (match == null) continue;
        final quarter = int.parse(match.group(1)!) * 1024 ~/ 4;
        if (quarter < maxExpandedBytes) return maxExpandedBytes;
        if (quarter > maxReceivedWorkBudget) return maxReceivedWorkBudget;
        return quarter;
      }
    } catch (_) {
      // Not readable on this platform: the fixed limit.
    }
    return maxExpandedBytes;
  }

  static Archive decodeZip(
    List<int> bytes, {
    ArchiveLimits limits = ArchiveLimits.received,
  }) {
    if (bytes.length > limits.compressedBytes) {
      throw const FormatException('アーカイブのファイルサイズが上限を超えています');
    }

    ZipDirectory directory;
    try {
      final inputBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      directory = ZipDirectory.read(InputStream(inputBytes));
      _validateDirectory(directory, limits);
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

  /// Reads the ZIP in [file] ([length] bytes) as [decodeZip] reads it, but
  /// only its end record, its central directory and the entries [expand]
  /// takes (by their stored name): the archive returned holds those
  /// entries alone. Every other entry is checked from the central directory
  /// only (its name, flags, kind, declared size and way of storing); its
  /// local header and data are not read, so whether it expands to the size
  /// it declares is left to [decodeZip] over the whole file later.
  ///
  /// Throws as [decodeZip] does for what it checks (anything it refuses,
  /// [decodeZip] refuses too). Returns null when the file is not laid out
  /// the way this reader expects (no end record near the end, a directory
  /// or an entry outside the file, ...): the caller then reads the whole
  /// file with [decodeZip], which decides as before.
  static Archive? decodeZipFileEntries(
    RandomAccessFile file,
    int length, {
    required bool Function(String name) expand,
    ArchiveLimits limits = ArchiveLimits.ownWork,
  }) {
    if (length > limits.compressedBytes) {
      throw const FormatException('アーカイブのファイルサイズが上限を超えています');
    }
    final ZipDirectory directory;
    try {
      final read = _readDirectory(file, length, expand);
      if (read == null) return null;
      directory = read;
    } catch (_) {
      // Anything the reader cannot follow is decided over the whole file.
      return null;
    }
    try {
      _validateDirectory(
        directory,
        limits,
        leftUnexpanded: (header) => header.file == null,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('ZIPアーカイブとして不正です');
    }
    try {
      return _archiveOf(directory);
    } catch (_) {
      throw const FormatException('ZIPアーカイブを展開できません');
    }
  }

  /// The longest stretch from the end of a file searched for the end record
  /// (the record and the longest comment it may carry, with room for a ZIP64
  /// locator before it).
  static const int _endSearch = 22 + 0xffff + 20;

  /// [file]'s end record and central directory as [ZipDirectory.read]
  /// reads them from the whole file, with the local headers of only the
  /// entries [expand] takes (the others keep `file` null). Null when a part
  /// it needs is not where this reader looks.
  static ZipDirectory? _readDirectory(
    RandomAccessFile file,
    int length,
    bool Function(String name) expand,
  ) {
    Uint8List? at(int offset, int count) {
      if (offset < 0 || count < 0 || offset + count > length) return null;
      file.setPositionSync(offset);
      final bytes = file.readSync(count);
      return bytes.length == count ? bytes : null;
    }

    int u16(Uint8List b, int i) => b[i] | b[i + 1] << 8;
    int u32(Uint8List b, int i) => u16(b, i) | u16(b, i + 2) << 16;
    int u64(Uint8List b, int i) => u32(b, i) | u32(b, i + 4) << 32;

    // The end record: searched from the end down, as ZipDirectory does
    // (its first candidate starts five bytes before the end). A record
    // without a comment is in the last few bytes, so a short stretch is read
    // first.
    var tailStart = length;
    var tail = Uint8List(0);
    var end = -1;
    var next = length - 5;
    for (final stretch in const [4096, _endSearch]) {
      final start = length > stretch ? length - stretch : 0;
      if (start >= tailStart) break;
      final read = at(start, length - start);
      if (read == null) return null;
      for (var ip = next; ip >= start; --ip) {
        if (u32(read, ip - start) == ZipDirectory.eocdLocatorSignature) {
          end = ip;
          break;
        }
      }
      tailStart = start;
      tail = read;
      next = start - 1;
      if (end >= 0) break;
    }
    if (end < 0) return null;
    final e = end - tailStart;
    if (e + 22 > tail.length) return null;
    final commentLength = u16(tail, e + 20);
    if (e + 22 + commentLength > tail.length) return null;
    final directory = ZipDirectory()
      ..filePosition = end
      ..numberOfThisDisk = u16(tail, e + 4)
      ..diskWithTheStartOfTheCentralDirectory = u16(tail, e + 6)
      ..totalCentralDirectoryEntriesOnThisDisk = u16(tail, e + 8)
      ..totalCentralDirectoryEntries = u16(tail, e + 10)
      ..centralDirectorySize = u32(tail, e + 12)
      ..centralDirectoryOffset = u32(tail, e + 16);
    if (directory.centralDirectoryOffset == 0xffffffff ||
        directory.centralDirectorySize == 0xffffffff ||
        directory.totalCentralDirectoryEntriesOnThisDisk == 0xffff ||
        directory.numberOfThisDisk == 0xffff) {
      // ZIP64: the sizes are in the ZIP64 end record its locator points to
      // (kept as they are when either is not there, as ZipDirectory does).
      final locator = end - ZipDirectory.zip64EocdLocatorSize;
      final located = locator < 0
          ? null
          : at(locator, ZipDirectory.zip64EocdLocatorSize);
      if (located != null &&
          u32(located, 0) == ZipDirectory.zip64EocdLocatorSignature) {
        final record = at(u64(located, 8), ZipDirectory.zip64EocdSize);
        if (record == null) return null;
        if (u32(record, 0) == ZipDirectory.zip64EocdSignature) {
          directory
            ..numberOfThisDisk = u32(record, 16)
            ..diskWithTheStartOfTheCentralDirectory = u32(record, 20)
            ..totalCentralDirectoryEntriesOnThisDisk = u64(record, 24)
            ..totalCentralDirectoryEntries = u64(record, 32)
            ..centralDirectorySize = u64(record, 40)
            ..centralDirectoryOffset = u64(record, 48);
        }
      } else if (locator >= 0 && located == null) {
        return null;
      }
    }

    final central = at(
      directory.centralDirectoryOffset,
      directory.centralDirectorySize,
    );
    if (central == null) return null;
    final entries = InputStream(central);
    while (!entries.isEOS) {
      if (entries.readUint32() != ZipFileHeader.SIGNATURE) break;
      directory.fileHeaders.add(ZipFileHeader(entries));
    }

    for (final header in directory.fileHeaders) {
      if (!expand(header.filename)) continue;
      final offset = header.localHeaderOffset!;
      final fixed = at(offset, 30);
      if (fixed == null) return null;
      final nameAndExtra = u16(fixed, 26) + u16(fixed, 28);
      // The data, and the descriptor after it when the entry has one.
      final descriptor = (u16(fixed, 6) & 0x08) != 0 ? 16 : 0;
      final size = 30 + nameAndExtra + header.compressedSize!;
      final local =
          at(offset, size + descriptor) ??
          (descriptor == 0 ? null : at(offset, size + 12));
      if (local == null) return null;
      header.file = ZipFile(InputStream(local), header);
    }
    return directory;
  }

  /// The archive [ZipDecoder.decodeBuffer] makes of [directory], of the
  /// entries whose local header was read.
  static Archive _archiveOf(ZipDirectory directory) {
    final archive = Archive();
    for (final header in directory.fileHeaders) {
      final zf = header.file;
      if (zf == null) continue;
      final file = ArchiveFile(
        zf.filename,
        zf.uncompressedSize!,
        zf,
        zf.compressionMethod,
      );
      file.mode = header.externalFileAttributes! >> 16;
      if (header.versionMadeBy >> 8 == 3) {
        final kind = file.mode & 0xF000;
        // Links were refused by the directory check.
        file.isFile = kind == 0x8000 || kind == 0x0000;
      } else {
        file.isFile = !file.name.endsWith('/');
      }
      file.crc32 = zf.crc32;
      file.compress = zf.compressionMethod != ZipFile.zipCompressionStore;
      file.lastModTime = zf.lastModFileDate << 16 | zf.lastModFileTime;
      archive.addFile(file);
    }
    return archive;
  }

  static void validateFileSize(
    int bytes, {
    ArchiveLimits limits = ArchiveLimits.received,
  }) {
    if (bytes > limits.compressedBytes) {
      throw const FormatException('アーカイブのファイルサイズが上限を超えています');
    }
  }

  /// Validates the sizes of an archive produced by this app before encoding.
  /// The writer supplies the uncompressed contents, so there is no need to
  /// decompress them a second time. [limits] are those the archive will be
  /// read with where it is received.
  static void validateExport(
    Archive archive, {
    ArchiveLimits limits = ArchiveLimits.received,
  }) {
    if (archive.files.length > limits.entries) {
      throw const FormatException('アーカイブ内のファイル数が上限を超えています');
    }
    var expandedBytes = 0;
    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/');
      _validateEntryName(name);
      _validateEntrySize(name, file.size, limits);
      expandedBytes += file.size;
      if (expandedBytes > limits.expandedBytes) {
        throw const FormatException('アーカイブの展開後サイズが上限を超えています');
      }
    }
  }

  static void _validateEntrySize(String name, int size, ArchiveLimits limits) {
    if (size < 0 || size > limits.singleEntryBytes) {
      throw const FormatException('アーカイブ内のファイルサイズが上限を超えています');
    }
    if (_isMetadata(name) && size > limits.metadataEntryBytes) {
      throw const FormatException('アーカイブ内のメタデータが大きすぎます');
    }
  }

  /// [leftUnexpanded] entries are checked from the central directory only
  /// (see [decodeZipFileEntries]): their declared size counts towards the
  /// whole, and their local header and data are not looked at.
  static void _validateDirectory(
    ZipDirectory directory,
    ArchiveLimits limits, {
    bool Function(ZipFileHeader header)? leftUnexpanded,
  }) {
    if (directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0 ||
        directory.totalCentralDirectoryEntriesOnThisDisk !=
            directory.totalCentralDirectoryEntries) {
      throw const FormatException('分割ZIPには対応していません');
    }

    final headers = directory.fileHeaders;
    if (headers.length > limits.entries ||
        headers.length != directory.totalCentralDirectoryEntries) {
      throw const FormatException('アーカイブ内のファイル数が上限を超えているか不正です');
    }

    var expandedBytes = 0;
    final names = <String>{};
    final expandedAlike = <(int, int), List<Uint8List>>{};
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
      if (size == null) {
        throw const FormatException('ZIPエントリの展開後サイズが不正です');
      }
      _validateEntrySize(name, size, limits);
      if (leftUnexpanded?.call(header) ?? false) {
        if (header.compressionMethod != ZipFile.zipCompressionStore &&
            header.compressionMethod != ZipFile.zipCompressionDeflate) {
          throw const FormatException('未対応のZIP圧縮方式です');
        }
        expandedBytes += size;
        if (expandedBytes > limits.expandedBytes) {
          throw const FormatException('アーカイブの展開後サイズが上限を超えています');
        }
        continue;
      }
      final file = header.file;
      if (file == null) throw const FormatException('ZIPエントリの実体がありません');
      final actualSize = switch (header.compressionMethod) {
        ZipFile.zipCompressionStore => file.rawContent?.length ?? 0,
        ZipFile.zipCompressionDeflate => _measureDeflated(
          file.rawContent,
          expandedBytes,
          size,
          limits,
          expandedAlike,
        ),
        _ => throw const FormatException('未対応のZIP圧縮方式です'),
      };
      if (actualSize != size) {
        throw const FormatException('ZIPエントリの展開後サイズが申告値と一致しません');
      }
      expandedBytes += actualSize;
      if (expandedBytes > limits.expandedBytes) {
        throw const FormatException('アーカイブの展開後サイズが上限を超えています');
      }
    }
  }

  static const _alikeKept = 4;

  /// [expandedAlike] holds the raw deflate streams (by their length and
  /// declared size) already seen to expand to their declared size: the same
  /// stream expands to the same bytes, so an entry with the same stream
  /// (copied frames keep many identical tiles) is not expanded again.
  static int _measureDeflated(
    InputStreamBase? rawContent,
    int expandedSoFar,
    int declaredSize,
    ArchiveLimits limits,
    Map<(int, int), List<Uint8List>> expandedAlike,
  ) {
    if (rawContent == null) throw const FormatException('ZIPエントリの圧縮データがありません');
    final remainingTotal = limits.expandedBytes - expandedSoFar;
    final limit = remainingTotal < limits.singleEntryBytes
        ? remainingTotal
        : limits.singleEntryBytes;
    // The entry's bytes are later read with the platform zlib
    // (ZipFile.content), which expands a stream the same way. When it expands
    // to exactly the declared size within the limit, the Dart inflater below
    // gives that size too, so its much slower pass is only needed to tell
    // what is wrong with an entry that does not.
    if (!debugDartInflateOnly && declaredSize <= limit) {
      final raw = rawContent.toUint8List();
      final alike = expandedAlike[(raw.length, declaredSize)];
      if (alike != null && alike.any((seen) => sameBytes(seen, raw))) {
        return declaredSize;
      }
      if (_nativeInflatedLength(raw, declaredSize) == declaredSize) {
        // A few per length are enough for copies; more would let a crafted
        // archive of many different streams of one length cost a comparison
        // with every earlier one.
        final seen = expandedAlike[(raw.length, declaredSize)] ??= [];
        if (seen.length < _alikeKept) seen.add(raw);
        return declaredSize;
      }
    }
    // An own work file's entries have no size limit, and a damaged stream
    // can decode without end: past its declared size an entry is already
    // wrong, so the count stops there.
    final pastDeclared = limits.singleEntryBytes >= ArchiveLimits._unbounded;
    final sink = _LimitedOutputStream(pastDeclared ? declaredSize + 1 : limit);
    try {
      Inflate.stream(rawContent, sink);
    } on _PastLimit {
      if (!pastDeclared) rethrow;
      return declaredSize + 1;
    }
    return sink.length;
  }

  /// The length [raw] (a raw deflate stream) expands to with the platform
  /// zlib, or null when it cannot be expanded or expands past [stopAfter]
  /// bytes (the expanded bytes are counted, not kept).
  static int? _nativeInflatedLength(Uint8List raw, int stopAfter) {
    final filter = RawZLibFilter.inflateFilter(raw: true);
    var length = 0;
    try {
      filter.process(raw, 0, raw.length);
      for (final end in const [false, true]) {
        for (
          var chunk = filter.processed(end: end);
          chunk != null;
          chunk = filter.processed(end: end)
        ) {
          length += chunk.length;
          if (length > stopAfter) return null;
        }
      }
    } catch (_) {
      return null;
    }
    return length;
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
    if (count < 0 || length + count > limit) throw const _PastLimit();
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

/// The expanded bytes went past the limit of a [_LimitedOutputStream].
class _PastLimit extends FormatException {
  const _PastLimit() : super('ZIPエントリの実展開サイズが上限を超えています');
}
