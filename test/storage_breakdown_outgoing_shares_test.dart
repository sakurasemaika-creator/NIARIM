import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 容量削減の画面の内訳は、作成した共有ファイル（`niarim/shared/outgoing`）を
/// 「書き出し済みファイル」に数える。
///
/// 以前はどの分類にも数えず、共有ファイルを作るほど端末の容量を使うのに、
/// 内訳とNIARIMの合計には出なかった（.niashareは作品のタイル・素材を含み、
/// 大きくなりうる）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory documents;
  late Directory cache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-storage-shares-');
    documents = await Directory('${root.path}/documents').create();
    cache = await Directory('${root.path}/cache').create();
    SharedPreferences.setMockInitialValues({'first_launch': false});
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'getApplicationCacheDirectory' => cache.path,
        'getApplicationDocumentsDirectory' => documents.path,
        _ => root.path,
      };
    });
    StorageInfoService().invalidate();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    StorageInfoService().invalidate();
    await root.delete(recursive: true);
  });

  void write(String relative, int bytes) {
    File('${documents.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 7));
  }

  test('created share files are counted with the exported files', () async {
    write('niarim/exports/clip.gif', 100);
    // Each created share is a folder with its .niashare file.
    write('niarim/shared/outgoing/1700000000000001/歩き.niashare', 300);
    write('niarim/shared/outgoing/1700000000000002/Walk cycle.niashare', 50);

    final breakdown = await StorageInfoService().computeBreakdown({});
    expect(
      breakdown.bytesOf(StorageCategory.exports),
      450,
      reason: 'the created share files are missing from the breakdown',
    );
    expect(breakdown.totalBytes, 450);
    expect(breakdown.incomplete, isEmpty);
  });

  test('only created share files: the exported files show them', () async {
    write('niarim/shared/outgoing/1700000000000003/a.niashare', 2048);

    final breakdown = await StorageInfoService().computeBreakdown({});
    expect(breakdown.bytesOf(StorageCategory.exports), 2048);
    expect(breakdown.nonEmptyCategories, {StorageCategory.exports});
  });

  test('no shared folder: the exported files are the exports only', () async {
    write('niarim/exports/clip.mp4', 123);

    final breakdown = await StorageInfoService().computeBreakdown({});
    expect(breakdown.bytesOf(StorageCategory.exports), 123);
    expect(breakdown.incomplete, isEmpty);
  });
}
