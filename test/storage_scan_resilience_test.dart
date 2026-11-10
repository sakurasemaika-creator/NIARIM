import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 容量の集計は、1か所が読めなくても残りを返す。直近の結果を覚え、
/// 同じ条件の集計が重なったら1回の走査を分け合う。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;
  var failCacheLookup = false;
  var failDocumentsLookup = false;
  var cacheLookups = 0;

  void write(String path, int bytes) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(bytes, 1));
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-resilience-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    failCacheLookup = false;
    failDocumentsLookup = false;
    cacheLookups = 0;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getApplicationCacheDirectory':
          cacheLookups++;
          if (failCacheLookup) {
            throw PlatformException(code: 'unavailable', message: 'no cache');
          }
          return cache.path;
        case 'getApplicationDocumentsDirectory':
          if (failDocumentsLookup) {
            throw PlatformException(code: 'unavailable', message: 'no docs');
          }
          return docs.path;
        default:
          throw StateError('Unexpected path request: ${call.method}');
      }
    });
    write('${docs.path}/niarim/projects/p/p.niapro', 11);
    write('${docs.path}/niarim/projects/p/Materials/a.png', 17);
    write('${cache.path}/thumb.bin', 123);
    StorageInfoService().invalidate();
    AppErrorReporter.recentErrors.clear();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  /// [faults]に挙げたフォルダだけ、一覧の中身を差し替えて集計する
  /// （テストはrootで動くので、権限を外しても読めてしまう）。
  Future<StorageBreakdown> scanWith(
    Map<String, Stream<FileSystemEntity> Function()> faults,
  ) {
    final outside = Zone.current;
    return IOOverrides.runZoned(
      () => StorageInfoService().computeBreakdown({}),
      createDirectory: (path) {
        final real = outside.run(() => Directory(path));
        final entries = faults[path];
        return entries == null ? real : _ScriptedDirectory(real, entries);
      },
    );
  }

  group('読めない所があっても残りを返す', () {
    test('キャッシュの場所が取れなくても、ほかの分類は集計される', () async {
      failCacheLookup = true;
      final b = await StorageInfoService().computeBreakdown({});
      expect(b.bytesOf(StorageCategory.projectData), 11);
      expect(b.bytesOf(StorageCategory.materials), 17);
      expect(b.bytesOf(StorageCategory.cache), 0);
      expect(b.incomplete, {StorageCategory.cache});
      expect(b.isUnreadable, isFalse);
      // 原因は1件だけ記録される。
      expect(
        AppErrorReporter.recentErrors.where((e) => e.contains('no cache')),
        hasLength(1),
      );
    });

    test('書類の場所が取れなくても、キャッシュは集計される', () async {
      failDocumentsLookup = true;
      final b = await StorageInfoService().computeBreakdown({});
      expect(b.bytesOf(StorageCategory.cache), 123);
      expect(b.totalBytes, 123);
      expect(b.incomplete, {
        StorageCategory.materials,
        StorageCategory.projectData,
        StorageCategory.trash,
        StorageCategory.exports,
        StorageCategory.customAssets,
      });
      expect(b.isUnreadable, isFalse);
      expect(
        AppErrorReporter.recentErrors.where((e) => e.contains('no docs')),
        hasLength(1),
      );
    });

    test('どちらも取れなければ「どの分類も読めなかった」になり、覚えない', () async {
      final service = StorageInfoService();
      final good = await service.computeBreakdown({});
      expect(service.lastBreakdown, same(good));

      failDocumentsLookup = true;
      failCacheLookup = true;
      final b = await service.computeBreakdown({});
      expect(b.isUnreadable, isTrue);
      expect(b.totalBytes, 0);
      expect(service.lastBreakdown, same(good));
    });

    test('フォルダの一覧が途中で失敗しても、読めた分とほかの分類を返す', () async {
      write('${docs.path}/niarim/exports/a.mp4', 29);
      write('${docs.path}/niarim/exports/b.gif', 31);
      write('${docs.path}/niarim/Brushes/a.bin', 37);
      final exports = '${docs.path}/niarim/exports';
      final b = await scanWith({
        exports: () {
          // 本物の一覧と同じく、読めない下位フォルダはエラーとして届き、
          // その後も続きが届く。
          final entries = StreamController<FileSystemEntity>();
          entries
            ..add(File('$exports/a.mp4'))
            ..addError(
              FileSystemException(
                'Directory listing failed',
                '$exports/locked',
                const OSError('Permission denied', 13),
              ),
            )
            ..add(File('$exports/b.gif'))
            ..close();
          return entries.stream;
        },
      });
      expect(b.bytesOf(StorageCategory.exports), 60);
      expect(b.incomplete, {StorageCategory.exports});
      expect(b.bytesOf(StorageCategory.customAssets), 37);
      expect(b.bytesOf(StorageCategory.projectData), 11);
      expect(b.bytesOf(StorageCategory.materials), 17);
      expect(b.bytesOf(StorageCategory.cache), 123);
      expect(
        AppErrorReporter.recentErrors.where(
          (e) => e.contains('Directory listing failed'),
        ),
        hasLength(1),
      );
    });

    test('1つのファイルの大きさが取れなくても、残りを数えて「読めない所がある」とする', () async {
      write('${docs.path}/niarim/Fonts/a.ttf', 43);
      final fonts = '${docs.path}/niarim/Fonts';
      final b = await scanWith({
        fonts: () => Stream.fromIterable([
          _FailingFile(
            '$fonts/locked.ttf',
            FileSystemException(
              'Cannot retrieve length of file',
              '$fonts/locked.ttf',
              const OSError('Permission denied', 13),
            ),
          ),
          File('$fonts/a.ttf'),
          _FailingFile(
            '$fonts/locked2.ttf',
            FileSystemException(
              'Cannot retrieve length of file',
              '$fonts/locked2.ttf',
              const OSError('Permission denied', 13),
            ),
          ),
        ]),
      });
      expect(b.bytesOf(StorageCategory.customAssets), 43);
      expect(b.incomplete, {StorageCategory.customAssets});
      expect(b.bytesOf(StorageCategory.cache), 123);
      // 読めないファイルがいくつあっても、記録は分類ごとに1件。
      expect(
        AppErrorReporter.recentErrors.where(
          (e) => e.contains('Cannot retrieve length of file'),
        ),
        hasLength(1),
      );
    });

    test('一覧を取った後に消えたファイルは、読めなかったうちに入れない', () async {
      write('${docs.path}/niarim/Stamps/a.bin', 41);
      final stamps = '${docs.path}/niarim/Stamps';
      final b = await scanWith({
        stamps: () => Stream.fromIterable([
          _FailingFile(
            '$stamps/gone.bin',
            PathNotFoundException(
              '$stamps/gone.bin',
              const OSError('No such file or directory', 2),
            ),
          ),
          File('$stamps/a.bin'),
        ]),
      });
      expect(b.bytesOf(StorageCategory.customAssets), 41);
      expect(b.incomplete, isEmpty);
      expect(AppErrorReporter.recentErrors, isEmpty);
    });

    test('ゴミ箱の作品の中が読めないときは、ゴミ箱だけが「読めない所がある」になる', () async {
      write('${docs.path}/niarim/projects/t/t.niapro', 19);
      final trashed = '${docs.path}/niarim/projects/t';
      final outside = Zone.current;
      final b = await IOOverrides.runZoned(
        () => StorageInfoService().computeBreakdown({'t'}),
        createDirectory: (path) {
          final real = outside.run(() => Directory(path));
          if (path != '${docs.path}/niarim/projects') return real;
          return _ScriptedDirectory(
            real,
            () => const Stream.empty(),
            children: [
              outside.run(() => Directory('${real.path}/p')),
              _ScriptedDirectory(
                outside.run(() => Directory(trashed)),
                () => Stream.fromIterable([
                  File('$trashed/t.niapro'),
                  _FailingFile(
                    '$trashed/tiles.bin',
                    FileSystemException(
                      'Cannot retrieve length of file',
                      '$trashed/tiles.bin',
                      const OSError('Permission denied', 13),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      );
      expect(b.bytesOf(StorageCategory.trash), 19);
      expect(b.incomplete, {StorageCategory.trash});
      expect(b.bytesOf(StorageCategory.projectData), 11);
      expect(b.bytesOf(StorageCategory.materials), 17);
    });
  });

  test('作品のフォルダは1回の走査で、直下のMaterialsだけを素材に数える', () async {
    write('${docs.path}/niarim/projects/p/tiles/a.bin', 13);
    // 直下ではない同名のフォルダ・名前が似ているだけのフォルダは作品の分。
    write('${docs.path}/niarim/projects/p/tiles/Materials/b.bin', 5);
    write('${docs.path}/niarim/projects/p/MaterialsBackup/c.bin', 7);
    write('${docs.path}/niarim/projects/t/t.niapro', 19);
    write('${docs.path}/niarim/projects/t/Materials/x.wav', 23);
    final b = await StorageInfoService().computeBreakdown({'t'});
    expect(b.bytesOf(StorageCategory.materials), 17);
    expect(b.bytesOf(StorageCategory.projectData), 11 + 13 + 5 + 7);
    expect(b.bytesOf(StorageCategory.trash), 42);
    expect(b.incomplete, isEmpty);
    expect(b.totalBytes, 17 + 36 + 42 + 123);
  });

  group('直近の結果', () {
    test('集計・取得できた結果を覚え、大きさを変える操作で捨てる', () async {
      final service = StorageInfoService();
      expect(service.lastBreakdown, isNull);
      final first = await service.computeBreakdown({});
      // 別のインスタンスからも同じものが見える（画面を開き直した場合）。
      expect(StorageInfoService().lastBreakdown, same(first));

      expect(await service.clearCache(), 123);
      expect(service.lastBreakdown, isNull);

      final second = await service.computeBreakdown({});
      expect(second.bytesOf(StorageCategory.cache), 0);
      expect(service.lastBreakdown, same(second));

      await service.eraseAllData();
      expect(service.lastBreakdown, isNull);
    });

    test('一部を読めなかった結果も、読めなかった印ごと覚える', () async {
      failCacheLookup = true;
      final service = StorageInfoService();
      final partial = await service.computeBreakdown({});
      expect(service.lastBreakdown, same(partial));
      expect(service.lastBreakdown!.incomplete, {StorageCategory.cache});
    });

    test('大きさを変える操作より前に始まった集計は覚えない', () async {
      final service = StorageInfoService();
      final stale = service.computeBreakdown({});
      await service.clearCache();
      await stale;
      expect(service.lastBreakdown, isNull);
    });
  });

  group('重なった集計', () {
    test('同じ条件で重なった呼び出しは、1回の走査を分け合う', () async {
      final first = StorageInfoService().computeBreakdown({});
      final second = StorageInfoService().computeBreakdown({});
      expect(second, same(first));
      final results = await Future.wait([first, second]);
      expect(results.first, same(results.last));
      expect(cacheLookups, 1);

      // 終わった後の呼び出しは、あらためて走査する。
      write('${cache.path}/more.bin', 10);
      final later = await StorageInfoService().computeBreakdown({});
      expect(later.bytesOf(StorageCategory.cache), 133);
      expect(cacheLookups, 2);
    });

    test('ゴミ箱の中身が違う呼び出しは、分け合わない', () async {
      write('${docs.path}/niarim/projects/t/t.niapro', 19);
      final live = StorageInfoService().computeBreakdown({});
      final trashed = StorageInfoService().computeBreakdown({'t'});
      expect(trashed, isNot(same(live)));
      expect((await live).bytesOf(StorageCategory.trash), 0);
      expect((await trashed).bytesOf(StorageCategory.trash), 19);
      expect(cacheLookups, 2);
    });

    test('大きさを変える操作の後の呼び出しは、前から走っている集計を待たない', () async {
      final service = StorageInfoService();
      final stale = service.computeBreakdown({});
      service.invalidate();
      final fresh = service.computeBreakdown({});
      expect(fresh, isNot(same(stale)));
      final results = await Future.wait([stale, fresh]);
      expect(cacheLookups, 2);
      expect(service.lastBreakdown, same(results.last));
    });

    test('別のゾーンで始まった集計は待たない（そのゾーンが止まると終わらないため）', () async {
      final elsewhere = runZoned(
        () => StorageInfoService().computeBreakdown({}),
      );
      final here = StorageInfoService().computeBreakdown({});
      expect(here, isNot(same(elsewhere)));
      await Future.wait([elsewhere, here]);
      expect(cacheLookups, 2);
    });

    test('失敗で終わった集計の後も、次の呼び出しは新しく走査できる', () async {
      final outside = Zone.current;
      var fail = true;
      // 同じゾーンの中で続けて呼ぶ（失敗した集計が残っていれば、それを待つ）。
      await IOOverrides.runZoned(
        () async {
          await expectLater(
            StorageInfoService().computeBreakdown({}),
            throwsStateError,
          );
          fail = false;
          final b = await StorageInfoService().computeBreakdown({});
          expect(b.bytesOf(StorageCategory.cache), 123);
          expect(b.incomplete, isEmpty);
        },
        createDirectory: (path) => fail && path.endsWith('/niarim/projects')
            ? throw StateError('unexpected failure')
            : outside.run(() => Directory(path)),
      );
    });
  });
}

/// 本物のフォルダの代わりに、決めた中身を一覧として返す。
class _ScriptedDirectory implements Directory {
  _ScriptedDirectory(this._real, this._entries, {this.children = const []});

  final Directory _real;
  final Stream<FileSystemEntity> Function() _entries;
  final List<FileSystemEntity> children;

  @override
  String get path => _real.path;

  @override
  Uri get uri => _real.uri;

  @override
  bool existsSync() => true;

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => children;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => _entries();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 大きさを聞かれると[error]で失敗するファイル。
class _FailingFile implements File {
  _FailingFile(this.path, this.error);

  @override
  final String path;
  final Object error;

  @override
  Future<int> length() async => throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
