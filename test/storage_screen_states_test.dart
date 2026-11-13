import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 容量削減の画面の、欄ごとの状態（集計中・失敗・一部読めない・端末の容量の
/// 待ち切れ）と、二度押し・古い結果・画面を閉じた後の扱い。集計の進み方は
/// 差し替えたサービスで1手ずつ決めるので、実時間を待たずに確かめられる。
const _retryBreakdown = ValueKey<String>('storageBreakdownRetry');
const _retryDevice = ValueKey<String>('storageDeviceRetry');

StorageBreakdown _breakdownOf({
  int cache = 123,
  int trash = 0,
  Set<StorageCategory> incomplete = const {},
}) => StorageBreakdown({
  StorageCategory.materials: 2048,
  StorageCategory.projectData: 4096,
  StorageCategory.trash: trash,
  StorageCategory.exports: 0,
  StorageCategory.customAssets: 0,
  StorageCategory.cache: cache,
}, incomplete: incomplete);

const _device = DeviceSpaceInfo(
  totalBytes: 1000 * 1024 * 1024,
  freeBytes: 400 * 1024 * 1024,
);

/// 呼ばれるたびに、テストが後から答える`Completer`を1つ足す。
class _ScriptedStorage extends StorageInfoService {
  final scans = <Completer<StorageBreakdown>>[];
  final deviceQueries = <Completer<DeviceSpaceInfo?>>[];
  StorageBreakdown? rememberedBreakdown;
  DeviceSpaceInfo? rememberedDevice;
  int invalidations = 0;
  int cacheClears = 0;

  @override
  StorageBreakdown? get lastBreakdown => rememberedBreakdown;

  @override
  StorageBreakdown? lastBreakdownFor(Set<String> trashedProjectIds) =>
      rememberedBreakdown;

  @override
  Set<StorageCategory>? get lastNonEmptyCategories => null;

  @override
  DeviceSpaceInfo? get lastDeviceSpace => rememberedDevice;

  @override
  void invalidate() {
    invalidations++;
    rememberedBreakdown = null;
    rememberedDevice = null;
  }

  @override
  Future<StorageBreakdown> computeBreakdown(
    Set<String> trashedProjectIds, {
    bool fresh = false,
  }) {
    final scan = Completer<StorageBreakdown>();
    scans.add(scan);
    return scan.future;
  }

  @override
  Future<DeviceSpaceInfo?> deviceSpace() {
    final query = Completer<DeviceSpaceInfo?>();
    deviceQueries.add(query);
    return query.future;
  }

  /// nullでなければ、キャッシュの削除はこれが終わるまで続く。
  Completer<int>? clearing;

  @override
  Future<int> clearCache() async {
    cacheClears++;
    return clearing?.future ?? 123;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  final boundaryKey = GlobalKey();

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-states-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
    AppErrorReporter.recentErrors.clear();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  Future<List<SingleChildWidget>> bootstrap(WidgetTester tester) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    return (await tester.runAsync(buildAppProviders))!;
  }

  /// 本番と同じテーマ・スクロールの振る舞いで、画面だけを載せる。
  Future<AppLocalizations> show(
    WidgetTester tester,
    List<SingleChildWidget> providers,
    StorageInfoService service, {
    String language = 'ja',
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(
          key: UniqueKey(),
          providers: providers,
          child: Builder(
            builder: (context) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: context.watch<ThemeService>().themeData,
              scrollBehavior: const AppScrollBehavior(),
              locale: localeFromLanguageCode(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: StorageScreen(service: service),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(StorageScreen)))!;
  }

  /// いまの画面を`build/storage-states/`へ焼く（目で見て確かめるため）。
  Future<void> capture(WidgetTester tester, String name) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final out = Directory('build/storage-states')..createSync(recursive: true);
    File('${out.path}/$name.png').writeAsBytesSync(bytes!);
  }

  ListTile tile(WidgetTester tester, String title) => tester.widget<ListTile>(
    find.widgetWithText(ListTile, title, skipOffstage: false),
  );

  testWidgets('集計と端末の容量を待っている間も、操作の欄は出ていて、欄ごとに集計中になる', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);

    expect(service.scans, hasLength(1));
    expect(service.deviceQueries, hasLength(1));
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
    expect(find.text(l10n.storageActionsTitle), findsOneWidget);
    // 端末の容量の欄・内訳の欄・キャッシュの行・ゴミ箱の行。
    expect(find.text(l10n.storageCalculating), findsNWidgets(4));
    // 大きさで決まる操作は、大きさが分かるまで押せない。
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isFalse);
    expect(tile(tester, l10n.storageEmptyTrashButton).enabled, isFalse);
    // 大きさに関係ない操作は、すぐ押せる。
    expect(
      tile(tester, l10n.storageRemoveUnusedMaterialsButton).enabled,
      isTrue,
    );
    expect(tile(tester, l10n.storageOrganizeProjectsButton).enabled, isTrue);
    expect(tile(tester, l10n.storageEraseAllButton).enabled, isTrue);
    await capture(tester, 'sp_ja_1_calculating');

