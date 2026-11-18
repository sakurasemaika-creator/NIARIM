import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  test('floating tool panels use a small top-right close affordance', () {
    final source = File(
      'lib/screens/canvas/widgets/panel_close_bar.dart',
    ).readAsStringSync();

    expect(source, contains('Alignment.centerRight'));
    expect(source, contains('Icons.close, size: 18'));
    expect(source, contains('minWidth: 44'));
    expect(source, contains('minHeight: 44'));
    expect(source, isNot(contains('return Center(')));
  });

  testWidgets('mobile floating panels dismiss when tapping outside', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final projects = tester
        .element(find.byType(MaterialApp))
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'Panel dismissal',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 48,
      ),
    ))!;
    appRouter.go('/canvas/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 450));

    final canvas = find.byType(CanvasArea);
    final l10n = AppLocalizations.of(tester.element(canvas))!;
    final panel = find.byType(LayerPanel);
    expect(panel, findsNothing);
    final openPanel = find.byTooltip(l10n.toolbarLayerTooltip);
    await tester.ensureVisible(openPanel);
    await tester.pumpAndSettle();
    expect(openPanel.hitTestable(), findsOneWidget);
    await tester.tap(openPanel);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    final outside = Offset(24, tester.getCenter(canvas).dy);
    expect(tester.getRect(panel).contains(outside), isFalse);
    await tester.tapAt(outside);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
