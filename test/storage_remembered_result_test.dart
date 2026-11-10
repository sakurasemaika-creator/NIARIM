import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 容量の集計が覚えておく「前回の結果」の決まり。
/// - 結果は、ゴミ箱として数えた作品の集合と一緒に覚える。
/// - 棒の本数（中身のある分類の数）は並びの見込みなので、結果を捨てても残る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;

  void write(String path, int bytes) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(bytes, 1));
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-remembered-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path,
    );
    write('${docs.path}/niarim/projects/p/p.niapro', 11);
    write('${docs.path}/niarim/projects/t/t.niapro', 19);
    write('${cache.path}/thumb.bin', 123);
    StorageInfoService().invalidate();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('前回の結果は、同じ作品をゴミ箱として数えたときだけ返す', () async {
    final service = StorageInfoService();
    expect(service.lastBreakdownFor({}), isNull);

    // ゴミ箱が空のときの集計：tは作品データに数えられている。
    final emptyTrash = await service.computeBreakdown({});
    expect(emptyTrash.bytesOf(StorageCategory.trash), 0);
    expect(emptyTrash.bytesOf(StorageCategory.projectData), 30);
    expect(service.lastBreakdownFor({}), same(emptyTrash));
    // tをゴミ箱へ移した後では、この結果は合っていない。
    expect(service.lastBreakdownFor({'t'}), isNull);

    final withTrash = await service.computeBreakdown({'t'});
    expect(withTrash.bytesOf(StorageCategory.trash), 19);
    expect(service.lastBreakdownFor({'t'}), same(withTrash));
    // tを戻した後では、ゴミ箱の大きさが残っている結果を返さない。
    expect(service.lastBreakdownFor({}), isNull);

    service.invalidate();
    expect(service.lastBreakdownFor({'t'}), isNull);
  });

  test('棒の本数は、結果を捨てても覚えていて、次の集計で入れ替わる', () async {
    final service = StorageInfoService();
    final first = await service.computeBreakdown({});
    expect(first.nonEmptyCategoryCount, 2);
    expect(service.lastNonEmptyCategoryCount, 2);

    // キャッシュを消す：結果は捨てるが、並びの見込みは残る。
    await service.clearCache();
    expect(service.lastBreakdown, isNull);
    expect(service.lastNonEmptyCategoryCount, 2);

    final second = await service.computeBreakdown({});
    expect(second.nonEmptyCategoryCount, 1);
    expect(service.lastNonEmptyCategoryCount, 1);
  });
}
