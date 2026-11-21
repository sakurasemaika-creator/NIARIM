import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';

import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面が、もう合っていない値・いつまでも終わらない集計をどう扱うか。
/// - 大きさを変える操作の後は、グラフも集計し直すまで前の値を出さない。
/// - 欄が集計中からグラフへ変わっても、操作の行は動かない。
/// - 画面を閉じた後に終わった操作でも、覚えている結果は捨てる。
/// - 終わらない集計は、引っぱって更新を待たせ続けず、始め直せる。
const _device = storageTestDevice;

/// 走っている集計を待つのをやめる長さ（30秒）より少し長く。
const _pastScanLimit = Duration(seconds: 31);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-outdated-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  // 一覧の画面の外も含めて探す。欄が高さを測るための見本（IndexedStackの
  // 選ばれていない子。描かない・読み上げない）は数えない。
  Finder anywhere(String text) => find.byElementPredicate(
    (element) =>
        element.widget is Text &&
        (element.widget as Text).data == text &&
        Visibility.of(element),
    skipOffstage: false,
  );

  Future<void> clearCacheByTap(
    WidgetTester tester,
    String tileTitle,
    String deleteLabel,
  ) async {
    await tester.tap(storageTile(tileTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, deleteLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('操作の後は、集計し直すまでグラフも前の値を出さず、操作の欄とスクロール位置はそのまま', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    // スクロールはするが、上の端末の容量の欄も作られたままの高さ
    // （一覧は見えている範囲の少し外までしか子を作らない）。
    final l10n = await showStorageScreen(
      tester,
      providers,
      service,
      size: const Size(390, 700),
    );
    service.deviceQueries.single.complete(_device);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();

    final tile = storageTile(l10n.storageClearCacheButton);
    await tester.ensureVisible(tile);
    await tester.pump();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final scrolledTo = position.pixels;
    expect(scrolledTo, greaterThan(0));
    final tileTop = tester.getTopLeft(tile).dy;

    await clearCacheByTap(
      tester,
      l10n.storageClearCacheButton,
      l10n.commonDelete,
    );
    expect(service.cacheClears, 1);
    expect(service.scans, hasLength(2));
    expect(service.deviceQueries, hasLength(2));

    // 消す前の数字は、グラフ・凡例・行のどこにも残さない。
    expect(anywhere('123B'), findsNothing);
    expect(anywhere(l10n.storageCategoryMaterials), findsNothing);
    expect(anywhere(l10n.storageCategoryFree), findsNothing);
    // 欄そのものは残り、端末の容量・内訳・キャッシュの行・ゴミ箱の行が集計中。
    expect(anywhere(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(anywhere(l10n.storageBreakdownChartTitle), findsOneWidget);
    expect(anywhere(l10n.storageCalculating), findsNWidgets(4));
    expect(anywhere(l10n.storageActionsTitle), findsOneWidget);
    expect(anywhere(l10n.storageEraseAllButton), findsOneWidget);
    // 見ていた場所は動かない。
    expect(position.pixels, scrolledTo);
    expect(tester.getTopLeft(tile).dy, tileTop);

    // 端末の容量が先に届いても、内訳が出るまではグラフにしない。
    service.deviceQueries.last.complete(_device);
    await tester.pump();
    await tester.pump();
    expect(anywhere(l10n.storageCategoryFree), findsNothing);

    // 棒の本数が変わらなければ（キャッシュが少し残った）、集計が終わっても
    // 操作の行は動かない。
    service.scans.last.complete(storageBreakdownOf(cache: 64));
    await tester.pump();
    await tester.pump();
    expect(anywhere(l10n.storageCalculating), findsNothing);
    expect(anywhere(l10n.storageCategoryMaterials), findsOneWidget);
    expect(anywhere(l10n.storageCategoryFree), findsOneWidget);
    expect(anywhere('123B'), findsNothing);
    expect(anywhere('64B'), findsNWidgets(2));
    expect(position.pixels, scrolledTo);
    expect(tester.getTopLeft(tile).dy, tileTop);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作の前から待っていた端末の容量の答えは、操作の後のグラフに使わない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(_device);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();

    // 取り直しの問い合わせ（2つ目）が返らないうちに、キャッシュを消す。
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.deviceQueries, hasLength(2));
    service.scans.last.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await clearCacheByTap(
      tester,
      l10n.storageClearCacheButton,
      l10n.commonDelete,
    );
    // 消した後の空き容量は、あらためて問い合わせる。
    expect(service.deviceQueries, hasLength(3));

    const before = DeviceSpaceInfo(
      totalBytes: 1000 * 1024 * 1024,
      freeBytes: 100 * 1024 * 1024,
    );
    service.deviceQueries[1].complete(before);
    service.scans.last.complete(storageBreakdownOf(cache: 0));
    await tester.pump();
    await tester.pump();
    // 消す前に聞いた答え（空き100MB）ではグラフを描かない。
    expect(find.text('100.0MB'), findsNothing);
    expect(find.text(l10n.storageCategoryFree), findsNothing);

    service.deviceQueries[2].complete(_device);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text('400.0MB'), findsOneWidget);
    expect(find.text('100.0MB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('欄が集計中からグラフへ変わっても、操作の行は動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    final tiles = [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEmptyTrashButton,
      l10n.storageOrganizeProjectsButton,
      l10n.storageEraseAllButton,
    ];
    List<double> tops() => [
      for (final title in tiles) tester.getTopLeft(storageTile(title)).dy,
    ];

    // 最初のフレーム：2つの欄とも集計中。
    expect(find.text(l10n.storageCalculating), findsNWidgets(4));
    final whileCalculating = tops();

    service.deviceQueries.single.complete(_device);
    await tester.pump();
    await tester.pump();
    expect(tops(), whileCalculating);

    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text(l10n.storageCategoryMaterials), findsOneWidget);
    expect(tops(), whileCalculating);
    expect(tester.takeException(), isNull);
  });

  for (final (label, size) in [
    ('スマホの幅：円グラフの下に棒', const Size(390, 844)),
    ('広い幅：円グラフの横に棒', const Size(900, 900)),
  ]) {
    testWidgets('内訳の棒が6本あるときも、操作の後の集計中の欄はグラフと同じ高さを取る（$label）', (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      final service = ScriptedStorage();
      final l10n = await showStorageScreen(
        tester,
        providers,
        service,
        size: size,
      );
      // どの分類にも中身がある：棒が6本並び、内訳の欄は円グラフより高くなる。
      StorageBreakdown sixCategories({int cache = 2000}) => StorageBreakdown({
        StorageCategory.materials: 6000,
        StorageCategory.projectData: 5000,
        StorageCategory.exports: 4000,
        StorageCategory.customAssets: 3000,
        StorageCategory.cache: cache,
        StorageCategory.trash: 1000,
      });
      final bars = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('storageBreakdownBar_');
      }, skipOffstage: false);
      final tile = storageTile(l10n.storageClearCacheButton);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;

      service.deviceQueries.single.complete(null);
      service.scans.single.complete(sixCategories());
      await tester.pump();
      await tester.pump();
      expect(bars, findsNWidgets(6));
      await tester.ensureVisible(tile);
      await tester.pump();
      final scrolledTo = position.pixels;
      final withChart = tester.getTopLeft(tile).dy;

      await clearCacheByTap(
        tester,
        l10n.storageClearCacheButton,
        l10n.commonDelete,
      );
      // グラフは集計中の表示に替わっているが、操作の行は同じ所にある。
      expect(bars, findsNothing);
      expect(anywhere(l10n.storageCalculating), findsWidgets);
      expect(position.pixels, scrolledTo);
      expect(tester.getTopLeft(tile).dy, withChart);

      service.scans.last.complete(sixCategories(cache: 500));
      await tester.pump();
      await tester.pump();
      expect(bars, findsNWidgets(6));
      expect(position.pixels, scrolledTo);
      expect(tester.getTopLeft(tile).dy, withChart);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('消している途中で画面を閉じても、覚えている結果は捨てる', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();

    service.clearing = Completer<int>();
    await clearCacheByTap(
      tester,
      l10n.storageClearCacheButton,
      l10n.commonDelete,
    );
    expect(service.cacheClears, 1);
    expect(service.invalidations, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    service.clearing!.complete(123);
    await tester.pump();
    await tester.pump();
    expect(service.invalidations, 1);
    // 閉じた画面からは集計を始めない。
    expect(service.scans, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('終わらない集計は引っぱって更新を待たせ続けず、次の更新で新しく始める', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    await tester.pump();
    final refresh = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );

    // 始まったばかりの集計には重ねない（走っている1回を待つ）。
    unawaited(refresh.show());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.scans, hasLength(1));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    service.deviceQueries.last.complete(null);

    // 集計が返らないまま時間が過ぎたら、更新の表示は引っ込む。
    await tester.pump(_pastScanLimit);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(service.scans, hasLength(1));
    // 欄は集計中のまま（遅れて届くかもしれない結果を待っている）。
    expect(find.text(l10n.storageCalculating), findsWidgets);

    // もう一度更新すると、返らない集計を待たずに新しく始める。
    unawaited(refresh.show());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.scans, hasLength(2));
    expect(service.freshScans, [false, true]);

    service.scans.last.complete(storageBreakdownOf(cache: 512));
    service.deviceQueries.last.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('512B'), findsNWidgets(2));
    expect(find.byType(RefreshProgressIndicator), findsNothing);

    // 始め直した後に、前の集計が今ごろ終わっても表示は戻らない。
    service.scans.first.complete(storageBreakdownOf(cache: 123));
    await tester.pumpAndSettle();
    expect(find.text('123B'), findsNothing);
    expect(find.text('512B'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('時間のかかった集計でも、始め直していなければ届いた結果を出す', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    await tester.pump(_pastScanLimit);
    expect(find.text(l10n.storageCalculating), findsWidgets);

    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    expect(service.scans, hasLength(1));
    expect(find.text('123B'), findsNWidgets(2));
    expect(find.text(l10n.storageCalculating), findsNothing);

    // 終わった後の更新は、ふつうの集計として始まる。
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.freshScans, [false, false]);
    service.scans.last.complete(storageBreakdownOf());
    service.deviceQueries.last.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
