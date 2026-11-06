import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  for (final width in [16.0, 32.0, 48.0]) {
    testWidgets('sort menu retains both controls in a $width px title', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fields = <bool>[];
      var directionChanges = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: SortModeControl(
                  sortByName: true,
                  sortAscending: true,
                  onSortByNameChanged: fields.add,
                  onToggleDirection: () => directionChanges++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SortModeControl)),
      )!;
      for (final label in [
        l10n.homeSortFieldUpdated,
        l10n.homeSortFieldName,
        l10n.homeSortDirectionAscTooltip,
      ]) {
        await tester.tap(find.byIcon(Icons.sort_by_alpha));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(fields, [false, true]);
      expect(directionChanges, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'home tabs, selection and favorite details fit narrow and scaled layouts',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final dataDir = Directory.systemTemp.createTempSync(
        'niarim_favorites_layout_',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dataDir.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadAppFonts(tester);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(NiarimApp));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(HomeScreen)),
      )!;
      final service = context.read<ProjectService>();
      final project = await tester.runAsync(
        () => service.createProject(
          name: 'Layout',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 180,
        ),
      );
      await tester.pumpAndSettle();
      for (final size in [
        const Size(240, 844),
        const Size(320, 844),
        const Size(640, 360),
        const Size(1024, 600),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();
          final labels = [
            l10n.homeTabProjects,
            l10n.homeTabWorks,
            l10n.homeTabBookmarked,
          ];
          for (var index = 0; index < labels.length; index++) {
            final label = labels[index];
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(ValueKey('home_tab_$index')),
                matching: find.text(label),
              ),
            );
            expect(
              paragraph.size.width + 0.01,
              greaterThanOrEqualTo(
                paragraph.getMaxIntrinsicWidth(double.infinity),
              ),
              reason: '$label at $size / $scale',
            );
          }
          await tester.longPress(find.text('Layout'));
          await tester.pumpAndSettle();
          expect(find.text(l10n.homeSelectionCount(1)), findsOneWidget);
          await tester.tap(find.text(l10n.homeSelectionAllDeselect));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size / $scale');
        }
      }
      appRouter.go('/project/${project!.id}');
      tester.view.physicalSize = const Size(240, 844);
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectDetailFavoriteUnregistered), findsOneWidget);
      await tester.ensureVisible(
        find.text(l10n.projectDetailFavoriteUnregistered),
      );
      await tester.tap(find.text(l10n.projectDetailFavoriteUnregistered));
      await tester.pumpAndSettle();
      expect(find.text(l10n.projectDetailFavoriteRegistered), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
