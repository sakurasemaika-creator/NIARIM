import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/exported_work_name.dart';
import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

/// 容量削減の画面の外で大きさが変わったら（書き出した作品の削除・作品の
/// 完全削除）、覚えている集計結果を捨て、その前から走っている集計を
/// 後から来た呼び出しへ渡さない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory docs;
  late Directory cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-outside-');
    docs = Directory('${root.path}/docs')..createSync();
    cache = Directory('${root.path}/cache')..createSync();
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => call.method == 'getApplicationCacheDirectory'
          ? cache.path
          : docs.path,
    );
    StorageInfoService().invalidate();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    root.deleteSync(recursive: true);
  });

  testWidgets('作品一覧で書き出した作品を消すと、覚えている集計結果を捨てる', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final file = File('${docs.path}/niarim/exports/AUDIT_delete.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(img.Image(width: 32, height: 18)));
    final bytes = file.lengthSync();
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    final remembered = await tester.runAsync(
      () => StorageInfoService().computeBreakdown({}),
    );
    expect(remembered!.bytesOf(StorageCategory.exports), bytes);
    expect(StorageInfoService().lastBreakdown, same(remembered));

    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
    expect(findExportedWorkName('AUDIT_delete.png'), findsOneWidget);

    // 消す前から走っている集計（実時間を進めていないので、まだ終わらない）。
    final running = StorageInfoService().computeBreakdown({});

    final delete = find.byTooltip('${l10n.commonDelete}: AUDIT_delete.png');
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pump();
    expect(file.existsSync(), isFalse);

    // 消した分を含む前回の結果は、開き直した画面に出さない。
    expect(StorageInfoService().lastBreakdown, isNull);
    // 消す前のディスクを見ている集計は、後から来た呼び出しへ渡さない。
    final afterwards = StorageInfoService().computeBreakdown({});
    expect(afterwards, isNot(same(running)));

    // 走査は本物のファイル操作なので、実時間を進めて終わらせる。
    final finished = <StorageBreakdown>[];
    unawaited(running.then(finished.add));
    unawaited(afterwards.then(finished.add));
    for (var i = 0; i < 30 && finished.length < 2; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 100));
    }
    expect(finished, hasLength(2));
    expect((await afterwards).bytesOf(StorageCategory.exports), 0);
    // 消す前に始まった集計が後から終わっても、その結果は覚えない。
    expect(
      StorageInfoService().lastBreakdown?.bytesOf(StorageCategory.exports),
      0,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });

  group('作品の完全削除', () {
    late ProjectService projects;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      projects = ProjectService();
      await projects.init();
    });

    tearDown(() => projects.dispose());

    Future<String> trashedProject(String name) async {
      final project = await projects.createProject(
        name: name,
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFF123456,
        exportWidth: 64,
        exportHeight: 64,
      );
      await projects.deleteProject(project.id);
      return project.id;
    }

    Set<String> trashedIds() => projects.trash.map((p) => p.id).toSet();

    test('ゴミ箱の作品を完全に消すと、覚えている集計結果を捨てる', () async {
      final id = await trashedProject('Audit permanent delete');
      final service = StorageInfoService();
      final before = await service.computeBreakdown(trashedIds());
      expect(before.bytesOf(StorageCategory.trash), greaterThan(0));
      expect(service.lastBreakdown, same(before));

      await projects.permanentDelete(id);
      expect(service.lastBreakdown, isNull);
      final after = await service.computeBreakdown(trashedIds());
      expect(after.bytesOf(StorageCategory.trash), 0);
    });

    test('ゴミ箱を空にしても、覚えている集計結果を捨てる', () async {
      await trashedProject('Audit empty trash 1');
      await trashedProject('Audit empty trash 2');
      final service = StorageInfoService();
      final before = await service.computeBreakdown(trashedIds());
      expect(before.bytesOf(StorageCategory.trash), greaterThan(0));

      await projects.emptyTrash();
      expect(projects.trash, isEmpty);
      expect(service.lastBreakdown, isNull);
    });
  });
}