    // 端末の容量が先に分かっても、グラフは内訳が出るまで待つ（その欄だけ）。
    service.deviceQueries.single.complete(_device);
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsNothing);
    expect(find.text(l10n.storageCalculating), findsNWidgets(4));

    service.scans.single.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCalculating), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text('123B'), findsNWidgets(2));
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isTrue);
    // ゴミ箱は空（0B）なので押せない。
    expect(tile(tester, l10n.storageEmptyTrashButton).enabled, isFalse);
    expect(find.text('0B'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'sp_ja_2_ready');
  });

  testWidgets('この端末では容量を取得できない（答えがnull）なら、欄ごと出さない', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);

    service.deviceQueries.single.complete(null);
    service.scans.single.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageDeviceChartTitle), findsNothing);
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    expect(find.byKey(_retryDevice), findsNothing);
    expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
    // 待ちのタイマーは答えが届いた時点で止まっている。
    await tester.pump(storageDeviceSpaceTimeout * 2);
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末の容量の待ちが切れたら知らせを出し、後から届いた答えは使う', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.scans.single.complete(_breakdownOf());
    await tester.pump();

    await tester.pump(
      storageDeviceSpaceTimeout - const Duration(milliseconds: 100),
    );
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsOneWidget);
    expect(find.byKey(_retryDevice), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await capture(tester, 'sp_ja_3_device_timed_out');

    // 問い合わせ直していないので、遅れて届いた最初の答えをそのまま使う。
    service.deviceQueries.single.complete(_device);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    expect(find.byKey(_retryDevice), findsNothing);
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末の容量をやり直した後は、前の問い合わせの答えを使わない', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.scans.single.complete(_breakdownOf());
    await tester.pump(storageDeviceSpaceTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_retryDevice), findsOneWidget);

    // 二度押ししても、問い合わせは1つだけ増える。
    await tester.tap(find.byKey(_retryDevice));
    await tester.tap(find.byKey(_retryDevice), warnIfMissed: false);
    await tester.pump();
    expect(service.deviceQueries, hasLength(2));
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    expect(find.text(l10n.storageCalculating), findsOneWidget);

    // 1回目の答え（nullなら欄が消える）が今ごろ届いても、何も変わらない。
    service.deviceQueries.first.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(find.text(l10n.storageCalculating), findsOneWidget);

    service.deviceQueries.last.complete(_device);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text(l10n.storageCalculating), findsNothing);
    await tester.pump(storageDeviceSpaceTimeout * 2);
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('集計に失敗したら文とやり直しを出し、二度押ししても集計は1回だけ始まる', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(_device);

    service.scans.single.completeError(
      const FileSystemException('secret/path/of/the/failure'),
      StackTrace.current,
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
    // 例外の文そのものは画面に出さず、エラーの記録にだけ残す。
    expect(find.textContaining('secret/path'), findsNothing);
    expect(find.textContaining('FileSystemException'), findsNothing);
    expect(
      AppErrorReporter.recentErrors.where((e) => e.contains('secret/path')),
      hasLength(1),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // 内訳が無いと端末の容量のグラフは描けない。欄の場所は取ったまま
    // （やり直すたびに欄が出入りして下が動かないように）、棒は出さない。
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(find.text(l10n.storageCategoryFree), findsNothing);
    expect(find.byIcon(Icons.donut_large), findsOneWidget);
    // 大きさが分からないので、数字も「集計中」も出さず、押せない。
    final clearCache = tile(tester, l10n.storageClearCacheButton);
    expect(clearCache.enabled, isFalse);
    expect((clearCache.subtitle! as Text).data, isEmpty);
    expect(tile(tester, l10n.storageEraseAllButton).enabled, isTrue);
    await capture(tester, 'sp_ja_4_breakdown_failed');

    // 知らせは読み上げられ、色ではなくアイコンで示す（本文と同じ色）。
    final message = find.text(l10n.storageBreakdownLoadFailed);
    expect(
      find.ancestor(
        of: message,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    final theme = Theme.of(tester.element(message));
    final bodyColor = theme.textTheme.bodyMedium!.color;
    expect(
      tester.renderObject<RenderParagraph>(message).text.style!.color,
      bodyColor,
    );
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(of: message, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.error_outline),
      ),
    );
    expect(icon.color, bodyColor);
    expect(bodyColor, isNot(theme.colorScheme.error));

    await tester.tap(find.byKey(_retryBreakdown));
    await tester.tap(find.byKey(_retryBreakdown), warnIfMissed: false);
    await tester.pump();
    expect(service.scans, hasLength(2));
    // やり直している間は、失敗の文の代わりに集計中と出す。ボタンは結果が
    // 届くまで同じ所に残る。
    expect(find.text(l10n.storageBreakdownLoadFailed), findsNothing);
    expect(find.byKey(_retryBreakdown), findsOneWidget);
    expect(find.text(l10n.storageCalculating), findsWidgets);

    service.scans.last.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text('123B'), findsNWidgets(2));
    expect(find.text(l10n.storageBreakdownLoadFailed), findsNothing);
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('どの分類も読めなかった結果は、0のグラフではなく失敗として出す', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(
      StorageBreakdown(const {}, incomplete: StorageCategory.values.toSet()),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
    expect(find.text(l10n.storageBreakdownIncomplete), findsNothing);
    expect(find.byIcon(Icons.donut_large), findsNothing);
    expect(find.byKey(_retryBreakdown), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一部を読めなかった内訳は、読めた分のグラフと知らせを出す', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(
      _breakdownOf(
        cache: 0,
        trash: 2048,
        incomplete: {StorageCategory.cache, StorageCategory.trash},
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
    expect(find.text(l10n.storageBreakdownLoadFailed), findsNothing);
    expect(find.text(l10n.storageCategoryMaterials), findsOneWidget);
    // 読めなかった分類で0のものは、0Bと言い切らない。
    final clearCache = tile(tester, l10n.storageClearCacheButton);
    expect(clearCache.enabled, isFalse);
    expect((clearCache.subtitle! as Text).data, isEmpty);
    // 読めた分があるものは、その分を出して押せる。
    final emptyTrash = tile(tester, l10n.storageEmptyTrashButton);
    expect(emptyTrash.enabled, isTrue);
    expect((emptyTrash.subtitle! as Text).data, '2.0KB');
    await capture(tester, 'sp_ja_5_breakdown_incomplete');

    // やり直している間もボタンは押せるまま残り、重ねて押しても集計は増えない。
    await tester.tap(find.byKey(_retryBreakdown));
    await tester.pump();
    expect(service.scans, hasLength(2));
    expect(
      tester.widget<TextButton>(find.byKey(_retryBreakdown)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(_retryBreakdown));
    await tester.pump();
    expect(service.scans, hasLength(2));
    service.scans.last.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownIncomplete), findsNothing);
    expect(find.byKey(_retryBreakdown), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('開き直したときは前回の値を最初のフレームから出し、裏で集計し直す', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage()
      ..rememberedBreakdown = _breakdownOf()
      ..rememberedDevice = _device;
    final l10n = await show(tester, providers, service);

    expect(find.text('123B'), findsNWidgets(2));
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text(l10n.storageCalculating), findsNothing);
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isTrue);
    // 取り直している印は、見出しの横の小さな表示だけ（欄ごとに1つ）。
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(service.scans, hasLength(1));
    expect(service.deviceQueries, hasLength(1));
    await capture(tester, 'sp_ja_6_reopened_first_frame');

    service.deviceQueries.single.complete(_device);
    service.scans.single.complete(_breakdownOf(cache: 2048));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('123B'), findsNothing);
    expect(find.text('2.0KB'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('引っぱって更新しても本文は出たままで、走っている集計に重ねて始めない', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(_device);
    service.scans.single.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();

    final refresh = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(refresh.show());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.scans, hasLength(2));
    expect(service.deviceQueries, hasLength(2));
    expect(find.text('123B'), findsNWidgets(2));
    expect(find.text(l10n.storageActionsTitle), findsOneWidget);
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isTrue);

    // 集計が終わる前にもう一度更新しても、新しい走査は始めない。
    unawaited(refresh.show());
    await tester.pump();
    expect(service.scans, hasLength(2));
    expect(service.deviceQueries, hasLength(2));

    service.deviceQueries.last.complete(_device);
    service.scans.last.complete(_breakdownOf(cache: 2048));
    await tester.pumpAndSettle();
    expect(find.text('2.0KB'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作の後は集計し直し、その間は前の値で操作させず、古い集計の結果は捨てる', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(_device);
    service.scans.single.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();

    // 更新の集計（2つ目）が走っている間にキャッシュを消す。
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(service.scans, hasLength(2));
    service.deviceQueries.last.complete(_device);

    // 同じフレームの中で2回実行されても（キーボードの連打。ポインターの
    // 二度押しはNavigatorが止めるので、行の処理を直接呼ぶ）、確かめる
    // ダイアログは1つ。
    final activate = tile(tester, l10n.storageClearCacheButton).onTap!;
    activate();
    activate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    // ダイアログが開いている間、下の行は押せる見た目のまま（押せなくすると
    // キーボードのフォーカスがダイアログへ移らない）。ほかの操作を実行
    // しても受け付けない。
    expect(tile(tester, l10n.storageEraseAllButton).enabled, isTrue);
    tile(tester, l10n.storageEraseAllButton).onTap!();
    tile(tester, l10n.storageRemoveUnusedMaterialsButton).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.storageEraseAllConfirmTitle), findsNothing);

    // 消している間（ダイアログは閉じている）も、ほかの操作は始められない。
    // 見出しの横に処理中の印が出る。
    final working = find.byWidgetPredicate(
      (w) =>
          w is CircularProgressIndicator &&
          w.semanticsLabel == l10n.homeTrashWorking,
    );
    expect(working, findsNothing);
    service.clearing = Completer<int>();
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.cacheClears, 1);
    expect(service.scans, hasLength(2));
    expect(working, findsOneWidget);
    tile(tester, l10n.storageEraseAllButton).onTap!();
    tile(tester, l10n.storageClearCacheButton).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.cacheClears, 1);

    service.clearing!.complete(123);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.invalidations, 1);
    // 走っていた集計は消す前のディスクを見ているので、始め直す。
    expect(service.scans, hasLength(3));
    expect(working, findsNothing);
    // 欄は出たまま。消す前の値はグラフにも出さず、前の値で決まる操作は
    // 集計し直すまで止める。
    expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
    expect(find.text(l10n.storageCategoryMaterials), findsNothing);
    expect(find.text('123B'), findsNothing);
    final busyTile = tile(tester, l10n.storageClearCacheButton);
    expect(busyTile.enabled, isFalse);
    expect((busyTile.subtitle! as Text).data, l10n.storageCalculating);
    expect(tile(tester, l10n.storageEraseAllButton).enabled, isTrue);
    await capture(tester, 'sp_ja_7_recalculating_after_action');

    service.scans[2].complete(_breakdownOf(cache: 0));
    await tester.pump();
    await tester.pump();
    final cleared = tile(tester, l10n.storageClearCacheButton);
    expect(cleared.enabled, isFalse);
    expect((cleared.subtitle! as Text).data, '0B');

    // 消す前に始まった集計が後から終わっても、表示は戻らない。
    service.scans[1].complete(_breakdownOf(cache: 123));
    await tester.pumpAndSettle();
    expect(find.text('123B'), findsNothing);
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作の後の集計に失敗したら、消す前の内訳は残さない', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ListTile, l10n.storageClearCacheButton),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.scans, hasLength(2));

    service.scans.last.completeError(StateError('scan failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
    expect(find.text(l10n.storageCategoryMaterials), findsNothing);
    expect(find.text('123B'), findsNothing);
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('確かめるダイアログを取り消したら、集計し直さず操作は元どおり押せる', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    final l10n = await show(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(_breakdownOf());
    await tester.pump();
    await tester.pump();

    final eraseAll = find.widgetWithText(ListTile, l10n.storageEraseAllButton);
    await tester.ensureVisible(eraseAll);
    await tester.pump();
    await tester.tap(eraseAll);
    await tester.tap(eraseAll, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.scans, hasLength(1));
    expect(service.invalidations, 0);
    expect(tile(tester, l10n.storageEraseAllButton).enabled, isTrue);
    expect(tile(tester, l10n.storageClearCacheButton).enabled, isTrue);
    expect(find.text('123B'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('集計・問い合わせの途中で画面を閉じても、後から届いた結果で例外にならない', (tester) async {
    final providers = await bootstrap(tester);
    final service = _ScriptedStorage();
    await show(tester, providers, service);

    await tester.pumpWidget(const SizedBox.shrink());
    service.scans.single.complete(_breakdownOf());
    service.deviceQueries.single.complete(_device);
    await tester.pump();
    // 待ちのタイマーは画面と一緒に止まっている（残っていればテストが落ちる）。
    await tester.pump(storageDeviceSpaceTimeout * 2);
    expect(tester.takeException(), isNull);

    // 失敗で終わる場合も同じ。
    final second = _ScriptedStorage();
    await show(tester, providers, second);
    await tester.pumpWidget(const SizedBox.shrink());
    second.scans.single.completeError(StateError('late failure'));
    second.deviceQueries.single.completeError(StateError('late failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('失敗・一部読めない・待ち切れの知らせは、狭い画面・文字2倍でもはみ出さず、やり直しを押せる', (tester) async {
    final providers = await bootstrap(tester);
    var profiles = 0;
    for (final language in ['ja', 'en', 'fr']) {
      for (final size in [const Size(320, 844), const Size(390, 220)]) {
        for (final failed in [false, true]) {
          final profile = '$language/$size/${failed ? 'failed' : 'incomplete'}';
          final service = _ScriptedStorage();
          final l10n = await show(
            tester,
            providers,
            service,
            language: language,
            size: size,
            textScale: 2,
          );
          // 集計中の表示もこの大きさで並ぶ。
          expect(tester.takeException(), isNull, reason: '$profile 集計中');
          if (failed) {
            service.scans.single.completeError(StateError('unreadable'));
          } else {
            service.scans.single.complete(
              _breakdownOf(incomplete: {StorageCategory.exports}),
            );
          }
          await tester.pump(storageDeviceSpaceTimeout);
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: profile);
          final shot =
              'x2_${language}_${size.width.round()}x${size.height.round()}_'
              '${failed ? 'failed' : 'incomplete'}';
          await capture(tester, '${shot}_top');

          final notices = [
            (
              l10n.storageDeviceSpaceUnavailable,
              _retryDevice,
              const ValueKey('storageDeviceNotice'),
            ),
            (
              failed
                  ? l10n.storageBreakdownLoadFailed
                  : l10n.storageBreakdownIncomplete,
              _retryBreakdown,
              const ValueKey('storageBreakdownNotice'),
            ),
          ];
          for (final (message, retryKey, noticeKey) in notices) {
            // 出している知らせの文（欄が高さを測るために並べる、描かない
            // 見本の知らせは数えない）。
            final text = find.descendant(
              of: find.byKey(noticeKey, skipOffstage: false),
              matching: find.text(message, skipOffstage: false),
              skipOffstage: false,
            );
            await tester.scrollUntilVisible(text, 80, maxScrolls: 60);
            expect(tester.takeException(), isNull, reason: '$profile $message');
            // 文は省略されず、欄の幅に収まる。
            final paragraph = tester.renderObject<RenderParagraph>(text);
            expect(paragraph.didExceedMaxLines, isFalse, reason: profile);
            final list = tester.getRect(find.byType(ListView));
            final box = tester.getRect(text);
            expect(box.left, greaterThanOrEqualTo(list.left), reason: profile);
            expect(box.right, lessThanOrEqualTo(list.right), reason: profile);

            final retry = find.byKey(retryKey, skipOffstage: false);
            await tester.scrollUntilVisible(retry, 80, maxScrolls: 60);
            await tester.ensureVisible(retry);
            await tester.pump();
            expect(retry.hitTestable(), findsOneWidget, reason: profile);
            expect(
              find.descendant(
                of: retry,
                matching: find.text(l10n.communityRetry),
              ),
              findsOneWidget,
              reason: profile,
            );
            final button = tester.getRect(retry);
            expect(
              button.right,
              lessThanOrEqualTo(list.right),
              reason: profile,
            );
            expect(
              button.left,
              greaterThanOrEqualTo(list.left),
              reason: profile,
            );
          }
          await capture(tester, '${shot}_breakdown_retry');
          // 操作の欄は最後までスクロールして届く。
          final eraseAll = find.text(
            l10n.storageEraseAllButton,
            skipOffstage: false,
          );
          await tester.scrollUntilVisible(eraseAll, 120, maxScrolls: 60);
          await tester.ensureVisible(eraseAll);
          await tester.pump();
          expect(eraseAll.hitTestable(), findsOneWidget, reason: profile);
          expect(tester.takeException(), isNull, reason: profile);
          profiles++;
        }
      }
    }
    expect(profiles, 12);
  });
}
