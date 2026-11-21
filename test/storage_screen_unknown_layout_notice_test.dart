import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/storage_info_service.dart';

import 'helpers/storage_screen_harness.dart';

/// 並びの見込みを何も覚えていない端末（入れたばかり・データを消した・
/// 見込みを保存するようになった版へ更新して最初に開いた）で容量削減の画面を
/// 開き、届いた内訳に「一部のデータを読み取れなかった」の知らせが付いても、
/// 下の操作の行は動かない。
///
/// 何も覚えていない画面は、分類の数（6本）の棒の高さを取って待つ。届いた
/// 内訳が2本と知らせなら、ふつうはその高さに収まる。以前は知らせが付いた
/// 結果が届くと、取っておいた6本の下に知らせの高さを足したので、行がその
/// 分だけ下へ動いた（Linuxの実画面：1280×800で558→622、360幅で562→646）。
/// 文字が大きく幅の狭い画面では知らせが棒4本より高くなり、収まらない分
/// だけは動く（何も覚えていない画面で、6本の下に知らせの高さまで取って
/// おくかは決めていない）。
///
/// あわせて、キャッシュの行が押せるようになって右端の矢印が出ても、行の
/// 高さが変わらないこと（文字2倍・360幅で名前が2行に折れ、下の行が28px
/// 動いた）と、開いている間に知らせを取っておく決まり（集計し直す間に
/// 知らせが消えても行が上へ動かない）も確かめる。
StorageBreakdown _twoBarsWithNotice({int cache = 123}) => StorageBreakdown(
  {
    StorageCategory.materials: 0,
    StorageCategory.projectData: 4096,
    StorageCategory.trash: 0,
    StorageCategory.exports: 0,
    StorageCategory.customAssets: 0,
    StorageCategory.cache: cache,
  },
  incomplete: const {StorageCategory.exports},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-unknown-layout-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  const profiles = [('1280×800', Size(1280, 800)), ('360×740', Size(360, 740))];

  for (final (label, size) in profiles) {
    for (final language in ['ja', 'fr']) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('何も覚えていない画面で、知らせ付きの内訳が届いても操作の行は動かない'
            '（$label・$language・文字$textScale倍）', (tester) async {
          final providers = await bootstrapStorageScreen(tester);
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          // 前回の内訳も、並びの見込みも無い。
          final service = ScriptedStorage();
          final l10n = await showStorageScreen(
            tester,
            providers,
            service,
            size: size,
            language: language,
          );
          final trashRow = storageTile(l10n.storageEmptyTrashButton);
          final cacheRow = storageTile(l10n.storageClearCacheButton);
          final list = find.byType(Scrollable).first;
          double scrolled() =>
              tester.state<ScrollableState>(list).position.pixels;
          // 一覧の中での行の上端（操作のために一覧を送っても比べられる）。
          double trashTop() => tester.getTopLeft(trashRow).dy + scrolled();
          // 一覧を送った後は、知らせが画面の上に隠れていることがある。
          final notice = find.byKey(
            const ValueKey('storageBreakdownNotice'),
            skipOffstage: false,
          );
          final block = find.descendant(
            of: find.byKey(
              const ValueKey('storageBreakdownSection'),
              skipOffstage: false,
            ),
            matching: find.byType(IndexedStack, skipOffstage: false),
          );

          service.deviceQueries.single.complete(storageTestDevice);
          await tester.pump();
          await tester.pump();
          expect(notice, findsNothing);
          final calculating = trashTop();
          final cacheRowHeight = tester.getSize(cacheRow).height;
          // 集計中に取っておいた内訳の欄の高さ（分類の数の棒）。
          final reserved = tester.getSize(block).height;

          service.scans.single.complete(_twoBarsWithNotice());
          await tester.pump();
          await tester.pump();
          expect(notice, findsOneWidget);
          final landed = trashTop();
          // 届いた内訳（2本の棒と知らせ）が、欄の中で占める高さ。
          final shown =
              tester.getBottomLeft(notice).dy - tester.getTopLeft(block).dy;
          // 行が動いてよいのは、届いた内訳が取っておいた高さに収まらない
          // 分だけ（文字が大きく幅が狭いと、知らせが棒4本より高くなる）。
          // 以前は収まっていても、取っておいた棒の下に知らせの高さを足した。
          final overflow = math.max(0.0, shown - reserved);
          final cacheRowLanded = tester.getSize(cacheRow).height;

          // キャッシュを消す：集計し直している間は、前の値と一緒に知らせも
          // 消える（狭い画面では行が画面の外なので、一覧を送ってから押す）。
          await tester.ensureVisible(cacheRow);
          await tester.pump();
          await tester.tap(cacheRow);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(
            find.widgetWithText(FilledButton, l10n.commonDelete),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(service.scans, hasLength(2));
          expect(notice, findsNothing);
          final recalculating = trashTop();
          final scrolledWhileRecalculating = scrolled();
          final cacheRowRecalculating = tester.getSize(cacheRow).height;

          service.deviceQueries.last.complete(storageTestDevice);
          service.scans.last.complete(_twoBarsWithNotice(cache: 0));
          await tester.pump();
          await tester.pump();
          expect(notice, findsOneWidget);
          final rescanned = trashTop();
          debugPrint(
            'STORAGE UNKNOWN LAYOUT NOTICE $label $language x$textScale '
            '"${l10n.storageEmptyTrashButton}" y: calculating=$calculating '
            'landed=$landed recalculating=$recalculating '
            'rescanned=$rescanned (reserved=$reserved shown=$shown '
            'overflow=$overflow) cache row height: '
            '$cacheRowHeight→$cacheRowLanded→$cacheRowRecalculating',
          );
          // キャッシュの行が押せるようになって矢印が出ても、行の高さは同じ。
          expect(cacheRowLanded, cacheRowHeight, reason: 'キャッシュの行（結果）');
          expect(
            cacheRowRecalculating,
            cacheRowHeight,
            reason: 'キャッシュの行（集計し直している間）',
          );
          expect(landed - calculating, overflow, reason: '最初の結果が届いた');
          expect(recalculating, landed, reason: '操作の後で集計し直している間');
          expect(rescanned, landed, reason: '集計し直した結果が届いた');
          // 一覧の送り位置も変わらない（欄が縮んで送り位置が詰められると、
          // 一覧の中の位置が同じでも画面の上で行が動く）。
          expect(scrolled(), scrolledWhileRecalculating);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
