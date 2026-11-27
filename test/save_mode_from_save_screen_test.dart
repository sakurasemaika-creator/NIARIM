// 手動保存の方式（スロット／ツリー）を保存の画面からも切り替える（所有者の判断、
// 2026-11-27、全部入りの作品づくりの判断カードJ7「保存の画面からも切り替え」）。
// 以前はパフォーマンス設定だけで切り替えた（U27）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/performance_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the save screen switches between slots and the tree', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'quality_level': 'medium',
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('save-mode-');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> settle({int rounds = 5}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    }

    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await settle();
    final ctx = tester.element(find.byType(MaterialApp).first);
    final ps = ctx.read<ProjectService>();
    final perf = ctx.read<PerformanceService>();
    final saves = ctx.read<SaveTreeService>();
    expect(perf.saveMode, SaveMode.slot);
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'save-mode',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      ),
    ))!;
    appRouter.go('/save-tree/${project.id}');
    await settle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(find.text(l10n.saveTreeScreenTitleSlot), findsOneWidget);

    Future<void> choose(SaveMode mode) async {
      await tester.tap(find.byKey(const ValueKey('saveModeMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('saveModeMenu-${mode.name}')));
      await settle();
    }

    await choose(SaveMode.tree);
    expect(perf.saveMode, SaveMode.tree);
    expect(saves.isTreeMode, isTrue);
    // The preset became カスタム with its other values kept.
    expect(perf.qualityLevel, QualityLevel.custom);
    expect(find.text(l10n.saveTreeScreenTitleTree), findsOneWidget);

    await choose(SaveMode.slot);
    expect(perf.saveMode, SaveMode.slot);
    expect(saves.isTreeMode, isFalse);
    expect(perf.slotCount, 10, reason: 'the medium preset had 10 slots');
    expect(find.text(l10n.saveTreeScreenTitleSlot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
