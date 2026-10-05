import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async =>
              '${Directory.systemTemp.path}/niarim_filter_panel_ui_contract',
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'every built-in filter is reachable by a stable production UI card',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(
          providers: providers!,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: _FilterPanelHarness()),
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(_FilterPanelHarness));
      final projects = context.read<ProjectService>();
      final project = (await tester.runAsync(
        () => projects.createProject(
          name: 'filter-panel-ui-contract',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 96,
          exportHeight: 96,
        ),
      ))!;
      final sceneId = projects.scenesOf(project.id).first.id;
      final layerId = projects
          .layersOf(project.id, sceneId, 0)
          .firstWhere((layer) => layer.type == model.LayerType.normal)
          .id;

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FilterPanel(
                projectId: project.id,
                sceneId: sceneId,
                layerId: layerId,
                frameIndex: 0,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final panelContext = tester.element(find.byType(FilterPanel));
      final filters = panelContext.read<FilterService>().filters;
      expect(filters, isNotEmpty);
      expect(filters.map((f) => f.id).toSet(), hasLength(filters.length));
      final horizontalList = find.byType(ListView).first;
      for (final filter in filters) {
        final card = find.byKey(ValueKey('filter-card-${filter.id}'));
        await tester.scrollUntilVisible(
          card,
          120,
          scrollable: find.descendant(
            of: horizontalList,
            matching: find.byType(Scrollable),
          ),
        );
        expect(
          card,
          findsOneWidget,
          reason: '${filter.id} ${filter.name} must be reachable',
        );
        await tester.ensureVisible(card);
        await tester.pump();
        await tester.ensureVisible(card);
        await tester.pump();
        await tester.tap(card);
        await tester.pump();
        expect(
          panelContext.read<FilterService>().currentFilter?.id,
          filter.id,
          reason:
              '${filter.id} ${filter.name} must be selectable through the UI',
        );
        // Edit mode hides the list; the back button returns to it.
        expect(
          find.byKey(const ValueKey('filter-apply-button')),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey('filter-card-${filter.id}')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('filter-back-to-list')));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tone curve exposes RGB channels and interactive production graph',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(
          providers: providers!,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: _FilterPanelHarness()),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(_FilterPanelHarness));
      final projects = context.read<ProjectService>();
      final project = (await tester.runAsync(
        () => projects.createProject(
          name: 'tone-curve-ui-contract',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 96,
          exportHeight: 96,
        ),
      ))!;
      final sceneId = projects.scenesOf(project.id).first.id;
      final layerId = projects
          .layersOf(project.id, sceneId, 0)
          .firstWhere((layer) => layer.type == model.LayerType.normal)
          .id;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FilterPanel(
                projectId: project.id,
                sceneId: sceneId,
                layerId: layerId,
                frameIndex: 0,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final panelContext = tester.element(find.byType(FilterPanel));
      final service = panelContext.read<FilterService>();
      final tone = service.filters.firstWhere(
        (f) => f.kind == FilterKind.toneCurve,
      );
      final card = find.byKey(ValueKey('filter-card-${tone.id}'));
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find.descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('tone-curve-channel-selector')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tone-curve-editor-0')), findsOneWidget);
      final editor = find.byKey(const ValueKey('tone-curve-editor-0'));
      final box = tester.getRect(editor);
      await tester.tapAt(
        Offset(box.left + box.width * .5, box.top + box.height * .35),
      );
      await tester.pump();
      var current = service.currentFilter!;
      expect(current.toneCurvePoints.length, greaterThan(4));
      await tester.tap(find.text('R'));
      await tester.pump();
      expect(find.byKey(const ValueKey('tone-curve-editor-1')), findsOneWidget);
      final redEditor = find.byKey(const ValueKey('tone-curve-editor-1'));
      final redBox = tester.getRect(redEditor);
      await tester.tapAt(
        Offset(
          redBox.left + redBox.width * .4,
          redBox.top + redBox.height * .6,
        ),
      );
      await tester.pump();
      current = service.currentFilter!;
      expect(current.toneCurveRedPoints.length, greaterThan(4));
      expect(current.toneCurvePoints.length, greaterThan(4));

      final levels = service.filters.firstWhere(
        (f) => f.kind == FilterKind.levels,
      );
      final levelsCard = find.byKey(ValueKey('filter-card-${levels.id}'));
      await tester.tap(find.byKey(const ValueKey('filter-back-to-list')));
      await tester.pump();
      await tester.scrollUntilVisible(
        levelsCard,
        120,
        scrollable: find.descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(levelsCard);
      await tester.pump();
      await tester.tap(levelsCard);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('levels-channel-selector')),
        findsOneWidget,
      );
      await tester.tap(find.text('R'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _FilterPanelHarness extends StatelessWidget {
  const _FilterPanelHarness();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
