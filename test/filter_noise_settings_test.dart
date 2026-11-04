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
    expect(filters, hasLength(1));
    expect(panelContext.read<FilterService>().filters, hasLength(26));
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
      final selector = find.byKey(const ValueKey('noise-style-option-color'));
      expect(find.byKey(const ValueKey('noise-style-option-filmGrain')), findsOneWidget);
      expect(find.byKey(const ValueKey('noise-style-option-vhs')), findsOneWidget);
      if (filter.id == FilterService.genericNoiseFilterId) {
        expect(selector, findsOneWidget);
        for (final style in [
          NoiseStyle.filmGrain,
          NoiseStyle.vhs,
          NoiseStyle.color,
        ]) {
          final choice = find.byKey(ValueKey('noise-style-option-${style.name}'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pump();
          expect(panelContext.read<FilterService>().currentFilter!.noiseStyle, style);
          expect(
            find.textContaining('走査線'),
            style == NoiseStyle.vhs ? findsOneWidget : findsNothing,
          );
        }
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
    final template = FilterService.builtInFilters.firstWhere(
      (f) => f.id == FilterService.genericNoiseFilterId,
    );
    final grain = template.copyWith(
      id: FilterService.filmGrainFilterId,
      name: 'フィルムグレイン',
      noiseStyle: NoiseStyle.filmGrain,
      strength: 47,
      isFavorite: true,
    );
    final vhs = template.copyWith(
      id: FilterService.vhsNoiseFilterId,
      name: 'VHSノイズ',
      noiseStyle: NoiseStyle.vhs,
      strength: 38,
      caSaturation: 62,
    );
    final color = template.copyWith(strength: 21);
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
        jsonEncode(color.toJson()),
        jsonEncode(custom.toJson()),
      ],
    });
    final service = FilterService();
    await service.init();

    FilterDef noise() => service.filters.firstWhere(
      (f) => f.id == FilterService.genericNoiseFilterId,
    );
    expect(service.filters, hasLength(27)); // 26 built-ins and one custom
    expect(service.filters.where((f) => f.kind == FilterKind.noise), hasLength(2));
    expect(noise().isFavorite, isTrue);
    expect(service.filters.any((f) => f.id == FilterService.filmGrainFilterId), isFalse);
    expect(service.filters.any((f) => f.id == FilterService.vhsNoiseFilterId), isFalse);
    expect(service.filters.firstWhere((f) => f.id == 'custom-noise').noiseStyle, NoiseStyle.vhs);
    // Legacy names still resolve internally for older recorded operations.
    service.selectFilter(FilterService.vhsNoiseFilterId);
    expect(service.currentFilter!.strength, 38);
    service.clearCurrentFilter();

    service.selectNoiseStyle(FilterService.genericNoiseFilterId, NoiseStyle.filmGrain);
    expect(noise().strength, 47);
    service.updateFilterParams(FilterService.genericNoiseFilterId, strength: 49);
    service.selectNoiseStyle(FilterService.genericNoiseFilterId, NoiseStyle.vhs);
    expect(noise().strength, 38);
    expect(noise().caSaturation, 62);
    service.selectNoiseStyle(FilterService.genericNoiseFilterId, NoiseStyle.color);
    expect(noise().strength, 21);
    service.selectNoiseStyle(FilterService.genericNoiseFilterId, NoiseStyle.filmGrain);
    expect(noise().strength, 49);
    service.toggleFavorite(FilterService.genericNoiseFilterId);
    expect(noise().isFavorite, isFalse);

    await Future<void>.delayed(Duration.zero);
    final reopened = FilterService();
    await reopened.init();
    final restored = reopened.filters.firstWhere(
      (f) => f.id == FilterService.genericNoiseFilterId,
    );
    expect(restored.isFavorite, isFalse);
    reopened.selectNoiseStyle(FilterService.genericNoiseFilterId, NoiseStyle.vhs);
    expect(reopened.filters.firstWhere((f) => f.id == FilterService.genericNoiseFilterId).caSaturation, 62);
    reopened.selectNoiseStyle(FilterService.genericNoiseFilterId, NoiseStyle.color);
    expect(reopened.filters.firstWhere((f) => f.id == FilterService.genericNoiseFilterId).strength, 21);
  });
}

class _FilterPanelHarness extends StatelessWidget {
  const _FilterPanelHarness();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
