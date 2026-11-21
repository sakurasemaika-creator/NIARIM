import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/services/font_service.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 容量削減の画面の外でファイルを消す所（素材・手動の保存・自作フォント）は、
/// 覚えている集計結果を捨てさせる。捨てないと、消した直後に開いた画面が
/// 消す前の値を今の値として出し、消す前から走っていた集計の結果まで
/// 「前回の値」として覚える。
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
    root = Directory.systemTemp.createTempSync('storage-outside-deletions-');
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
    StorageInfoService().invalidate();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('素材を消すと、覚えている集計結果を捨て、消す前からの集計も覚えない', () async {
    final source = File('${root.path}/big.mp4')
      ..writeAsBytesSync(List<int>.filled(5000, 3));
    final materials = MaterialService();
    final asset = await materials.addMaterial(
      projectId: 'p',
      sourcePath: source.path,
      type: MaterialType.video,
    );
    final service = StorageInfoService();
    final before = await service.computeBreakdown({});
    expect(
      before.bytesOf(StorageCategory.materials),
      greaterThanOrEqualTo(5000),
    );
    expect(service.lastBreakdown, same(before));

    // 消す前から走っている集計（まだ終わっていない）。
    final running = service.computeBreakdown({});
    final removed = await materials.removeMaterial(
      projectId: 'p',
      materialId: asset.id,
      isUsed: (_) => false,
    );
    expect(removed, isTrue);

    // 消す前の値は、開き直した画面に出さない。
    expect(service.lastBreakdown, isNull);
    // 消す前のディスクを見ている集計は、後から来た呼び出しへ渡さない。
    final afterwards = service.computeBreakdown({});
    expect(afterwards, isNot(same(running)));
    final results = await Future.wait([running, afterwards]);
    expect(results.last.bytesOf(StorageCategory.materials), lessThan(5000));
    // 消す前に始まった集計が終わっても、その結果を「前回の値」にしない。
    expect(service.lastBreakdown, same(results.last));
    materials.dispose();
  });

  test('未使用の素材をまとめて消しても、覚えている集計結果を捨てる', () async {
    final materials = MaterialService();
    for (final name in ['a.png', 'b.png']) {
      final source = File('${root.path}/$name')
        ..writeAsBytesSync(List<int>.filled(name == 'a.png' ? 700 : 900, 3));
      await materials.addMaterial(
        projectId: 'p',
        sourcePath: source.path,
        type: MaterialType.image,
      );
    }
    final service = StorageInfoService();
    final before = await service.computeBreakdown({});
    expect(
      before.bytesOf(StorageCategory.materials),
      greaterThanOrEqualTo(1600),
    );

    expect(
      await materials.removeUnused(projectId: 'p', isUsed: (_) => false),
      2,
    );
    expect(service.lastBreakdown, isNull);
    final after = await service.computeBreakdown({});
    expect(after.bytesOf(StorageCategory.materials), lessThan(700));
    materials.dispose();
  });

  test('消すものが無かった素材の操作は、覚えている結果をそのままにする', () async {
    final materials = MaterialService();
    final service = StorageInfoService();
    final before = await service.computeBreakdown({});
    expect(
      await materials.removeMaterial(
        projectId: 'p',
        materialId: 'missing',
        isUsed: (_) => false,
      ),
      isFalse,
    );
    expect(service.lastBreakdown, same(before));
    materials.dispose();
  });

  test('手動の保存のノードを消すと、覚えている集計結果を捨てる', () async {
    write('${docs.path}/niarim/projects/p/SaveTree/n1.niapro', 4000);
    write('${docs.path}/niarim/projects/p/SaveTree/n1_thumb.png', 300);
    final service = StorageInfoService();
    final before = await service.computeBreakdown({});
    expect(before.bytesOf(StorageCategory.projectData), 11 + 4000 + 300);
    expect(service.lastBreakdown, same(before));

    final saves = SaveTreeService();
    await saves.deleteNode('p', 'n1');
    expect(
      File('${docs.path}/niarim/projects/p/SaveTree/n1.niapro').existsSync(),
      isFalse,
    );
    expect(service.lastBreakdown, isNull);
    final after = await service.computeBreakdown({});
    expect(after.bytesOf(StorageCategory.projectData), lessThan(4000));
    saves.dispose();
  });

  test('自作フォントを消すと、覚えている集計結果を捨てる', () async {
    final fonts = FontService();
    await fonts.init();
    final font = await fonts.addFont(
      'assets/fonts/NotoSansKRBlackSubset.ttf',
      'Audit font',
    );
    expect(font, isNotNull);
    final service = StorageInfoService();
    final before = await service.computeBreakdown({});
    expect(before.bytesOf(StorageCategory.customAssets), greaterThan(0));
    expect(service.lastBreakdown, same(before));

    await fonts.removeFont(font!.id);
    expect(service.lastBreakdown, isNull);
    final after = await service.computeBreakdown({});
    expect(after.bytesOf(StorageCategory.customAssets), 0);
    fonts.dispose();
  });
}
