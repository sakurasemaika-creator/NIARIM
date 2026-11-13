import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 決まったファイルだけを、消せない（権限が無い）・書けない（空き容量が
/// 無い）ように見せる[IOOverrides]。テストはrootで動き、chmodでは消せなく
/// ならないので、保存の失敗の扱いはこれで確かめる。
///
/// [IOOverrides.global]へ入れて使い、tearDownでnullに戻す。
final class SaveFileFaults extends IOOverrides {
  /// 消そうとするとPathAccessException（Permission denied）になるファイル。
  final Set<String> undeletable = {};

  /// trueを返すパスへの書き込みはFileSystemException（No space left on
  /// device）になる。
  bool Function(String path)? failWrite;

  void clear() {
    undeletable.clear();
    failWrite = null;
  }

  bool _blocked(String path) =>
      undeletable.contains(path) || (failWrite?.call(path) ?? false);

  @override
  File createFile(String path) {
    final real = super.createFile(path);
    return _blocked(path) ? _FaultyFile(real, this) : real;
  }
}

class _FaultyFile implements File {
  _FaultyFile(this._real, this._faults);

  final File _real;
  final SaveFileFaults _faults;

  bool get _undeletable => _faults.undeletable.contains(_real.path);
  bool get _unwritable => _faults.failWrite?.call(_real.path) ?? false;

  Never _denied() => throw PathAccessException(
    path,
    const OSError('Permission denied', 13),
    'Cannot delete file',
  );

  Never _full() => throw FileSystemException(
    'Cannot write to file',
    path,
    const OSError('No space left on device', 28),
  );

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  bool get isAbsolute => _real.isAbsolute;
  @override
  File get absolute => _real.absolute;
  @override
  Directory get parent => _real.parent;
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<bool> exists() => _real.exists();
  @override
  int lengthSync() => _real.lengthSync();
  @override
  Future<int> length() => _real.length();
  @override
  DateTime lastModifiedSync() => _real.lastModifiedSync();
  @override
  FileStat statSync() => _real.statSync();
  @override
  Future<FileStat> stat() => _real.stat();
  @override
  Uint8List readAsBytesSync() => _real.readAsBytesSync();
  @override
  Future<Uint8List> readAsBytes() => _real.readAsBytes();
  @override
  String readAsStringSync({Encoding encoding = utf8}) =>
      _real.readAsStringSync(encoding: encoding);
  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      _real.readAsString(encoding: encoding);

  @override
  void deleteSync({bool recursive = false}) {
    if (_undeletable) _denied();
    _real.deleteSync(recursive: recursive);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (_undeletable) _denied();
    return _real.delete(recursive: recursive);
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    if (_unwritable) _full();
    _real.writeAsStringSync(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    if (_unwritable) _full();
    return _real.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    if (_unwritable) _full();
    return _real.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    if (_unwritable) _full();
    _real.writeAsBytesSync(bytes, mode: mode, flush: flush);
  }

  @override
  File renameSync(String newPath) => _real.renameSync(newPath);

  @override
  Future<File> rename(String newPath) => _real.rename(newPath);

  @override
  String toString() => _real.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a faulty file');
}
