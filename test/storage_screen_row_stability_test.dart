import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';

import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面の操作の行は、集計・問い合わせの途中の表示（見出しの横の
/// 進行中の印・「集計中…」の行・知らせ）と結果が入れ替わっても、指の下で
/// 動かない。
///
/// 欄は結果と同じ高さを取って待ち、開いている間は縮めない。以前は次の場面で
/// 取っておく高さが足りず・縮み、行が上下に動いた（レビューで実測）：
/// - 「作品を整理する」からホームへ行き、作品をゴミ箱へ移して戻った：集計し
///   直した結果にゴミ箱の棒が増え、届いたときに行が42px下へ動いた（戻った
///   時点で、ゴミ箱に作品があることは分かっていた）。
/// - 見出しの横の進行中の印（14px）が見出しの幅を狭め、フランス語・スペイン
///   語の大きな文字では見出しが2行に折れた。印が消えると26〜40px上へ動いた。
/// - 作品が無い端末（キャッシュの棒1本＝42px）で、文字が大きいと「集計中…」の
///   行がそれより高く、結果が届くたびに4〜20px上へ動いた。
/// - 集計できなかった・待ち切れ（30秒）の知らせ：出たときに行が下へ動き、
///   やり直しで文が「集計中…」に替わると縮み、結果が届くとまた縮んだ。
/// - 端末の容量の問い合わせの待ち切れの知らせが、文字2倍・狭い幅では棒3本
///   より高く、4秒で10〜14px下へ動いて答えで戻った。
/// - 韓国語・中国語の「集計中…」の行の下の文が、届いた大きさ（数字）より
///   1〜2px高く、結果が届くとその下の行が1〜4px上へ動いた。
///
/// 前もって分からない知らせ（集計できなかった・待ち切れ）は、出た時点では
/// 行が動いてよい（いつも取っておくと、ふだんの画面に知らせの高さの空きが
/// 残る）。出た後は、文が替わっても・結果が届いても閉じるまで縮めない。
StorageBreakdown _with(
  Set<StorageCategory> categories, {
  Set<StorageCategory> incomplete = const {},
}) => StorageBreakdown({
  for (final c in StorageCategory.values)
    c: categories.contains(c) ? 1024 * (c.index + 2) : 0,
}, incomplete: incomplete);

const _three = {
  StorageCategory.materials,
  StorageCategory.projectData,
  StorageCategory.cache,
};
const _two = {StorageCategory.projectData, StorageCategory.cache};
const _cacheOnly = {StorageCategory.cache};

List<String> _titles(AppLocalizations l10n) => [
  l10n.storageClearCacheButton,
  l10n.storageRemoveUnusedMaterialsButton,
  l10n.storageEmptyTrashButton,
  l10n.storageOrganizeProjectsButton,
  l10n.storageEraseAllButton,
];

