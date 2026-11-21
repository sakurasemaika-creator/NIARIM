import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ゴミ箱の自動削除を選んでいるとき、書き出した作品・作った共有ファイルの
/// ゴミ箱（`niarim/trash/files`）を読めなくても（書類のフォルダが使えない・
/// ゴミ箱のフォルダを一覧できない）、起動を止めない。読めなかったことは
/// エラーの記録に残し、読めない控えは消さない。
///
/// 以前は起動の「project」の段で呼ぶ`LocalFileTrashService.sweepExpired`が、
/// 一覧（`list()`）の例外をそのまま投げ、起動失敗の画面になった（「もう一度
/// 試す」でも同じ所で止まる）。作品のゴミ箱の片付け
/// （`ProjectService.sweepExpiredTrash`）は保存先を読めなければ何もしない。
final class _UnlistableTrash extends IOOverrides {
  _UnlistableTrash(this.trashPath);

  final String trashPath;
  bool blocked = true;

  @override
  Directory createDirectory(String path) {
    final real = super.createDirectory(path);
    return blocked && path == trashPath ? _UnlistableDirectory(real) : real;
  }
}

class _UnlistableDirectory implements Directory {
  _UnlistableDirectory(this._real);

  final Directory _real;

  @override
  String get path => _real.path;
  @override
  Uri get uri => _real.uri;
  @override
  Directory get absolute => _real.absolute;
  @override
  Future<bool> exists() => _real.exists();
  @override
  bool existsSync() => _real.existsSync();
  @override
  Future<Directory> create({bool recursive = false}) =>
      _real.create(recursive: recursive);

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.error(
    PathAccessException(
      _real.path,
      const OSError('Permission denied', 13),
      'Directory listing failed',
    ),
  );

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => throw PathAccessException(
    _real.path,
    const OSError('Permission denied', 13),
    'Directory listing failed',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on the Trash folder');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late bool failDocuments;
  final created = <ChangeNotifier>[];

  String trashPath() => '${directory.path}/niarim/trash/files';

  setUp(() {
    directory = Directory.systemTemp.createTempSync('niarim_trash_sweep_');
    failDocuments = false;
    AppErrorReporter.recentErrors.clear();
    SharedPreferences.setMockInitialValues({
      'language': 'ja',
      'first_launch': false,
      'trash_auto_delete': 30,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          if (failDocuments &&
              call.method == 'getApplicationDocumentsDirectory') {
            return null;
          }
          return directory.path;
        });
  });

  tearDown(() {
    IOOverrides.global = null;
    for (final service in created.reversed) {
      service.dispose();
    }
    created.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  /// ゴミ箱に、[daysAgo]日前に移した書き出した作品の控えを作る。
  Directory trashedClip(String id, int daysAgo) {
    final folder = Directory('${trashPath()}/$id')..createSync(recursive: true);
    File('${folder.path}/data').writeAsBytesSync([1, 2, 3]);
    File('${folder.path}/meta.json').writeAsStringSync(
      jsonEncode({
        'id': id,
        'kind': 'exportedWork',
        'originalPath': '${directory.path}/niarim/exports/$id.mp4',
        'deletedAt': DateTime.now()
            .subtract(Duration(days: daysAgo))
            .toIso8601String(),
      }),
    );
    return folder;
  }

  Future<List<Object>> start() async {
    try {
      await buildAppProviders(debugOnCreated: created.add);
      return const [];
    } on AppStartupException catch (error) {
      // The services made so far were already disposed by the start-up.
      created.clear();
      debugPrint('startup failed: $error');
      return [error];
    }
  }

  bool recordedFromTrash(String message) => AppErrorReporter.recentErrors.any(
    (entry) =>
        entry.contains(message) &&
        entry.contains('local_file_trash_service.dart'),
  );

  test('start-up goes on when the documents folder is unavailable and the '
      'Trash auto-delete is on', () async {
    failDocuments = true;
    final failures = await start();
    expect(failures, isEmpty, reason: 'start-up stopped');
    expect(created.whereType<ProjectService>(), hasLength(1));
    expect(
      recordedFromTrash('MissingPlatformDirectoryException'),
      isTrue,
      reason: 'the Trash that could not be read was not recorded',
    );
  });

  test('start-up goes on when the Trash folder cannot be listed, and keeps '
      'the expired item it could not read', () async {
    final expired = trashedClip('1700000000000001', 60);
    final probe = _UnlistableTrash(trashPath());
    IOOverrides.global = probe;
    final failures = await start();
    expect(failures, isEmpty, reason: 'start-up stopped');
    expect(created.whereType<ProjectService>(), hasLength(1));
    expect(recordedFromTrash('Directory listing failed'), isTrue);
    expect(expired.existsSync(), isTrue);

    // Once it can be read, the next sweep removes the expired item.
    probe.blocked = false;
    await LocalFileTrashService.sweepExpired(30);
    expect(expired.existsSync(), isFalse);
  });

  test('a readable Trash is still swept at start-up', () async {
    final expired = trashedClip('1700000000000002', 45);
    final recent = trashedClip('1700000000000003', 3);
    final failures = await start();
    expect(failures, isEmpty);
    expect(expired.existsSync(), isFalse, reason: 'the expired item stayed');
    expect(recent.existsSync(), isTrue);
    expect((await LocalFileTrashService.list()).map((e) => e.id), [
      '1700000000000003',
    ]);
  });
}
