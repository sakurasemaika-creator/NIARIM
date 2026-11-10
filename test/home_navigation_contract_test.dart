import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProjectService> openHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('home_navigation_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(HomeScreen)).read<ProjectService>();
  }

  Future<void> settleHomeTab(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 70)));
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('leaving projects ends selection and scopes editing shortcuts', (
    tester,
  ) async {
    final service = await openHome(tester);
    await tester.runAsync(
      () => service.createProject(
        name: 'Protected project',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    );
    await settleHomeTab(tester);
    await tester.longPress(find.text('Protected project'));
    await settleHomeTab(tester);
    expect(find.byTooltip('ゴミ箱へ移動'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await settleHomeTab(tester);
    expect(
      find.byTooltip('ゴミ箱へ移動'),
      findsNothing,
      reason: 'a hidden project must not remain a destructive action target',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settleHomeTab(tester);
    expect(find.text('全解除'), findsNothing);
    expect(service.projects.single.name, 'Protected project');
    await tester.tap(find.byKey(const ValueKey('home_tab_0')));
    await settleHomeTab(tester);
    expect(find.byTooltip('ゴミ箱へ移動'), findsNothing);
    expect(find.text('Protected project'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tabs expose their selected state to assistive technology', (
    tester,
  ) async {
    await openHome(tester);
    final semantics = tester.ensureSemantics();
    try {
      for (var selected = 0; selected < 4; selected++) {
        await tester.tap(find.byKey(ValueKey('home_tab_$selected')));
        await settleHomeTab(tester);
        for (var candidate = 0; candidate < 4; candidate++) {
          final data = tester
              .getSemantics(find.byKey(ValueKey('home_tab_$candidate')))
              .getSemanticsData();
          expect(
            data.flagsCollection.isSelected,
            candidate == selected ? Tristate.isTrue : Tristate.isFalse,
            reason: '$candidate selected state after navigating to $selected',
          );
        }
      }
    } finally {
      semantics.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('drawer consolidates reward and help destinations', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeGuideMenuItem')), findsOneWidget);
    expect(find.byKey(const Key('homeCoinBenefitsMenuItem')), findsOneWidget);
    expect(find.byKey(const Key('homeEarnCoinsMenuItem')), findsNothing);
    expect(find.byKey(const Key('homeCreatorMissionsMenuItem')), findsNothing);
    expect(find.text('使い方'), findsOneWidget);
    expect(find.text('コイン・特典'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared pills separate imported projects and reusable snapshots', (
    tester,
  ) async {
    final service = await openHome(tester);
    final project = await tester.runAsync(
      () => service.createProject(
        name: 'Reusable drawing',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    );
    final file = await tester.runAsync(
      () => service.createOutgoingShare(project: project!),
    );
    expect(file, isNotNull);
    final importedData = await tester.runAsync(
      () => NiaproSerializer.loadShare(file!.path),
    );
    await tester.runAsync(
      () => service.importSharedProject(importedData!),
    );
    await settleHomeTab(tester);
    await tester.tap(find.byKey(const ValueKey('home_tab_2')));
    await settleHomeTab(tester);
    expect(find.byKey(const Key('sharedReceivedFilter')), findsOneWidget);
    expect(find.byKey(const Key('sharedOutgoingFilter')), findsOneWidget);
    expect(find.byKey(const Key('sharedReceivedFilter')), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_outlined), findsNothing);

    // Received project has its own share action in its three-dot menu.
    final receivedMenu = find.byKey(
      ValueKey('receivedShareMenu_${service.shared.single.id}'),
    );
    expect(receivedMenu, findsOneWidget);
    await tester.tap(receivedMenu);
    await tester.pumpAndSettle();
    expect(find.text('共有'), findsWidgets);
    await tester.tapAt(const Offset(5, 700));
    await settleHomeTab(tester);

    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await settleHomeTab(tester);
    expect(find.text('Reusable drawing'), findsOneWidget);
    expect(find.byKey(ValueKey('outgoingShareMenu_${file!.path}')), findsOneWidget);
    expect(find.byKey(ValueKey('receivedShareMenu_${service.shared.single.id}')), findsNothing);
    await tester.tap(find.byKey(const Key('sharedReceivedFilter')));
    await settleHomeTab(tester);
    expect(receivedMenu, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project search controls do not imply filtering other tabs', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.byTooltip('検索'));
    await settleHomeTab(tester);
    await tester.enterText(find.byType(TextField), 'project query');
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await settleHomeTab(tester);
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'project search must end when its results leave the screen',
    );
    expect(find.byTooltip('検索'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home_tab_0')));
    await settleHomeTab(tester);
    await tester.tap(find.byTooltip('検索'));
    await settleHomeTab(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
