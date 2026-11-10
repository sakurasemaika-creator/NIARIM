import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:provider/provider.dart';

import 'helpers/pump_real_async.dart';
import 'helpers/storage_screen_harness.dart';

/// 容量削減の画面を開き直したときに出す「前回の値」。
/// - ゴミ箱の中身が前回と違えば（作品をゴミ箱へ移した・戻した）、前回の値は
///   ゴミ箱の大きさも作品データの大きさも合っていないので出さない。
/// - 集計の途中で離れて戻ったときは、走っている1回の集計を2つの画面で分け合う。
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

/// 集計を、テストの本体と同じゾーンで呼ぶ。サービスは同じゾーンの呼び出しとだけ
/// 走っている集計を分け合うが、ウィジェットテストは画面を作るたびに別の
/// ゾーンで動くので、そのままでは製品と同じ「分け合う」道を通らない。
class _SameZoneStorage extends StorageInfoService {
  _SameZoneStorage() : _zone = Zone.current;

  final Zone _zone;

  @override
  Future<StorageBreakdown> computeBreakdown(
    Set<String> trashedProjectIds, {
    bool fresh = false,
  }) =>
      _zone.run(() => super.computeBreakdown(trashedProjectIds, fresh: fresh));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;
  var documentsLookups = 0;

  /// アプリ専用キャッシュの場所を聞くのは、容量の集計だけ（1回の集計の最後）。
  var cacheLookups = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-revisit-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    File('${cache.path}/thumb.bin').writeAsBytesSync(List.filled(123, 7));
    documentsLookups = 0;
    cacheLookups = 0;
    StorageInfoService().invalidate();
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      if (call.method == 'getApplicationCacheDirectory') {
        cacheLookups++;
        return cache.path;
      }
      if (call.method == 'getApplicationDocumentsDirectory') documentsLookups++;
      return docs.path;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    root.deleteSync(recursive: true);
  });

  ListTile tile(WidgetTester tester, String title) =>
      tester.widget<ListTile>(storageTile(title));
  String subtitleOf(ListTile tile) => (tile.subtitle! as Text).data!;

  /// ゴミ箱に作品が1つある状態を作る（本物のProjectService）。
  Future<String> trashOneProject(WidgetTester tester, ProjectService ps) async {
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'Audit trash revisit',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFF123456,
        exportWidth: 64,
        exportHeight: 64,
      ),
    );
    await tester.runAsync(() => ps.deleteProject(project!.id));
    expect(ps.trash.map((p) => p.id), [project!.id]);
    return project.id;
  }

  testWidgets('空のゴミ箱で覚えた値は、作品をゴミ箱へ移した後に開き直した画面へ出さない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    // 前回（ゴミ箱が空のとき）の値を覚えている。
    final service = ScriptedStorage()
      ..rememberedBreakdown = storageBreakdownOf(trash: 0)
      ..rememberedTrashedIds = const {};

    // 画面の外で、作品をゴミ箱へ移した。
    await showStorageScreen(tester, providers, ScriptedStorage());
    final ps = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    await tester.pumpWidget(const SizedBox.shrink());
    final id = await trashOneProject(tester, ps);
    addTearDown(() => tester.runAsync(() => ps.permanentDelete(id)));

    final l10n = await showStorageScreen(tester, providers, service);
    // 集計し直している間、「ゴミ箱 0B」とも、前回の内訳のグラフとも出さない。
    final row = tile(tester, l10n.storageEmptyTrashButton);
    expect(subtitleOf(row), l10n.storageCalculating);
    expect(row.enabled, isFalse);
    expect(find.text('0B'), findsNothing);
    expect(find.text('123B'), findsNothing);
    expect(find.text(l10n.storageCategoryMaterials), findsNothing);
    // 時間がたっても同じ（集計が終わるまで、合っていない値は出ない）。
    await tester.pump(const Duration(seconds: 20));
    expect(
      subtitleOf(tile(tester, l10n.storageEmptyTrashButton)),
      l10n.storageCalculating,
    );

    service.scans.single.complete(storageBreakdownOf(trash: 2048));
    service.deviceQueries.single.complete(null);
    await tester.pump();
    await tester.pump();
    final landed = tile(tester, l10n.storageEmptyTrashButton);
    expect(subtitleOf(landed), '2.0KB');
    expect(landed.enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ゴミ箱に作品があるときに覚えた値は、作品を戻した後に開き直した画面へ出さない', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    await showStorageScreen(tester, providers, ScriptedStorage());
    final ps = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    await tester.pumpWidget(const SizedBox.shrink());
    final id = await trashOneProject(tester, ps);

    // ゴミ箱に作品があるときの値を覚えている。
    final service = ScriptedStorage()
      ..rememberedBreakdown = storageBreakdownOf(trash: 2048)
      ..rememberedTrashedIds = {id};
    // 同じゴミ箱のまま開き直せば、前回の値がそのまま出る。
    var l10n = await showStorageScreen(tester, providers, service);
    expect(subtitleOf(tile(tester, l10n.storageEmptyTrashButton)), '2.0KB');
    expect(tile(tester, l10n.storageEmptyTrashButton).enabled, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());

    // 画面の外で、作品をゴミ箱から戻した。
    await tester.runAsync(() => ps.restoreProject(id));
    expect(ps.trash, isEmpty);
    addTearDown(() async {
      await tester.runAsync(() async {
        await ps.deleteProject(id);
        await ps.permanentDelete(id);
      });
    });

    final reopened = ScriptedStorage()
      ..rememberedBreakdown = storageBreakdownOf(trash: 2048)
      ..rememberedTrashedIds = {id};
    l10n = await showStorageScreen(tester, providers, reopened);
    // 空のゴミ箱に、前回の大きさを出して「空にする」を押せるようにしない。
    final row = tile(tester, l10n.storageEmptyTrashButton);
    expect(subtitleOf(row), l10n.storageCalculating);
    expect(row.enabled, isFalse);
    expect(find.text('2.0KB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('集計の途中で離れて戻ると、走っている1回の集計を分け合い、結果が出る', (tester) async {
    final providers = await bootstrapStorageScreen(tester);
    final service = _SameZoneStorage();
    // 起動処理も書類の場所を聞くので、ここから数える。
    documentsLookups = 0;
    await showStorageScreen(tester, providers, service);
    // 走査は始まったばかり（実時間を進めていないので、ファイルの一覧は返らない）。
    await tester.pump();
    expect(documentsLookups, 1);

    // 離れて（最初の画面は破棄される）、戻る。
    await tester.pumpWidget(const SizedBox.shrink());
    await showStorageScreen(tester, providers, service);
    await tester.pump();
    // 2つ目の画面は、走っている集計を待つ（もう1回走査を始めない）。
    expect(documentsLookups, 1);

    for (var i = 0; i < 30 && find.text('123B').evaluate().isEmpty; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    expect(find.text('123B'), findsNWidgets(2));
    expect(documentsLookups, 1);
    expect(cacheLookups, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
