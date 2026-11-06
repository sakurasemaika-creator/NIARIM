import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  for (final size in [
    const Size(240, 220),
    const Size(320, 399),
    const Size(320, 400),
  ]) {
    testWidgets('project menus and Add have separate hit areas at $size', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('home-project-actions-');
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(pathProvider, (_) async => dir.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(pathProvider, null);
        dir.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'fr',
        'force_pc_mode': 0,
        'home.projectViewMode.v1': 'small',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadAppFonts(tester);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(HomeScreen));
      final l10n = AppLocalizations.of(context)!;
      final service = context.read<ProjectService>();
      await tester.runAsync(() async {
        for (final name in ['Gamma', 'Beta']) {
          await service.createProject(
            name: name,
            fps: 12,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 64,
            exportHeight: 64,
          );
        }
      });
      await tester.pumpAndSettle();
      final list = find.byType(ProjectListWidget);
      final viewport = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      final menus = find.descendant(
        of: list,
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton<String>),
      );
      final add = find.byWidgetPredicate(
        (w) => w is FloatingActionButton && w.heroTag == 'home-add-project',
      );
      expect(
        tester.getRect(viewport).bottom,
        lessThanOrEqualTo(tester.getTopLeft(add).dy),
        reason: 'The list must end before the Add hit area at $size.',
      );
      final listBounds = tester.getRect(viewport);
      Finder? target;
      for (var attempt = 0; target == null && attempt < 12; attempt++) {
        for (final item in menus.evaluate().toList()) {
          final control = find.byWidget(item.widget);
          final bounds = tester.getRect(control);
          if (bounds.top >= listBounds.top &&
              bounds.bottom <= listBounds.bottom &&
              control.hitTestable().evaluate().isNotEmpty) {
            target = control;
          }
        }
        if (target == null) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: listBounds.center,
              scrollDelta: const Offset(0, 12),
            ),
          );
          await tester.pumpAndSettle();
        }
      }
      expect(
        target,
        isNotNull,
        reason: 'A full menu target must be reachable at $size.',
      );
      await tester.tap(target!, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.commonRename),
        findsOneWidget,
        reason: 'Opening a tile menu at $size must show Rename.',
      );
      expect(find.text(l10n.homeAddSheetNewProject), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonRename), findsNothing);
      expect(add.hitTestable(), findsOneWidget);
      expect(tester.getSize(add).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeAddSheetNewProject), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeAddSheetNewProject), findsNothing);
      expect(tester.takeException(), isNull);
      expect(service.projects, hasLength(2));
      expect(service.trash, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
