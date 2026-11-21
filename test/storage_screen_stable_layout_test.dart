import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';

import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面で、集計の結果が届く・やり直す・待ち切れになるたびに、
/// 操作の行が指の下で動かないこと（「プロジェクトを整理する」に置いた指が
/// 「全データを削除」の上に来ない）。行の位置を実測して見張る。
const _fillOrder = [
  StorageCategory.cache,
  StorageCategory.projectData,
  StorageCategory.materials,
  StorageCategory.exports,
  StorageCategory.customAssets,
  StorageCategory.trash,
];

/// 中身のある分類が[bars]個の内訳（キャッシュはいつも中身がある）。
StorageBreakdown _withBars(int bars, {bool cacheCleared = false}) =>
    StorageBreakdown({
      for (var i = 0; i < _fillOrder.length; i++)
        _fillOrder[i]: i >= bars || (cacheCleared && i == 0)
            ? 0
            : 1000 * (i + 1),
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-stable-layout-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  /// 操作の5行の上端（上から順）。
  List<double> rowTops(WidgetTester tester, List<String> titles) => [
    for (final title in titles) tester.getTopLeft(storageTile(title)).dy,
  ];

  // 画面は縦に長く取る（どの行も作られたまま測れる。行の位置は画面の高さに
  // よらない）。
  const profiles = [
    ('390幅', Size(390, 2400), 1.0),
    ('900幅', Size(900, 2400), 1.0),
    ('320幅・文字2倍', Size(320, 3200), 2.0),
  ];

  for (final (label, size, textScale) in profiles) {
    testWidgets('最初の結果が届いても、操作の後で棒が減っても、操作の行は動かない（$label・棒1〜6本）', (
      tester,
    ) async {
      final providers = await bootstrapStorageScreen(tester);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (var bars = 1; bars <= _fillOrder.length; bars++) {
        final service = ScriptedStorage();
        final l10n = await showStorageScreen(
          tester,
          providers,
          service,
          size: size,
        );
        final titles = [
          l10n.storageClearCacheButton,
          l10n.storageRemoveUnusedMaterialsButton,
          l10n.storageEmptyTrashButton,
          l10n.storageOrganizeProjectsButton,
          l10n.storageEraseAllButton,
        ];
        // 端末の容量も内訳もまだ分からない最初のフレーム。
        final calculating = rowTops(tester, titles);

        service.deviceQueries.single.complete(storageTestDevice);
        await tester.pump();
        await tester.pump();
        expect(rowTops(tester, titles), calculating, reason: '$bars本・端末の容量');

        service.scans.single.complete(_withBars(bars));
        await tester.pump();
        await tester.pump();
        final landed = rowTops(tester, titles);
        expect(landed, calculating, reason: '$bars本・最初の結果');

        // キャッシュを消す：集計し直している間も、キャッシュの棒が無くなった
        // 結果が届いた後も、行は同じ所。
        await tester.tap(storageTile(l10n.storageClearCacheButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(service.scans, hasLength(2));
        final recalculating = rowTops(tester, titles);
        expect(recalculating, calculating, reason: '$bars本・操作の後');

        service.deviceQueries.last.complete(storageTestDevice);
        service.scans.last.complete(_withBars(bars, cacheCleared: true));
        await tester.pump();
        await tester.pump();
        final rescanned = rowTops(tester, titles);
        expect(rescanned, calculating, reason: '$bars本・集計し直した後');
        expect(tester.takeException(), isNull, reason: '$bars本');
        debugPrint(
          'STORAGE ROW Y $label bars=$bars first-row: '
          'calculating=${calculating.first} landed=${landed.first} '
          'recalculating=${recalculating.first} '
          'rescanned(cache 0)=${rescanned.first}',
        );
        // 次の本数は、画面を作り直して最初から。
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets('前回の棒の本数を覚えていれば、その高さだけを取っておく（空きを残さない）', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    Future<(double, double)> heightsFor(int? rememberedBars, int bars) async {
      final service = ScriptedStorage()
        ..rememberedCategories = rememberedBars == null
            ? null
            : _withBars(rememberedBars).nonEmptyCategories;
      final l10n = await showStorageScreen(tester, providers, service);
      service.deviceQueries.single.complete(null);
      await tester.pump();
      final tile = storageTile(l10n.storageClearCacheButton);
      final section = find.byKey(const ValueKey('storageBreakdownSection'));
      final before = tester.getTopLeft(tile).dy;
      final reserved = tester.getSize(section).height;
      service.scans.single.complete(_withBars(bars));
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(tile).dy,
        before,
        reason: '$rememberedBars→$bars',
      );
      final shown = tester.getSize(section).height;
      await tester.pumpWidget(const SizedBox.shrink());
      return (reserved, shown);
    }

    // 覚えが無い：分類の数だけ（いちばん高い場合）を取っておく。
    final (unknownReserved, unknownShown) = await heightsFor(null, 2);
    expect(unknownShown, unknownReserved);
    // 覚えがある（消した後で集計結果を捨てていても）：その本数の高さ。
    final (twoReserved, twoShown) = await heightsFor(2, 2);
    expect(twoShown, twoReserved);
    expect(twoReserved, lessThan(unknownReserved));
    // 6本目はゴミ箱：ゴミ箱の棒は、ゴミ箱に作品があるときだけ並ぶ。
    final projects = await storageProjectServiceOf(tester, providers);
    await addStorageTestProject(tester, projects, trashed: true);
    final (sixReserved, _) = await heightsFor(6, 6);
    expect(sixReserved, unknownReserved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('内訳のやり直し・失敗・成功で、端末の容量の欄も操作の行も動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    final titles = [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEmptyTrashButton,
      l10n.storageOrganizeProjectsButton,
      l10n.storageEraseAllButton,
    ];
    final retry = find.byKey(storageBreakdownRetryKey);
    final calculating = rowTops(tester, titles);

    // 端末の容量は答えたが、内訳の集計は失敗した。
    service.deviceQueries.single.complete(storageTestDevice);
    service.scans.single.completeError(StateError('unreadable'));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
    expect(rowTops(tester, titles), calculating);
    final retryTop = tester.getTopLeft(retry).dy;

    // やり直しを押しても、押したボタンは指の下から動かない。
    await tester.tap(retry);
    await tester.pump();
    expect(service.scans, hasLength(2));
    expect(tester.getTopLeft(retry).dy, retryTop);
    expect(rowTops(tester, titles), calculating);

    // もう一度失敗しても、成功しても同じ。
    service.scans.last.completeError(StateError('unreadable again'));
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(retry).dy, retryTop);
    expect(rowTops(tester, titles), calculating);

    await tester.tap(retry);
    await tester.pump();
    service.scans.last.complete(_withBars(3));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(retry, findsNothing);
    expect(rowTops(tester, titles), calculating);
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末の容量が待ち切れになっても、遅れて届いても、操作の行は動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    final titles = [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEmptyTrashButton,
      l10n.storageOrganizeProjectsButton,
      l10n.storageEraseAllButton,
    ];
    final calculating = rowTops(tester, titles);
    service.scans.single.complete(_withBars(3));
    await tester.pump();
    await tester.pump();
    expect(rowTops(tester, titles), calculating);

    // 4秒たっても答えが無い：集計中の表示が知らせに替わる。
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsOneWidget);
    expect(rowTops(tester, titles), calculating);

    // 遅れて届いた答えでグラフになる。
    service.deviceQueries.single.complete(storageTestDevice);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(rowTops(tester, titles), calculating);
    expect(tester.takeException(), isNull);
  });
}
