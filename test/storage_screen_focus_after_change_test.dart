import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/help_button.dart';

import 'helpers/storage_screen_harness.dart';

/// キーボードで操作した行が押せなくなる・「再試行」が消えるとき、フォーカスが
/// アプリバーのヘルプへ飛ばず（次のEnterでヘルプが開かず）、その欄に残ること。
/// 終わらない集計にも、キーボードで押せる「再試行」が出ること。
///
/// この道具立てにはルーターが無いので、ヘルプのボタンが押されると例外になる
/// （＝Enterがヘルプを押していないことも一緒に確かめられる）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-focus-after-');
    messenger.setMockMethodCallHandler(pathChannel, (call) async => root.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  String? focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;
  final help = find.byType(HelpButton);

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('キーボードでキャッシュを消した後、フォーカスは「整理する」に残り、Tabで次の行へ進む', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    final cacheRow = storageTile(l10n.storageClearCacheButton);
    final nextRow = storageTile(l10n.storageRemoveUnusedMaterialsButton);

    expect(await tabTo(tester, cacheRow), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      await tabTo(tester, find.widgetWithText(FilledButton, l10n.commonDelete)),
      isTrue,
    );
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.cacheClears, 1);
    // 集計し直している間、キャッシュの行は押せない。
    expect(tester.widget<ListTile>(cacheRow).enabled, isFalse);
    expect(focusIsWithin(tester, help), isFalse);
    expect(focusLabel(), 'storageActionsHeading');

    // 続けてEnterを押しても何も起きない（ヘルプも確かめるダイアログも開かない）。
    await press(tester, LogicalKeyboardKey.enter);
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);

    // キャッシュが空になった結果が届いても、フォーカスはその欄のまま。
    service.scans.last.complete(storageBreakdownOf(cache: 0));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ListTile>(cacheRow).enabled, isFalse);
    expect(focusIsWithin(tester, help), isFalse);
    expect(focusLabel(), 'storageActionsHeading');

    // Tabは、押せる最初の行へ進む。
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusIsWithin(tester, nextRow), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('キーボードで押した内訳の「再試行」が成功して消えても、フォーカスは内訳の欄に残る', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    service.scans.single.completeError(StateError('unreadable'));
    await tester.pump();
    await tester.pump();
    final retry = find.byKey(storageBreakdownRetryKey);

    expect(await tabTo(tester, retry), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(service.scans, hasLength(2));
    service.scans.last.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    expect(retry, findsNothing);
    expect(focusIsWithin(tester, help), isFalse);
    expect(focusLabel(), 'storageBreakdownHeading');

    await press(tester, LogicalKeyboardKey.enter);
    expect(tester.takeException(), isNull);
    // Tabは、内訳の欄の次の操作（キャッシュの行）へ進む。
    await press(tester, LogicalKeyboardKey.tab);
    expect(
      focusIsWithin(tester, storageTile(l10n.storageClearCacheButton)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('キーボードで押した端末の容量の「再試行」が成功して消えても、フォーカスはその欄に残る', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));
    final retry = find.byKey(storageDeviceRetryKey);

    expect(await tabTo(tester, retry), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(service.deviceQueries, hasLength(2));
    service.deviceQueries.last.complete(storageTestDevice);
    await tester.pump();
    await tester.pump();
    expect(retry, findsNothing);
    expect(find.text(l10n.storageCategoryFree), findsOneWidget);
    expect(focusIsWithin(tester, help), isFalse);
    expect(focusLabel(), 'storageDeviceHeading');
    await press(tester, LogicalKeyboardKey.enter);
    expect(tester.takeException(), isNull);
  });

  testWidgets('この端末では取得できないと分かって欄ごと消えるときは、次の欄へフォーカスを移す', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.scans.single.complete(storageBreakdownOf());
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));
    final retry = find.byKey(storageDeviceRetryKey);

    expect(await tabTo(tester, retry), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    service.deviceQueries.last.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.storageDeviceChartTitle), findsNothing);
    expect(focusIsWithin(tester, help), isFalse);
    expect(focusLabel(), 'storageBreakdownHeading');
    await press(tester, LogicalKeyboardKey.enter);
    expect(tester.takeException(), isNull);
  });

  testWidgets('終わらない集計には、キーボードでも押せる「再試行」が出て、新しい集計を始められる', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage();
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    await tester.pump();
    final retry = find.byKey(storageBreakdownRetryKey);
    expect(retry, findsNothing);

    // 30秒たっても集計が返らない。
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(retry, findsOneWidget);
    // まだ走っているので「集計できませんでした」とは言わない。
    expect(find.text(l10n.storageBreakdownLoadFailed), findsNothing);
    expect(find.text(l10n.storageCalculating), findsWidgets);
    expect(service.scans, hasLength(1));

    expect(await tabTo(tester, retry), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(service.scans, hasLength(2));
    expect(service.freshScans, [false, true]);
    // 走っている間もボタンはその場に残り、重ねて押しても集計は増えない。
    expect(retry, findsOneWidget);
    expect(focusIsWithin(tester, retry), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(service.scans, hasLength(2));

    service.scans.last.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    expect(find.text('123B'), findsNWidgets(2));
    expect(retry, findsNothing);
    expect(focusLabel(), 'storageBreakdownHeading');
    expect(tester.takeException(), isNull);
  });

  testWidgets('待ち切れの「再試行」を押さなければ、遅れて届いた結果をそのまま出す', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = ScriptedStorage()
      ..rememberedBreakdown = storageBreakdownOf(cache: 64);
    final l10n = await showStorageScreen(tester, providers, service);
    service.deviceQueries.single.complete(null);
    await tester.pump();
    // 前回の値を出したまま、裏の集計が返らない。
    expect(find.text('64B'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    final retry = find.byKey(storageBreakdownRetryKey);
    expect(retry, findsOneWidget);
    expect(find.text('64B'), findsNWidgets(2));
    expect(find.text(l10n.storageBreakdownLoadFailed), findsNothing);

    service.scans.single.complete(storageBreakdownOf());
    await tester.pump();
    await tester.pump();
    expect(service.scans, hasLength(1));
    expect(find.text('123B'), findsNWidgets(2));
    expect(retry, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
