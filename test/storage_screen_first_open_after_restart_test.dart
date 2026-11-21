import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面の操作の行は、開くたびに同じ所に並ぶ。
///
/// 内訳の棒が何本になるか分からない間、画面は見込んだ本数の高さを取って
/// おき、開いている間は縮めない。以前は、どの分類に中身があったかをプロセスの
/// 中でしか覚えていなかったので、アプリを起動して最初に開いた画面だけが
/// 6本ぶんの高さを取り、2回目以降は実際の本数ぶんになった。同じ中身なのに
/// 「ゴミ箱を空にする」の行が開くたびに100px前後上下し、前に押した所を
/// 押すと何も無い所に当たった（Linuxの実画面で558px→455px）。
///
/// 前の起動で覚えた分類のうち、ひとりでに中身の有無が変わるもの（キャッシュ・
/// ゴミ箱・作品データ）は、開いたときの様子で見込む。覚えた本数のままだと、
/// キャッシュがまたたまった・ゴミ箱へ移した・起動時にゴミ箱が空になった
/// だけで、最初に開いた画面の行が結果が届いたときに動いた・2回目と違った。
///
/// 保存のキー（前の起動の記録）は、最後のテストでサービス自身が書くものと
/// 突き合わせている。
const _savedCategoriesKey = 'storage_breakdown_categories';
const _savedIncompleteKey = 'storage_breakdown_incomplete';

/// 前の起動で、中身のある分類が[categories]の内訳を集計していた記録。
Map<String, Object> _saved(
  Set<StorageCategory> categories, {
  bool incomplete = false,
}) => {
  _savedCategoriesKey: [
    for (final category in StorageCategory.values)
      if (categories.contains(category)) category.name,
  ],
  _savedIncompleteKey: incomplete,
};

/// 前の起動の記録だけを持って起動した直後のサービス。集計は1手ずつテストが
/// 答え、答えた結果は本物と同じように覚えて次に開いた画面へ渡す。覚えて
/// いない間は、本物のサービス（起動処理が読んだ前の起動の記録）に任せる。
class _RestartedStorage extends StorageInfoService {
  final scans = <Completer<StorageBreakdown>>[];
  final deviceQueries = <Completer<DeviceSpaceInfo?>>[];
  StorageBreakdown? _delivered;
  Set<String>? _deliveredTrash;

  @override
  StorageBreakdown? lastBreakdownFor(Set<String> trashedProjectIds) =>
      _delivered != null && setEquals(_deliveredTrash, trashedProjectIds)
      ? _delivered
      : super.lastBreakdownFor(trashedProjectIds);

  @override
  Set<StorageCategory>? get lastNonEmptyCategories =>
      _delivered?.nonEmptyCategories ?? super.lastNonEmptyCategories;

  @override
  Future<StorageBreakdown> computeBreakdown(
    Set<String> trashedProjectIds, {
    bool fresh = false,
  }) {
    final scan = Completer<StorageBreakdown>();
    scans.add(scan);
    return scan.future.then((breakdown) {
      _delivered = breakdown;
      _deliveredTrash = Set.of(trashedProjectIds);
      return breakdown;
    });
  }

  @override
  Future<DeviceSpaceInfo?> deviceSpace() {
    final query = Completer<DeviceSpaceInfo?>();
    deviceQueries.add(query);
    return query.future;
  }
}

/// [categories]に中身がある内訳。[incomplete]なら書き出しのフォルダを
/// 読めなかった（中身は0のまま、知らせが付く）。
StorageBreakdown _breakdownWith(
  Set<StorageCategory> categories, {
  bool incomplete = false,
}) => StorageBreakdown({
  for (final category in StorageCategory.values)
    category: categories.contains(category) ? 1024 * (category.index + 2) : 0,
}, incomplete: incomplete ? const {StorageCategory.exports} : const {});

