// PCの作業画面で窓を別の列へ移すと、ほかの窓はたたまずに高さを分け合い、
// 入りきらないときだけたたむ（所有者の判断、2026-11-27、全部入りの作品づくりの
// 判断カードJ5）。作品づくりの工程2a（U30）で、列へ窓を移すとほかの窓が
// たたまれたように見えた。今の作り（DesktopDockColumnFit）がこの決まりどおりで
// あることを、本物のキャンバスの画面で見張る。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/utils/desktop_dock_column_fit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  testWidgets('a window moved to a column shares its height, folds none', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('dock-share-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
      'default_docked_panels': [
        'penSubTool',
        'colorPicker',
        'layer',
        'onionSkin',
      ],
    });
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    Future<void> settle([int rounds = 6]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle(4);
    final home = tester.element(find.byType(HomeScreen));
    final ps = home.read<ProjectService>();
    final settings = home.read<SettingsService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'docks',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    appRouter.push('/canvas/${project.id}');
    await settle(12);

    bool folded(CanvasDockPanel panel) => find
        .byKey(ValueKey('dockCollapsedDrag-${panel.name}'))
        .evaluate()
        .isNotEmpty;
    Rect window(CanvasDockPanel panel) =>
        tester.getRect(find.byKey(ValueKey('dockTarget-${panel.name}')));

    // Into the right column, one by one: four windows at 720px high.
    for (final panel in [
      CanvasDockPanel.penSubTool,
      CanvasDockPanel.onionSkin,
    ]) {
      await tester.runAsync(
        () => settings.moveDesktopDockPanel(panel, toRight: true),
      );
      await settle();
    }
    final right = [
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
      CanvasDockPanel.penSubTool,
      CanvasDockPanel.onionSkin,
    ].where(settings.rightDockOrder.contains).toList();
    expect(right, hasLength(4));
    const smallest =
        DesktopDockColumnFit.titleHeight +
        DesktopDockColumnFit.resizeGripHeight +
        DesktopDockColumnFit.minimumBodyHeight;
    for (final panel in right) {
      expect(folded(panel), isFalse, reason: '${panel.name} is not folded');
      expect(window(panel).height, greaterThanOrEqualTo(smallest - 1));
    }
    // They share the column: one after another, the same height each.
    final heights = {for (final p in right) window(p).height.round()};
    expect(heights.length, 1, reason: 'shared alike: $heights');
    for (var i = 1; i < right.length; i++) {
      expect(
        window(right[i]).top,
        closeTo(window(right[i - 1]).bottom, 2),
        reason: right[i].name,
      );
    }
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.layer), isFalse);
    expect(tester.takeException(), isNull);
  });
}
