import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

/// 容量削減の画面を本物のアプリ（起動処理・ルーター・テーマ）で開き、
/// 端末の容量・内訳・操作がそれぞれ独立に出ることを確かめる。
///
/// 内訳の走査は本物のファイル操作なので、偽の時計を進めるだけでは終わらない。
/// 待つときは`waitFor`（実時間と偽の時計を交互に進める）を使う。
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _diskChannel = MethodChannel('disk_space_2');

const _retryBreakdown = ValueKey<String>('storageBreakdownRetry');
const _retryDevice = ValueKey<String>('storageDeviceRetry');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory root;
  late Directory docs;
  late Directory cache;

  /// trueの間、アプリ専用キャッシュの場所の問い合わせを失敗させる
  /// （この問い合わせをするのは容量の集計だけ）。
  var failCacheLookup = false;

  /// 端末の容量の問い合わせへの答え方。nullならプラグイン無し
  /// （ウィジェットテストの既定）。
  Future<Object?> Function(MethodCall call)? disk;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-loading-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    File('${cache.path}/thumb.bin').writeAsBytesSync(List.filled(123, 7));
    failCacheLookup = false;
    disk = null;
    // 直近の結果はプロセスの中で覚えているので、前のテストの値を捨てる。
    StorageInfoService().invalidate();
    AppErrorReporter.recentErrors.clear();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (call.method == 'getApplicationCacheDirectory') {
        if (failCacheLookup) {
          throw PlatformException(code: 'unavailable', message: 'no cache dir');
        }
        return cache.path;
      }
      return docs.path;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    messenger.setMockMethodCallHandler(_diskChannel, null);
    root.deleteSync(recursive: true);
  });

  Future<AppLocalizations> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool pc = false,
  }) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final answer = disk;
    messenger.setMockMethodCallHandler(
      _diskChannel,
      answer == null ? null : (call) => disk!(call),
    );
    appRouter.go('/storage');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(StorageScreen)))!;
  }

  /// [finder]が見つかるまで、実時間と偽の時計を交互に進める（最長3秒）。
  Future<bool> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 30; i++) {
      if (finder.evaluate().isNotEmpty) return true;
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    return finder.evaluate().isNotEmpty;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  }

  for (final (label, size, pc) in [
    ('スマホ 390x844', const Size(390, 844), false),
    ('PC 1440x900', const Size(1440, 900), true),
  ]) {
    testWidgets('端末の容量の問い合わせが返らなくても、内訳と操作は出る（$label）', (tester) async {
      disk = (_) => Completer<Object?>().future;
      final l10n = await open(tester, size: size, pc: pc);

      await waitFor(tester, find.text('123B'));
      expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
      expect(find.text(l10n.storageActionsTitle), findsOneWidget);
      expect(
        find.text(l10n.storageEraseAllButton, skipOffstage: false),
        findsOneWidget,
      );
      // 凡例と「キャッシュを削除」の行の両方に出る。
      expect(find.text('123B'), findsWidgets);

      // 答えを待っている間は、端末の容量の欄の中だけが集計中。
      expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
      expect(find.text(l10n.storageCalculating), findsOneWidget);
      expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);

      // 待ちが切れた後は、どこにも回り続ける表示が残らない。
      await tester.pump(storageDeviceSpaceTimeout);
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.storageCalculating), findsNothing);
      expect(find.text(l10n.storageDeviceSpaceUnavailable), findsOneWidget);
      expect(find.text('123B'), findsWidgets);
      expect(tester.takeException(), isNull);

      // 答えが返るようになってからやり直すと、グラフが出る。
      disk = (call) async => call.method == 'getFreeDiskSpace' ? 400.0 : 1000.0;
      await tester.tap(find.byKey(_retryDevice));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
      expect(find.text(l10n.storageCategoryFree), findsOneWidget);
      expect(find.byKey(_retryDevice), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  testWidgets('キャッシュの場所が取れなくても残りは出て、やり直せる', (tester) async {
    failCacheLookup = true;
    final l10n = await open(tester);

    await waitFor(tester, find.byKey(_retryBreakdown));
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
    expect(find.text(l10n.storageActionsTitle), findsOneWidget);
    expect(
      find.text(l10n.storageEraseAllButton, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(_retryBreakdown), findsOneWidget);
    expect(find.text(l10n.communityRetry), findsOneWidget);
    expect(find.text('123B'), findsNothing);
    // 読めなかった分類があることを文で知らせる（例外の文は出さない）。
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.textContaining('no cache dir'), findsNothing);
    // キャッシュの大きさは分かっていないので、0Bとは出さず、押せない。
    final clearCache = tester.widget<ListTile>(
      find.widgetWithText(ListTile, l10n.storageClearCacheButton),
    );
    expect(clearCache.enabled, isFalse);
    expect((clearCache.subtitle! as Text).data, isEmpty);
    // 原因はエラーの記録に残る。
    expect(
      AppErrorReporter.recentErrors.where((e) => e.contains('no cache dir')),
      hasLength(1),
    );

    failCacheLookup = false;
    await tester.ensureVisible(find.byKey(_retryBreakdown));
    await tester.pump();
    await tester.tap(find.byKey(_retryBreakdown));
    await waitFor(tester, find.text('123B'));
    expect(find.text('123B'), findsWidgets);
    expect(find.byKey(_retryBreakdown), findsNothing);
    expect(find.text(l10n.storageBreakdownIncomplete), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('読み込み直している間も本文は出たまま', (tester) async {
    disk = (call) async => call.method == 'getFreeDiskSpace' ? 400.0 : 1000.0;
    final l10n = await open(tester);
    await waitFor(tester, find.text('123B'));
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);

    // 2回目の問い合わせは返らない。
    disk = (_) => Completer<Object?>().future;
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pump(const Duration(seconds: 1));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));

    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
    expect(find.text(l10n.storageActionsTitle), findsOneWidget);
    expect(find.text('123B'), findsWidgets);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text(l10n.storageActionsTitle), findsOneWidget);
    expect(find.text('123B'), findsWidgets);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('開き直した最初のフレームに前回の結果が出る', (tester) async {
    disk = (call) async => call.method == 'getFreeDiskSpace' ? 400.0 : 1000.0;
    final l10n = await open(tester);
    await waitFor(tester, find.text('123B'));
    expect(find.text('123B'), findsWidgets);
    // 端末の容量のグラフ（空き400MB）も出ている。
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text('400.0MB'), findsOneWidget);

    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StorageScreen), findsNothing);

    // 実時間を進めない（＝新しい走査は終われない）・端末の容量の問い合わせも
    // 返らないまま開き直す。出ているのは、覚えていた前回の値だけ。
    disk = (_) => Completer<Object?>().future;
    appRouter.go('/storage');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StorageScreen), findsOneWidget);
    expect(find.text(l10n.storageBreakdownChartTitle), findsOneWidget);
    expect(find.text('123B'), findsWidgets);
    // 内訳だけでなく、端末の容量のグラフも前回の値で出る。
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(find.text('400.0MB'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('走査の途中で離れて戻っても例外にならず、結果が出る', (tester) async {
    await open(tester);
    // 走査は始まったばかり（実時間を進めていない）。
    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StorageScreen), findsNothing);

    appRouter.go('/storage');
    await tester.pump();
    await waitFor(tester, find.text('123B'));
    expect(find.text('123B'), findsWidgets);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('「プロジェクトを整理する」から戻ると、整理した後の大きさを集計し直す', (tester) async {
    final l10n = await open(tester);
    await waitFor(tester, find.text('123B'));
    String location() =>
        appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

    await tester.tap(find.text(l10n.storageOrganizeProjectsButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(location(), '/home');

    // 行き先で大きさが変わった。
    File('${cache.path}/more.bin').writeAsBytesSync(List.filled(10, 7));
    appRouter.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(location(), '/storage');
    await waitFor(tester, find.text('133B'));
    expect(find.text('133B'), findsWidgets);
    expect(find.text('123B'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