/// 中身のある分類が2つ（作品データとキャッシュ）の内訳。
StorageBreakdown _twoBars({required bool incomplete}) => _breakdownWith(const {
  StorageCategory.projectData,
  StorageCategory.cache,
}, incomplete: incomplete);

/// 起動処理を、前の起動で保存した[saved]を持った端末として走らせる。
Future<List<SingleChildWidget>> _bootstrap(
  WidgetTester tester,
  Map<String, Object> saved,
) async {
  await loadAppFonts(tester);
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': 'ja',
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    ...saved,
  });
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return (await tester.runAsync(buildAppProviders))!;
}

/// 「ゴミ箱を空にする」の行の上端：起動して最初に開いた画面の集計中・結果の
/// 後と、同じ起動の中でもう一度開いた画面の前回の値・結果の後。
typedef _Opens = ({
  double firstCalculating,
  double firstLanded,
  double secondShown,
  double secondLanded,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-first-open-');
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

  /// 起動して最初に開き、[result]が届いたら閉じて、同じ起動の中でもう一度
  /// 開く。操作の5行の上端を、それぞれの時点で返す。
  Future<List<List<double>>> openTwice(
    WidgetTester tester,
    List<SingleChildWidget> providers,
    StorageBreakdown result, {
    required Size size,
  }) async {
    final service = _RestartedStorage();
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
    service.deviceQueries.single.complete(storageTestDevice);
    await tester.pump();
    await tester.pump();
    final firstCalculating = rowTops(tester, titles);
    service.scans.single.complete(result);
    await tester.pump();
    await tester.pump();
    final firstLanded = rowTops(tester, titles);
    expect(
      find.text(l10n.storageBreakdownIncomplete),
      result.incomplete.isEmpty ? findsNothing : findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await showStorageScreen(tester, providers, service, size: size);
    service.deviceQueries.last.complete(storageTestDevice);
    await tester.pump();
    await tester.pump();
    final secondShown = rowTops(tester, titles);
    service.scans.last.complete(result);
    await tester.pump();
    await tester.pump();
    final secondLanded = rowTops(tester, titles);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    return [firstCalculating, firstLanded, secondShown, secondLanded];
  }

  _Opens trashRow(List<List<double>> tops) => (
    firstCalculating: tops[0][2],
    firstLanded: tops[1][2],
    secondShown: tops[2][2],
    secondLanded: tops[3][2],
  );

  void expectSameEveryOpen(List<List<double>> tops) {
    expect(tops[1], tops[0], reason: '最初の画面で結果が届いた');
    expect(tops[3], tops[2], reason: '2回目の画面で結果が届いた');
    expect(tops[1], tops[3], reason: '最初に開いた画面と2回目の画面');
  }

  // 画面は縦に長く取る（どの行も作られたまま測れる。行の位置は画面の高さに
  // よらない）。
  const profiles = [
    ('390幅', Size(390, 2400), 1.0),
    ('900幅', Size(900, 2400), 1.0),
    ('320幅・文字2倍', Size(320, 3200), 2.0),
  ];

  for (final (label, size, textScale) in profiles) {
    for (final incomplete in [false, true]) {
      final notice = incomplete ? '一部を読めない知らせあり' : '知らせなし';
      testWidgets('起動して最初に開いた画面も、2回目に開いた画面と同じ所に操作の行を置く（$label・$notice）', (
        tester,
      ) async {
        final result = _twoBars(incomplete: incomplete);
        // 前の起動で開いた画面が、この内訳を集計していた。
        final providers = await _bootstrap(
          tester,
          _saved(result.nonEmptyCategories, incomplete: incomplete),
        );
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final tops = await openTwice(tester, providers, result, size: size);
        debugPrint('STORAGE FIRST OPEN $label $notice y: ${trashRow(tops)}');
        expectSameEveryOpen(tops);
      });
    }
  }

  // 前の起動で覚えた後で、中身の有無がひとりでに変わる分類。
  final changedSince = [
    (
      'キャッシュを消してから起動した（キャッシュはまたたまる）',
      const {StorageCategory.materials, StorageCategory.projectData},
      const {
        StorageCategory.materials,
        StorageCategory.projectData,
        StorageCategory.cache,
      },
      null,
    ),
    (
      '開く前に作品をゴミ箱へ移した',
      const {StorageCategory.projectData, StorageCategory.cache},
      const {
        StorageCategory.projectData,
        StorageCategory.cache,
        StorageCategory.trash,
      },
      true,
    ),
    (
      '起動時の自動削除でゴミ箱が空になった',
      const {
        StorageCategory.projectData,
        StorageCategory.cache,
        StorageCategory.trash,
      },
      const {StorageCategory.projectData, StorageCategory.cache},
      null,
    ),
    (
      '全データを削除した後に作品を作った',
      const <StorageCategory>{},
      const {StorageCategory.projectData, StorageCategory.cache},
      false,
    ),
  ];
  for (final (label, saved, now, project) in changedSince) {
    testWidgets('前の起動の後で中身の有無が変わる分類も、最初に開いた画面と2回目の画面で操作の行が同じ所（$label）', (
      tester,
    ) async {
      final providers = await _bootstrap(tester, _saved(saved));
      if (project != null) {
        // 画面を開く前の作品（[project]ならゴミ箱へ移した）。
        final projects = await storageProjectServiceOf(tester, providers);
        await addStorageTestProject(tester, projects, trashed: project);
      }
      final tops = await openTwice(
        tester,
        providers,
        _breakdownWith(now),
        size: const Size(390, 2400),
      );
      debugPrint('STORAGE CHANGED SINCE $label y: ${trashRow(tops)}');
      expectSameEveryOpen(tops);
    });
  }

  testWidgets('一部を読めなかった内訳で操作をした後、集計し直している間も結果が届いた後も操作の行は動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final incomplete = storageBreakdownOf(
      incomplete: const {StorageCategory.exports},
    );
    final service = ScriptedStorage()
      ..rememberedBreakdown = incomplete
      ..rememberedCategories = incomplete.nonEmptyCategories;
    final l10n = await showStorageScreen(tester, providers, service);
    final titles = [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEmptyTrashButton,
      l10n.storageOrganizeProjectsButton,
      l10n.storageEraseAllButton,
    ];
    service.deviceQueries.single.complete(storageTestDevice);
    service.scans.single.complete(incomplete);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
    final shown = rowTops(tester, titles);

    // キャッシュを消す：集計し直している間は、前の値と一緒に知らせも消える。
    await tester.tap(storageTile(l10n.storageClearCacheButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.scans, hasLength(2));
    expect(find.text(l10n.storageBreakdownIncomplete), findsNothing);
    final recalculating = rowTops(tester, titles);

    service.deviceQueries.last.complete(storageTestDevice);
    service.scans.last.complete(
      storageBreakdownOf(cache: 0, incomplete: const {StorageCategory.exports}),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
    final rescanned = rowTops(tester, titles);
    debugPrint(
      'STORAGE INCOMPLETE RESCAN "${titles[2]}" y: shown=${shown[2]} '
      'recalculating=${recalculating[2]} rescanned=${rescanned[2]}',
    );
    expect(recalculating, shown, reason: '集計し直している間');
    expect(rescanned, shown, reason: '集計し直した後');
    expect(tester.takeException(), isNull);
  });

  testWidgets('開いている間に初めて「一部を読み取れなかった」が付いたら、その後の集計し直しでも操作の行は動かない', (
    tester,
  ) async {
    final providers = await bootstrapStorageScreen(tester);
    // 前回の内訳には知らせが無かった（知らせの高さを取っておかずに開く）。
    final complete = storageBreakdownOf();
    final service = ScriptedStorage()
      ..rememberedBreakdown = complete
      ..rememberedCategories = complete.nonEmptyCategories;
    final l10n = await showStorageScreen(tester, providers, service);
    final titles = [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEmptyTrashButton,
      l10n.storageOrganizeProjectsButton,
      l10n.storageEraseAllButton,
    ];
    service.deviceQueries.single.complete(storageTestDevice);
    await tester.pump();
    await tester.pump();
    final opened = rowTops(tester, titles);
    // 集計し直すと、書き出しのフォルダを読めなかった（知らせが付く分、行は
    // 下へ動く：届くまで分からない）。
    service.scans.single.complete(
      storageBreakdownOf(incomplete: const {StorageCategory.exports}),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
    final noticed = rowTops(tester, titles);

    await tester.tap(storageTile(l10n.storageClearCacheButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.scans, hasLength(2));
    expect(find.text(l10n.storageBreakdownIncomplete), findsNothing);
    final recalculating = rowTops(tester, titles);

    service.deviceQueries.last.complete(storageTestDevice);
    service.scans.last.complete(
      storageBreakdownOf(cache: 0, incomplete: const {StorageCategory.exports}),
    );
    await tester.pump();
    await tester.pump();
    final rescanned = rowTops(tester, titles);
    debugPrint(
      'STORAGE NOTICE FIRST SHOWN WHILE OPEN "${titles[2]}" y: '
      'opened=${opened[2]} noticed=${noticed[2]} '
      'recalculating=${recalculating[2]} rescanned=${rescanned[2]}',
    );
    expect(recalculating, noticed, reason: '集計し直している間');
    expect(rescanned, noticed, reason: '集計し直した後');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '集計に失敗して「再試行」をキーボードで押し、一部を読めない結果が届いても、欄の中身は作り直さず、フォーカスは「再試行」に残る',
    (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      final service = ScriptedStorage();
      final l10n = await showStorageScreen(tester, providers, service);
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.completeError(StateError('unreadable'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
      final retry = find.byKey(storageBreakdownRetryKey);
      expect(await tabTo(tester, retry), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(service.scans, hasLength(2));
      final pressed = tester.element(retry);

      // この結果で初めて「一部を読み取れなかった」が付き、欄はその高さも
      // 取っておくようになる（欄の中身は作り直さない）。
      service.scans.last.complete(
        storageBreakdownOf(incomplete: const {StorageCategory.exports}),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
      expect(retry, findsOneWidget);
      expect(tester.element(retry), same(pressed), reason: '欄の中身を作り直した');
      expect(focusIsWithin(tester, retry), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // 本物の集計を走らせるので、プロセスの中の覚え（前の起動を模した上の
  // テストの前提）を変える。いちばん最後に置くこと。
  test('集計できた内訳の中身のある分類と知らせの有無を、次の起動のために保存する', () async {
    // 見込みは変わったときだけ保存するので、違う見込み（ゴミ箱だけ）を
    // 覚えた状態から始める。
    SharedPreferences.setMockInitialValues(_saved({StorageCategory.trash}));
    await StorageInfoService().restoreSavedLayout();
    SharedPreferences.setMockInitialValues({});
    final docs = Directory('${root.path}/docs')..createSync();
    final cache = Directory('${root.path}/cache')..createSync();
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path,
    );
    File('${docs.path}/niarim/projects/p/p.niapro')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(11, 1));
    File('${docs.path}/niarim/Brushes/b.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(5, 1));
    File('${cache.path}/thumb.bin').writeAsBytesSync(List<int>.filled(123, 7));

    final breakdown = await StorageInfoService().computeBreakdown({});
    expect(breakdown.nonEmptyCategoryCount, 3);
    expect(breakdown.incomplete, isEmpty);
    // 保存は集計の結果を返した後で行う。
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_savedCategoriesKey), [
      'projectData',
      'customAssets',
      'cache',
    ]);
    expect(prefs.getBool(_savedIncompleteKey), isFalse);
  });
}
