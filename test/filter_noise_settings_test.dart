import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/models/filter_def.dart';
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

  testWidgets('dedicated noise effects keep focused controls while general noise stays configurable', (
    tester,
  ) async {
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
    final filters = panelContext
        .read<FilterService>()
        .filters
        .where((f) => f.kind == FilterKind.noise)
        .toList();
    expect(filters, hasLength(3));
    final gallery = find.byKey(const ValueKey('filter-tile-grid'));
    for (final filter in filters) {
      final card = find.byKey(ValueKey('filter-card-${filter.id}'));
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find.descendant(
          of: gallery,
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        card,
        findsOneWidget,
        reason: '${filter.id} ${filter.name} must be reachable',
      );
      await Scrollable.ensureVisible(tester.element(card), alignment: .5);
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      expect(
        panelContext.read<FilterService>().currentFilter?.id,
        filter.id,
        reason: '${filter.id} ${filter.name} must be selectable through the UI',
      );
      expect(find.byKey(const ValueKey('filter-apply-button')), findsOneWidget);
      final selector = find.byType(DropdownButtonFormField<NoiseStyle>);
      if (filter.id == FilterService.genericNoiseFilterId) {
        expect(selector, findsOneWidget);
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('カラーノイズ').last);
        await tester.pump();
        expect(
          panelContext.read<FilterService>().currentFilter!.noiseStyle,
          NoiseStyle.color,
        );
      } else {
        // Two named effects do not need an algorithm selector.
        expect(selector, findsNothing);
        expect(
          panelContext.read<FilterService>().currentFilter!.noiseStyle,
          filter.id == FilterService.vhsNoiseFilterId
              ? NoiseStyle.vhs
              : NoiseStyle.filmGrain,
        );
      }
      // The gallery remains visible; cancel the temporary selection.
      await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
  test('saved named noise effects are normalized but custom filters are kept',
      () async {
    final grain = FilterService.builtInFilters
        .firstWhere((f) => f.id == FilterService.filmGrainFilterId)
        .copyWith(noiseStyle: NoiseStyle.vhs, strength: 47);
    final vhs = FilterService.builtInFilters
        .firstWhere((f) => f.id == FilterService.vhsNoiseFilterId)
        .copyWith(noiseStyle: NoiseStyle.color, strength: 38);
    const custom = FilterDef(
      id: 'custom-noise',
      name: 'Custom noise',
      kind: FilterKind.noise,
      noiseStyle: NoiseStyle.vhs,
    );
    SharedPreferences.setMockInitialValues({
      'draw_filters': [
        jsonEncode(grain.toJson()),
        jsonEncode(vhs.toJson()),
        jsonEncode(custom.toJson()),
      ],
    });
    final service = FilterService();
    await service.init();

    FilterDef withId(String id) =>
        service.filters.firstWhere((f) => f.id == id);
    expect(
      withId(FilterService.filmGrainFilterId).noiseStyle,
      NoiseStyle.filmGrain,
    );
    expect(withId(FilterService.filmGrainFilterId).strength, 47);
    expect(withId(FilterService.vhsNoiseFilterId).noiseStyle, NoiseStyle.vhs);
    expect(withId(FilterService.vhsNoiseFilterId).strength, 38);
    expect(withId('custom-noise').noiseStyle, NoiseStyle.vhs);

    service.updateFilterParams(
      FilterService.filmGrainFilterId,
      noiseStyle: NoiseStyle.color,
    );
    expect(
      withId(FilterService.filmGrainFilterId).noiseStyle,
      NoiseStyle.filmGrain,
    );
    service.updateFilterParams('custom-noise', noiseStyle: NoiseStyle.color);
    expect(withId('custom-noise').noiseStyle, NoiseStyle.color);

    await Future<void>.delayed(Duration.zero);
    final reopened = FilterService();
    await reopened.init();
    expect(
      reopened.filters
          .firstWhere((f) => f.id == FilterService.vhsNoiseFilterId)
          .noiseStyle,
      NoiseStyle.vhs,
    );
  });
}

class _FilterPanelHarness extends StatelessWidget {
  const _FilterPanelHarness();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
