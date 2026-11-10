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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面をキーボードだけで操作する（PC・外付けキーボード）。
/// 確かめるダイアログがフォーカスを受け取ること、やり直しのボタンが結果が
/// 届くまでその場に残ること、欄が出入りしても操作の行のフォーカスが
/// 外れないこと。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-keyboard-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  /// 内訳が出ていて、端末の容量の欄は無い状態（操作の行がすべて押せる）。
  Future<void> settle(WidgetTester tester, ScriptedStorage service) async {
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(storageBreakdownOf(trash: 2048));
    await tester.pump();
    await tester.pump();
  }

  bool dialogHasFocus(WidgetTester tester) =>
      FocusScope.of(tester.element(find.byType(AlertDialog))).hasFocus;

  testWidgets('行をEnterで押して開いた確かめるダイアログがフォーカスを受け取り、Escapeで閉じると同じ行へ戻る', (
    tester,
  ) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    await settle(tester, service);

    for (final title in [
      l10n.storageClearCacheButton,
      l10n.storageRemoveUnusedMaterialsButton,
      l10n.storageEraseAllButton,
    ]) {
      final tile = storageTile(title);
      expect(await tabTo(tester, tile), isTrue, reason: title);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget, reason: title);
      // フォーカスはダイアログの中。下の画面の行・ヘルプのボタンには無い。
      expect(dialogHasFocus(tester), isTrue, reason: title);
      expect(focusIsWithin(tester, tile), isFalse, reason: title);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: title);
      // 取り消したら、押した行へフォーカスが戻る（続けて操作できる）。
      expect(focusIsWithin(tester, tile), isTrue, reason: title);
      expect(tester.takeException(), isNull, reason: title);
    }
    // 取り消しただけなので、何も消していないし集計もし直していない。
    expect(service.cacheClears, 0);
    expect(service.invalidations, 0);
    expect(service.scans, hasLength(1));
  });

  testWidgets('キーボードだけで、取り消しのボタンを選んで閉じられ、消す操作も最後まで通せる', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    await settle(tester, service);
    final tile = storageTile(l10n.storageClearCacheButton);

    expect(await tabTo(tester, tile), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 最初のTabはダイアログの中のボタンへ入る（下の画面へは行かない）。
    final cancel = find.widgetWithText(TextButton, l10n.commonCancel);
    expect(await tabTo(tester, cancel), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(focusIsWithin(tester, tile), isTrue);
    expect(service.cacheClears, 0);

    // 取り消した後、同じ行をもう一度押せる。今度は削除を選ぶ。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    final delete = find.widgetWithText(FilledButton, l10n.commonDelete);
    expect(await tabTo(tester, delete), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.cacheClears, 1);
    expect(service.scans, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('内訳のやり直しをEnterで押しても、結果が届くまでボタンはその場に残りフォーカスを保つ', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.completeError(StateError('unreadable'));
    await tester.pump();
    await tester.pump();
    final retry = find.byKey(storageBreakdownRetryKey);
    expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);

    expect(await tabTo(tester, retry), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.scans, hasLength(2));
    // 走っている間もボタンは同じ所にあり、フォーカスはそこから動かない。
    expect(retry, findsOneWidget);
    expect(focusIsWithin(tester, retry), isTrue);
    // やり直している間は、失敗の文ではなく集計中と出す。
    expect(find.text(l10n.storageBreakdownLoadFailed), findsNothing);
    expect(find.text(l10n.storageCalculating), findsWidgets);

    // 続けてEnterを押しても、別の操作（ヘルプ等）は動かず、集計も重ならない。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.scans, hasLength(2));
    expect(focusIsWithin(tester, retry), isTrue);
    expect(tester.takeException(), isNull);

    // もう一度失敗したら、文が戻り、ボタンはそのまま使える。
    service.scans.last.completeError(StateError('unreadable again'));
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageBreakdownLoadFailed), findsOneWidget);
    expect(focusIsWithin(tester, retry), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.scans, hasLength(3));

    service.scans.last.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text('123B'), findsNWidgets(2));
    expect(retry, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一部を読めなかった内訳のやり直しも、走っている間は押せるまま残る', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(
      storageBreakdownOf(incomplete: {StorageCategory.exports}),
    );
    await tester.pump();
    await tester.pump();
    final retry = find.byKey(storageBreakdownRetryKey);
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);

    expect(await tabTo(tester, retry), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.scans, hasLength(2));
    expect(focusIsWithin(tester, retry), isTrue);
    expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
    // 出ている値はまだ「一部を読めなかった」ものなので、その文は残す。
    expect(find.text(l10n.storageBreakdownIncomplete), findsOneWidget);
    expect(find.text('123B'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末の容量のやり直しをEnterで押しても、答えが届くまでボタンはその場に残る', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump(storageDeviceSpaceTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    final retry = find.byKey(storageDeviceRetryKey);
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsOneWidget);

    expect(await tabTo(tester, retry), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.deviceQueries, hasLength(2));
    expect(retry, findsOneWidget);
    expect(focusIsWithin(tester, retry), isTrue);
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsNothing);
    expect(find.text(l10n.storageCalculating), findsOneWidget);

    // 今度も待ちが切れたら、文が戻ってボタンはそのまま。
    await tester.pump(storageDeviceSpaceTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l10n.storageDeviceSpaceUnavailable), findsOneWidget);
    expect(focusIsWithin(tester, retry), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(service.deviceQueries, hasLength(3));
    service.deviceQueries.last.complete(storageTestDevice);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(retry, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末の容量の欄が出入りしても、操作の行のフォーカスは外れない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    // 端末の容量はまだ待っている（欄は出ている）。
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    final tile = storageTile(l10n.storageRemoveUnusedMaterialsButton);
    expect(await tabTo(tester, tile), isTrue);

    // 「この端末では取得できない」と分かって、欄が消える。
    service.deviceQueries.single.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageDeviceChartTitle), findsNothing);
    expect(focusIsWithin(tester, tile), isTrue);

    // 取り直して答えが届き、欄が出る。
    final refresh = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(refresh.show());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    service.deviceQueries.last.complete(storageTestDevice);
    service.scans.last.complete(storageBreakdownOf());
    await tester.pumpAndSettle();
    expect(find.text(l10n.storageDeviceChartTitle), findsOneWidget);
    expect(focusIsWithin(tester, tile), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本物のアプリ（PC 1440x900）でも、行をEnterで押したダイアログがEscapeで閉じ、同じ行へ戻る', (
    tester,
  ) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    StorageInfoService().invalidate();
    appRouter.go('/storage');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(StorageScreen)),
    )!;
    String location() =>
        appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

    final tile = storageTile(l10n.storageEraseAllButton);
    expect(await tabTo(tester, tile), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(dialogHasFocus(tester), isTrue);

    // もう一度Enterを押しても、下の画面のボタン（ヘルプ）は動かない。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(location(), '/storage');
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(focusIsWithin(tester, tile), isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });
}
