import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 容量削減の画面の並びの見込み（内訳の中身のあった分類と、読めなかった
/// 分類の知らせの有無）を、次の起動のために保存して読み直す決まり。
/// - 集計できた内訳で見込みが変わったら保存し、起動処理が読み直す。
/// - 保存が壊れている・知らない分類の名前があるなら使わない（画面はいちばん
///   高い場合を取る）。
/// - 全データを削除した後の集計は、前に覚えていた見込みによらず保存する。
/// - 棒の本数の見込みは、ひとりでに変わる分類（キャッシュ・ゴミ箱・作品
///   データ）を今の様子で合わせる。
const _savedCategoriesKey = 'storage_breakdown_categories';
const _savedIncompleteKey = 'storage_breakdown_incomplete';

const _materials = StorageCategory.materials;
const _projectData = StorageCategory.projectData;
const _trash = StorageCategory.trash;
const _exports = StorageCategory.exports;
const _customAssets = StorageCategory.customAssets;
const _cache = StorageCategory.cache;

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
    root = Directory.systemTemp.createTempSync('storage-saved-layout-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path,
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('集計で保存した見込みを、次の起動の読み直しで同じ値として読む', () async {
    final service = StorageInfoService();
    // 前の見込み（5つ・知らせあり）を覚えている状態から始める。
    SharedPreferences.setMockInitialValues({
      _savedCategoriesKey: [
        'materials',
        'projectData',
        'trash',
        'exports',
        'customAssets',
      ],
      _savedIncompleteKey: true,
    });
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategories, {
      _materials,
      _projectData,
      _trash,
      _exports,
      _customAssets,
    });
    expect(service.lastNonEmptyCategoryCount, 5);
    expect(service.lastBreakdownIncomplete, isTrue);

    write('${docs.path}/niarim/projects/p/p.niapro', 11);
    write('${cache.path}/thumb.bin', 123);
    final breakdown = await service.computeBreakdown({});
    expect(breakdown.nonEmptyCategories, {_projectData, _cache});
    expect(service.lastNonEmptyCategories, {_projectData, _cache});
    expect(service.lastBreakdownIncomplete, isFalse);
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    final saved = <String, Object>{
      _savedCategoriesKey: prefs.getStringList(_savedCategoriesKey)!,
      _savedIncompleteKey: prefs.getBool(_savedIncompleteKey)!,
    };
    expect(saved, {
      _savedCategoriesKey: ['projectData', 'cache'],
      _savedIncompleteKey: false,
    });

    // 結果を捨てても（大きさを変える操作の後）、見込みは残る。
    service.invalidate();
    expect(service.lastNonEmptyCategories, {_projectData, _cache});

    // 次の起動：別の見込みを覚えていても、保存を読み直すとその値になる。
    SharedPreferences.setMockInitialValues({
      _savedCategoriesKey: ['cache'],
      _savedIncompleteKey: true,
    });
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategories, {_cache});
    SharedPreferences.setMockInitialValues(saved);
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategories, {_projectData, _cache});
    expect(service.lastBreakdownIncomplete, isFalse);
  });

  test('壊れた記録・知らない分類の名前は使わず、前の見込みのまま', () async {
    final service = StorageInfoService();
    SharedPreferences.setMockInitialValues({
      _savedCategoriesKey: ['materials', 'projectData', 'cache'],
      _savedIncompleteKey: true,
    });
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategories, {_materials, _projectData, _cache});
    expect(service.lastBreakdownIncomplete, isTrue);

    for (final broken in <Object>[
      3,
      'cache',
      2.5,
      true,
      ['bogus'],
      ['cache', '7'],
      ['Cache'],
    ]) {
      SharedPreferences.setMockInitialValues({
        _savedCategoriesKey: broken,
        _savedIncompleteKey: false,
      });
      await service.restoreSavedLayout();
      expect(service.lastNonEmptyCategories, {
        _materials,
        _projectData,
        _cache,
      }, reason: '$broken');
      expect(service.lastBreakdownIncomplete, isTrue, reason: '$broken');
    }

    // 知らせの有無だけ読めなければ、知らせは無かったものとして扱う。
    SharedPreferences.setMockInitialValues({
      _savedCategoriesKey: ['projectData', 'cache'],
      _savedIncompleteKey: 'yes',
    });
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategories, {_projectData, _cache});
    expect(service.lastBreakdownIncomplete, isFalse);

    // 中身のある分類が無かった内訳（空の一覧）も見込みとして読む。
    SharedPreferences.setMockInitialValues({_savedCategoriesKey: <String>[]});
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategories, isEmpty);
  });

  test('保存が無い起動では、覚えている見込みを変えない', () async {
    final service = StorageInfoService();
    SharedPreferences.setMockInitialValues({
      _savedCategoriesKey: ['materials', 'projectData', 'exports', 'cache'],
    });
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategoryCount, 4);
    expect(service.lastBreakdownIncomplete, isFalse);
    SharedPreferences.setMockInitialValues({});
    await service.restoreSavedLayout();
    expect(service.lastNonEmptyCategoryCount, 4);
  });

  test('操作の前に始まった集計が後から終わっても、見込みを操作の前の中身へ戻さない', () async {
    SharedPreferences.setMockInitialValues({});
    write('${docs.path}/niarim/projects/p/p.niapro', 11);
    write('${docs.path}/niarim/projects/p/Materials/m.png', 7);
    // 操作の前の集計を、作品のフォルダを数え終えた所（キャッシュのフォルダを
    // 尋ねる所）で止めておく。
    final reached = Completer<void>();
    final release = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'getApplicationCacheDirectory') return docs.path;
      if (!reached.isCompleted) {
        reached.complete();
        await release.future;
      }
      return cache.path;
    });
    final service = StorageInfoService();
    final beforeAction = service.computeBreakdown({});
    await reached.future;

    // 使っていない素材を消した（画面の操作と同じく、覚えた結果を捨てて
    // 集計し直す）。
    Directory(
      '${docs.path}/niarim/projects/p/Materials',
    ).deleteSync(recursive: true);
    service.invalidate();
    final afterAction = await service.computeBreakdown({});
    expect(afterAction.nonEmptyCategories, {_projectData});
    await pumpEventQueue();

    // 操作の前の集計が後から終わる（素材の分を数えている）。
    release.complete();
    expect((await beforeAction).nonEmptyCategories, {_materials, _projectData});
    await pumpEventQueue();
    expect(service.lastNonEmptyCategories, {_projectData});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_savedCategoriesKey), ['projectData']);
  });

  test('棒の本数の見込みは、ひとりでに変わる分類を今の様子で合わせる', () async {
    final service = StorageInfoService();
    Future<int?> expected(
      List<String> saved, {
      bool hasTrash = false,
      bool hasLiveProjects = false,
    }) async {
      SharedPreferences.setMockInitialValues({_savedCategoriesKey: saved});
      await service.restoreSavedLayout();
      return service.expectedBarCount(
        hasTrash: hasTrash,
        hasLiveProjects: hasLiveProjects,
      );
    }

    // キャッシュは、覚えた内訳に無くても（消した後の集計）あるものとする。
    expect(await expected(['materials', 'projectData']), 3);
    expect(await expected(['materials', 'projectData', 'cache']), 3);
    // ゴミ箱は、いまゴミ箱に作品があるかで決まる。
    expect(await expected(['projectData', 'cache'], hasTrash: true), 3);
    expect(await expected(['projectData', 'cache', 'trash']), 2);
    expect(
      await expected(['projectData', 'cache', 'trash'], hasTrash: true),
      3,
    );
    // 作品データは、ゴミ箱の外に作品があればあるものとし、無くても減らさない
    // （読めていない作品のフォルダも数える）。
    expect(await expected([], hasLiveProjects: true), 2);
    expect(await expected(['projectData', 'cache']), 2);
    // 素材・書き出し・自作の素材は、覚えた値のまま。
    expect(
      await expected([
        'materials',
        'projectData',
        'trash',
        'exports',
        'customAssets',
        'cache',
      ], hasTrash: true),
      6,
    );
    expect(await expected([]), 1);
  });

  test('何も覚えていなければ、棒の本数を見込まない（画面は分類の数だけ取る）', () {
    // 起動処理の読み直しより前・保存の無い端末を、全データの削除で作る
    // （削除は、保存とプロセスの中の覚えの両方を消す）。
    SharedPreferences.setMockInitialValues({});
    final service = StorageInfoService();
    return service.eraseAllData().then((_) {
      expect(service.lastNonEmptyCategories, isNull);
      expect(
        service.expectedBarCount(hasTrash: true, hasLiveProjects: true),
        isNull,
      );
    });
  });

  for (final hadContent in [false, true]) {
    test('全データを削除した後の集計は、前の見込みによらず次の起動のために保存する'
        '（削除の前の集計：${hadContent ? '中身あり' : '中身なし'}）', () async {
      SharedPreferences.setMockInitialValues({});
      if (hadContent) {
        write('${docs.path}/niarim/projects/p/p.niapro', 11);
        write('${cache.path}/thumb.bin', 123);
      }
      final service = StorageInfoService();
      await service.computeBreakdown({});
      await pumpEventQueue();
      await service.eraseAllData();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      // 画面は削除の後で集計し直す（何も無い）。
      final after = await service.computeBreakdown({});
      expect(after.nonEmptyCategoryCount, 0);
      await pumpEventQueue();
      expect(prefs.getStringList(_savedCategoriesKey), isEmpty);
      expect(prefs.getBool(_savedIncompleteKey), isFalse);

      // 次の起動の最初の画面は、削除の後の集計（とキャッシュ）の高さを取る。
      await service.restoreSavedLayout();
      expect(
        service.expectedBarCount(hasTrash: false, hasLiveProjects: false),
        1,
      );
    });
  }
}