double _scrolled(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(StorageScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .pixels;

/// 操作の行の、一覧の中での上端（一覧を送っても比べられる）。
List<double> _rows(WidgetTester tester, AppLocalizations l10n) => [
  for (final t in _titles(l10n))
    tester.getTopLeft(storageTile(t)).dy + _scrolled(tester),
];

String _fmt(List<double> r) => r.map((v) => v.toStringAsFixed(0)).join('/');

/// [steps]の各段で行が同じ所にあるか。違えば失敗の一覧へ1行足す。
void _same(
  List<String> failures,
  String label,
  Map<String, List<double>> steps,
) {
  final line =
      '$label ${steps.entries.map((e) => '${e.key}=${_fmt(e.value)}').join(' ')}';
  debugPrint('STORAGE ROWS $line');
  final first = steps.values.first;
  for (final step in steps.values.skip(1)) {
    for (var i = 0; i < first.length; i++) {
      if ((step[i] - first[i]).abs() > 0.01) {
        failures.add(line);
        return;
      }
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-row-stability-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('「作品を整理する」でゴミ箱へ移して戻ると、集計し直した結果が届いても'
        '行は動かない（文字$textScale倍）', (tester) async {
      final providers = await bootstrapStorageScreen(tester);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final projects = await storageProjectServiceOf(tester, providers);
      await addStorageTestProject(tester, projects);
      final toTrash = await addStorageTestProject(tester, projects);
      final service = ScriptedStorage()..rememberedCategories = _two;
      tester.view.physicalSize = const Size(390, 844);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => StorageScreen(service: service),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          key: UniqueKey(),
          providers: providers,
          child: Builder(
            builder: (context) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: context.watch<ThemeService>().themeData,
              scrollBehavior: const AppScrollBehavior(),
              locale: localeFromLanguageCode('ja'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(StorageScreen)),
      )!;
      service.deviceQueries.single.complete(storageTestDevice);
      service.scans.single.complete(_with(_two));
      await _settle(tester);
      final shown = _rows(tester, l10n);

      final organize = storageTile(l10n.storageOrganizeProjectsButton);
      await tester.ensureVisible(organize);
      await tester.pump();
      await tester.tap(organize);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('home'), findsOneWidget);
      // ホームで2つのうち1つの作品をゴミ箱へ移して戻る。
      await tester.runAsync(() => projects.deleteProject(toTrash));
      router.pop();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(service.scans, hasLength(2));
      expect(projects.trash, isNotEmpty);
      final recalculating = _rows(tester, l10n);

      service.deviceQueries.last.complete(storageTestDevice);
      service.scans.last.complete(_with({..._two, StorageCategory.trash}));
      await _settle(tester);
      final landed = _rows(tester, l10n);
      final failures = <String>[];
      _same(failures, 'organize x$textScale (shown=${_fmt(shown)})', {
        'recalculating': recalculating,
        'landed': landed,
      });
      expect(failures, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('取り直している間の見出しの横の印で見出しが折れず、印が消えても行は動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final failures = <String>[];
    for (final (language, width, textScale) in [
      ('fr', 360.0, 2.0),
      ('fr', 390.0, 2.0),
      ('es', 360.0, 1.3),
      ('es', 360.0, 2.0),
      ('ja', 360.0, 2.0),
    ]) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      // 同じプロセスで2回目に開いた：前回の内訳と空き容量を出したまま、
      // どちらも取り直す（見出しの横に印が出る）。
      final service = ScriptedStorage()
        ..rememberedBreakdown = _with(_three)
        ..rememberedCategories = _three
        ..rememberedDevice = storageTestDevice;
      final l10n = await showStorageScreen(
        tester,
        providers,
        service,
        size: Size(width, 800),
        language: language,
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNWidgets(2),
      );
      final loading = _rows(tester, l10n);
      service.deviceQueries.single.complete(storageTestDevice);
      await _settle(tester);
      final deviceAnswered = _rows(tester, l10n);
      service.scans.single.complete(_with(_three));
      await _settle(tester);
      final result = _rows(tester, l10n);
      _same(failures, 'titles $language w=$width x$textScale', {
        'loading': loading,
        'deviceAnswered': deviceAnswered,
        'result': result,
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('棒1本の端末で文字が大きくても、「集計中…」の行と結果・キャッシュの削除で行は動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final failures = <String>[];
    for (final language in ['ja', 'fr', 'ko']) {
      for (final textScale in [1.5, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        // 作品の無い端末（入れて最初に集計した後・全データの削除の後）。
        final service = ScriptedStorage()..rememberedCategories = _cacheOnly;
        final l10n = await showStorageScreen(
          tester,
          providers,
          service,
          size: const Size(360, 740),
          language: language,
        );
        service.deviceQueries.single.complete(storageTestDevice);
        await _settle(tester);
        final calculating = _rows(tester, l10n);
        service.scans.single.complete(_with(_cacheOnly));
        await _settle(tester);
        final landed = _rows(tester, l10n);

        final cacheRow = storageTile(l10n.storageClearCacheButton);
        await tester.ensureVisible(cacheRow);
        await tester.pump();
        await tester.tap(cacheRow);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(service.scans, hasLength(2));
        final recalculating = _rows(tester, l10n);
        service.deviceQueries.last.complete(storageTestDevice);
        service.scans.last.complete(_with(_cacheOnly));
        await _settle(tester);
        final rescanned = _rows(tester, l10n);
        _same(failures, 'one bar $language x$textScale', {
          'calculating': calculating,
          'landed': landed,
          'recalculating': recalculating,
          'rescanned': rescanned,
        });
        // 消した知らせを閉じてから次の場面へ。
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('集計できなかった知らせは、キーボードでやり直す間も結果が届いても縮まない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final failures = <String>[];
    for (final language in ['ja', 'fr', 'ko']) {
      for (final width in [360.0, 390.0]) {
        for (final textScale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          final service = ScriptedStorage()..rememberedCategories = _two;
          final l10n = await showStorageScreen(
            tester,
            providers,
            service,
            size: Size(width, 800),
            language: language,
          );
          service.deviceQueries.single.complete(storageTestDevice);
          await _settle(tester);
          service.scans.single.completeError(Exception('scan failed'));
          await _settle(tester);
          expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
          final retry = find.byKey(storageBreakdownRetryKey);
          await tester.ensureVisible(retry);
          await tester.pump();
          expect(await tabTo(tester, retry), isTrue);
          final failed = _rows(tester, l10n);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await _settle(tester);
          expect(service.scans, hasLength(2));
          final retrying = _rows(tester, l10n);
          final kept = focusIsWithin(tester, retry);
          service.scans.last.complete(_with(_two));
          await _settle(tester);
          final result = _rows(tester, l10n);
          // やり直しは端末の容量も問い合わせ直す（その答えでも動かない）。
          service.deviceQueries.last.complete(storageTestDevice);
          await _settle(tester);
          final deviceAnswered = _rows(tester, l10n);
          _same(failures, 'failed $language w=$width x$textScale', {
            'failed': failed,
            'retrying': retrying,
            'result': result,
            'deviceAnswered': deviceAnswered,
          });
          if (!kept) failures.add('focus lost $language w=$width x$textScale');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('待ち切れ（30秒）の知らせは、結果が届いても縮まない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final failures = <String>[];
    for (final language in ['ja', 'fr']) {
      for (final remembered in [_cacheOnly, _two]) {
        for (final textScale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          final service = ScriptedStorage()..rememberedCategories = remembered;
          final l10n = await showStorageScreen(
            tester,
            providers,
            service,
            size: const Size(360, 800),
            language: language,
          );
          service.deviceQueries.single.complete(storageTestDevice);
          await _settle(tester);
          final block = find.descendant(
            of: find.byKey(const ValueKey('storageBreakdownSection')),
            matching: find.byType(IndexedStack),
          );
          final calculating = _rows(tester, l10n);
          final reserved = tester.getSize(block).height;
          await tester.pump(storageScanShareLimit + const Duration(seconds: 1));
          await tester.pump();
          expect(find.byKey(storageBreakdownRetryKey), findsOneWidget);
          final overdue = _rows(tester, l10n);
          // 知らせが出たときに動いてよいのは、取っておいた高さに収まらない
          // 分だけ（まだ出ていない「集計できなかった」の文の高さまで取ると、
          // その分だけ余計に動き、結果の下に空きが残る）。
          final notice = find.byKey(const ValueKey('storageBreakdownNotice'));
          final shown =
              tester.getBottomLeft(notice).dy - tester.getTopLeft(block).dy;
          final overflow = math.max(0.0, shown - reserved);
          service.scans.last.complete(_with(remembered));
          await _settle(tester);
          final result = _rows(tester, l10n);
          final label =
              'overdue $language bars=${remembered.length} x$textScale';
          _same(failures, label, {'overdue': overdue, 'result': result});
          final moved = overdue[0] - calculating[0];
          if ((moved - overflow).abs() > 0.01) {
            failures.add('$label moved=$moved overflow=$overflow');
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末の容量の待ち切れの知らせが出ても・答えが届いても行は動かない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final failures = <String>[];
    for (final language in ['ja', 'fr', 'ko']) {
      for (final width in [320.0, 360.0, 390.0]) {
        for (final textScale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          final service = ScriptedStorage()..rememberedCategories = _two;
          final l10n = await showStorageScreen(
            tester,
            providers,
            service,
            size: Size(width, 800),
            language: language,
          );
          service.scans.single.complete(_with(_two));
          await _settle(tester);
          final waiting = _rows(tester, l10n);
          await tester.pump(
            storageDeviceSpaceTimeout + const Duration(milliseconds: 100),
          );
          await tester.pump();
          expect(find.byKey(storageDeviceRetryKey), findsOneWidget);
          final timedOut = _rows(tester, l10n);
          service.deviceQueries.single.complete(storageTestDevice);
          await _settle(tester);
          final answered = _rows(tester, l10n);

          // グラフを出したまま問い合わせ直して（引っぱって更新）、また待ち
          // 切れになった：知らせはグラフの下に出る（出たときは動いてよい）。
          final refresh = tester.state<RefreshIndicatorState>(
            find.byType(RefreshIndicator),
          );
          refresh.show();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          service.scans.last.complete(_with(_two));
          await _settle(tester);
          await tester.pump(storageDeviceSpaceTimeout);
          await tester.pump();
          expect(find.byKey(storageDeviceRetryKey), findsOneWidget);
          final timedOutBelowChart = _rows(tester, l10n);
          service.deviceQueries.last.complete(storageTestDevice);
          await _settle(tester);
          final answeredAgain = _rows(tester, l10n);
          _same(failures, 'device $language w=$width x$textScale', {
            'waiting': waiting,
            'timedOut': timedOut,
            'answered': answered,
          });
          _same(failures, 'device again $language w=$width x$textScale', {
            'timedOutBelowChart': timedOutBelowChart,
            'answeredAgain': answeredAgain,
          });
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('韓国語・中国語でも、行の下の「集計中…」と届いた大きさで行の高さが同じ', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final failures = <String>[];
    for (final language in ['ko', 'zh', 'zh_Hant', 'ja']) {
      for (final width in [360.0, 390.0]) {
        for (final textScale in [1.0, 1.3, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          final service = ScriptedStorage()..rememberedCategories = _three;
          final l10n = await showStorageScreen(
            tester,
            providers,
            service,
            size: Size(width, 800),
            language: language,
          );
          service.deviceQueries.single.complete(storageTestDevice);
          await _settle(tester);
          final loading = _rows(tester, l10n);
          service.scans.single.complete(_with(_three));
          await _settle(tester);
          final result = _rows(tester, l10n);
          _same(failures, 'subtitle $language w=$width x$textScale', {
            'loading': loading,
            'result': result,
          });
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
