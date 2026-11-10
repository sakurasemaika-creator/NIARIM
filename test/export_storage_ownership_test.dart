import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;
  late Directory managed;
  late Directory legacy;

  File write(Directory directory, String name, int bytes) {
    directory.createSync(recursive: true);
    return File('${directory.path}/$name')
      ..writeAsBytesSync(List.filled(bytes, 29));
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-export-ownership-');
    docs = Directory('${root.path}/Documents')..createSync();
    cache = Directory('${root.path}/app-cache')..createSync();
    managed = Directory('${docs.path}/niarim/exports');
    legacy = Directory('${docs.path}/exports');
    SharedPreferences.setMockInitialValues({'first_launch': false});
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'getApplicationDocumentsDirectory' => docs.path,
        'getApplicationCacheDirectory' => cache.path,
        'getTemporaryDirectory' => '${root.path}/shared-temp',
        _ => throw StateError('Unexpected path request: ${call.method}'),
      };
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('new exports use the NIARIM managed directory', () async {
    final directory = await ExportEngine.exportsDir();
    expect(directory.path, managed.path);
    expect(await directory.exists(), isTrue);
    expect(await legacy.exists(), isFalse);
  });

  test('storage accounting excludes the shared exports directory', () async {
    final own = write(managed, 'niarim_1.mp4', 13);
    final other = write(legacy, 'another-app.mp4', 257);
    final old = write(legacy, 'renamed-old-work.gif', 19);
    final breakdown = await StorageInfoService().computeBreakdown({});
    expect(breakdown.bytesOf(StorageCategory.exports), 13);
    expect(await own.length(), 13);
    expect(await other.length(), 257);
    expect(await old.length(), 19);
  });

  test(
    'reset preserves all shared exports and removes managed exports',
    () async {
      final own = write(managed, 'niarim_1.mp4', 13);
      final other = write(legacy, 'another-app.mp4', 257);
      final old = write(legacy, 'renamed-old-work.gif', 19);
      final lookalike = write(legacy, 'niarim_1712345678901.mp4', 31);
      final nested = write(
        Directory('${legacy.path}/another-app'),
        'work.bin',
        43,
      );
      write(cache, 'cached.bin', 47);
      await StorageInfoService().eraseAllData();
      expect(await other.exists(), isTrue);
      expect(await old.exists(), isTrue);
      expect(await lookalike.exists(), isTrue);
      expect(await nested.exists(), isTrue);
      expect(await other.readAsBytes(), List.filled(257, 29));
      expect(await old.readAsBytes(), List.filled(19, 29));
      expect(await lookalike.readAsBytes(), List.filled(31, 29));
      expect(await own.exists(), isFalse);
      expect(await managed.exists(), isFalse);
      expect(cache.listSync(), isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test('both export locations remain available with equal filenames', () async {
    final own = write(managed, 'my-work.gif', 13);
    final old = write(legacy, 'my-work.gif', 19);
    final files = await ExportEngine.listExportedFiles(forceRefresh: true);
    expect(
      files.map((file) => file.path),
      unorderedEquals([own.path, old.path]),
    );
    expect(await own.readAsBytes(), List.filled(13, 29));
    expect(await old.readAsBytes(), List.filled(19, 29));
  });

  test(
    'reset invalidates a cached export list and retains legacy works',
    () async {
      final own = write(managed, 'managed.gif', 13);
      final old = write(legacy, 'old.gif', 19);
      await ExportEngine.listExportedFiles(forceRefresh: true);
      await StorageInfoService().eraseAllData();
      final files = await ExportEngine.listExportedFiles();
      expect(files.map((file) => file.path), [old.path]);
      expect(await old.exists(), isTrue);
      expect(await own.exists(), isFalse);
    },
  );

  test(
    'unrelated non-media files are preserved without listing as works',
    () async {
      final foreign = write(legacy, 'another-app.bin', 257);
      final old = write(legacy, 'OLD_WORK.GIF', 19);
      final files = await ExportEngine.listExportedFiles(forceRefresh: true);
      expect(files.map((file) => file.path), [old.path]);
      expect(await foreign.readAsBytes(), List.filled(257, 29));
    },
  );
}
