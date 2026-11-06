import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
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
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Protected project'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('ゴミ箱へ移動'), findsOneWidget);
    await tester.tap(find.text('作品一覧'));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('ゴミ箱へ移動'),
      findsNothing,
      reason: 'a hidden project must not remain a destructive action target',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('全解除'), findsNothing);
    expect(service.projects.single.name, 'Protected project');
    await tester.tap(find.text('プロジェクト'));
    await tester.pumpAndSettle();
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
      for (var selected = 0; selected < 3; selected++) {
        await tester.tap(find.byKey(ValueKey('home_tab_$selected')));
        await tester.pumpAndSettle();
        for (var candidate = 0; candidate < 3; candidate++) {
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

  testWidgets('project search controls do not imply filtering other tabs', (
    tester,
  ) async {
    await openHome(tester);
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'project query');
    await tester.tap(find.text('作品一覧'));
    await tester.pumpAndSettle();
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'project search must end when its results leave the screen',
    );
    expect(find.byTooltip('検索'), findsNothing);
    await tester.tap(find.text('ブクマ済み'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('検索'), findsNothing);
    await tester.tap(find.text('プロジェクト'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
