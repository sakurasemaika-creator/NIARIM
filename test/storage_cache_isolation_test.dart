import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory cache;
  late Directory sharedTemp;
  late Directory documents;
  late File unrelated;
  late File cached;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-cache-isolation-');
    cache = await Directory('${root.path}/app-cache').create();
    sharedTemp = await Directory('${root.path}/shared-temp').create();
    documents = await Directory('${root.path}/documents').create();
    unrelated = await File(
      '${sharedTemp.path}/another-app-data.bin',
    ).writeAsBytes(List.filled(257, 83));
    cached = await File(
      '${cache.path}/niarim-cache.bin',
    ).writeAsBytes(List.filled(123, 17));
    SharedPreferences.setMockInitialValues({'first_launch': false});
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'getTemporaryDirectory' => sharedTemp.path,
        'getApplicationCacheDirectory' => cache.path,
        'getApplicationDocumentsDirectory' => documents.path,
        _ => throw StateError('Unexpected path request: ${call.method}'),
      };
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('cache accounting excludes the OS shared temporary directory', () async {
    final breakdown = await StorageInfoService().computeBreakdown({});
    expect(breakdown.bytesOf(StorageCategory.cache), 123);
    expect(await unrelated.readAsBytes(), List.filled(257, 83));
    expect(await cached.exists(), isTrue);
  });

  test('clear cache removes only the application cache', () async {
    final freed = await StorageInfoService().clearCache();
    expect(await unrelated.readAsBytes(), List.filled(257, 83));
    expect(freed, 123);
    expect(await cached.exists(), isFalse);
    expect(await cache.exists(), isTrue);
  });

  test(
    'reset preserves shared temporary and unrelated document files',
    () async {
      final project = File('${documents.path}/niarim/projects/p/data.niapro');
      await project.parent.create(recursive: true);
      await project.writeAsString('synthetic application project');
      final export = File('${documents.path}/exports/animation.gif');
      await export.parent.create();
      await export.writeAsString('synthetic application export');
      final otherDocument = await File(
        '${documents.path}/another-app.txt',
      ).writeAsString('unrelated document');

      await StorageInfoService().eraseAllData();

      expect(await unrelated.readAsBytes(), List.filled(257, 83));
      expect(await otherDocument.readAsString(), 'unrelated document');
      expect(await project.exists(), isFalse);
      expect(await export.exists(), isFalse);
      expect(await cached.exists(), isFalse);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test(
    'cache cleanup does not follow links into another application',
    () async {
      final link = await Link(
        '${cache.path}/outside-link',
      ).create(unrelated.path);
      await StorageInfoService().clearCache();
      expect(await unrelated.readAsBytes(), List.filled(257, 83));
      expect(await link.exists(), isFalse);
    },
    skip: Platform.isWindows
        ? 'Symlink creation needs extra privileges on Windows'
        : false,
  );
}
