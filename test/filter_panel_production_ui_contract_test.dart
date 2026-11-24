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
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/widgets/filter_sample_preview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// The gallery's scrolling grid (its cards are built as they scroll in).
final _galleryScrollable = find.descendant(
  of: find.byKey(const ValueKey('filter-tile-grid')),
  matching: find.byType(Scrollable),
);

Future<void> _tapFilterCard(WidgetTester tester, Finder card) async {
  // NIARIMならではのフィルターが一覧の先に並ぶので、ほかのカードは一覧を
  // 送って探す。
  if (card.evaluate().isEmpty) {
    await tester.scrollUntilVisible(card, 120, scrollable: _galleryScrollable);
  }
  await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
  await tester.pump();
  expect(card.hitTestable(), findsOneWidget);
  await tester.tap(card);
  await tester.pump();
}

class _FilterAccess extends PremiumService {
  @override
  bool isFeatureAvailable(PremiumFeature feature) =>
      feature == PremiumFeature.toneCurve ||
      feature == PremiumFeature.levelAdjustment;
}

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
    'named settings show thumbnails and are recalled without changing the saved copy',
    (tester) async {
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: FilterPanel(
                  projectId: '',
                  sceneId: '',
                  layerId: null,
                  frameIndex: 0,
                  onClose: _doNothing,
                  onCanvasPreviewChanged: (image) => image?.dispose(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FilterPanel));
      final service = context.read<FilterService>();
      final l10n = AppLocalizations.of(context)!;
      await _tapFilterCard(
        tester,
        find.byKey(const ValueKey('filter-card-Filter0001')),
      );
      final dialog = find.byType(AlertDialog);
      final save = find.byKey(const ValueKey('filter-save-settings'));
      final load = find.byKey(const ValueKey('filter-load-settings'));
      await tester.tap(load);
      await tester.pumpAndSettle();
      expect(find.text(l10n.filterSettingsEmpty), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing, reason: 'closed empty settings list');

      for (final (name, strength) in [('弱いぼかし', 3.0), ('夕焼け用', 18.0)]) {
        service.updateFilterParams('Filter0001', strength: strength);
        await tester.pump();
        expect(
          save.hitTestable(),
          findsOneWidget,
          reason: 'open save for $name',
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget, reason: 'name dialog for $name');
        await tester.enterText(find.byType(TextField), name);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
        await pumpRealAsync(tester, const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing, reason: 'saved $name');
      }
      expect(service.savedSettingsFor(FilterKind.gaussianBlur).length, 2);
      await tester.tap(load);
      await tester.pumpAndSettle();
      final thumbnails = find.descendant(
        of: dialog,
        matching: find.byType(FilterSamplePreview),
      );
      expect(thumbnails, findsNWidgets(2));
      for (var attempt = 0; attempt < 20; attempt++) {
        if (find
                .descendant(of: thumbnails, matching: find.byType(RawImage))
                .evaluate()
                .length ==
            2) {
          break;
        }
        await pumpRealAsync(tester, const Duration(milliseconds: 100));
      }
      expect(
        find.descendant(of: thumbnails, matching: find.byType(RawImage)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: dialog, matching: find.text('夕焼け用')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('弱いぼかし')),
      );
      await tester.pumpAndSettle();
      final id = service.currentFilter!.id;
      expect(service.currentFilter!.strength, 3);
      service.updateFilterParams(id, strength: 26);
      await tester.pumpAndSettle();
      expect(service.currentFilter!.strength, 26);
      await tester.tap(load);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('弱いぼかし')),
      );
      await tester.pumpAndSettle();
      expect(service.currentFilter!.strength, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gallery duplicates, renames and deletes custom filters', (
    tester,
  ) async {
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: FilterPanel(
                projectId: '',
                sceneId: '',
                layerId: null,
                frameIndex: 0,
                onClose: _doNothing,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final service = tester
        .element(find.byType(FilterPanel))
        .read<FilterService>();
    final l10n = AppLocalizations.of(tester.element(find.byType(FilterPanel)))!;

    Future<void> openMenu(String id) async {
      await tester.longPress(find.byKey(ValueKey('filter-card-$id')));
      await tester.pumpAndSettle();
    }

    // ガウスぼかしのカード（NIARIMならではのフィルターの後に並ぶ）。
    final gaussianCard = find.byKey(const ValueKey('filter-card-Filter0001'));
    await tester.scrollUntilVisible(
      gaussianCard,
      120,
      scrollable: _galleryScrollable,
    );
    await tester.ensureVisible(gaussianCard);
    await tester.pumpAndSettle();
    final favoriteFinder = find.byKey(
      const ValueKey('filter-favorite-Filter0001'),
    );
    final favorite = tester.getRect(favoriteFinder);
    expect(find.byKey(const ValueKey('filter-menu-Filter0001')), findsNothing);
    // The card's tap surface lies over the picture and name in one stack.
    final gaussianTile = find
        .ancestor(of: gaussianCard, matching: find.byType(Stack))
        .first;
    final preview = tester.getRect(
      find.descendant(
        of: gaussianTile,
        matching: find.byType(FilterSamplePreview),
      ),
    );
    final filterName = tester.getRect(
      find.descendant(
        of: gaussianTile,
        matching: find.text(l10n.filterNameGaussianBlur),
      ),
    );
    // The star is drawn in the name row's leading slot, below the picture
    // and before the name, and keeps a 48x48 touch target on every platform
    // (Android pads smaller buttons to 48x48, which used to push the star
    // onto the name).
    final star = tester.getRect(
      find.descendant(of: favoriteFinder, matching: find.byType(Icon)),
    );
    expect(star.top, greaterThanOrEqualTo(preview.bottom));
    expect(
      filterName.left - star.right,
      greaterThanOrEqualTo(6),
      reason: 'the star stays in its slot instead of touching the name',
    );
    expect(
      (star.center.dy - filterName.center.dy).abs(),
      lessThan(3),
      reason: 'the favorite star and filter name share one row',
    );
    expect(favorite.width, greaterThanOrEqualTo(48));
    expect(favorite.height, greaterThanOrEqualTo(48));

    await openMenu('Filter0001');
    expect(find.text(l10n.commonRename), findsNothing);
    expect(find.text(l10n.commonDelete), findsNothing);
    await tester.tap(find.text(l10n.commonDuplicate));
    await tester.pumpAndSettle();
    final copy = service.filters.singleWhere((f) => !service.isBuiltIn(f.id));
    expect(
      find.text(l10n.projectDuplicateName(l10n.filterNameGaussianBlur)),
      findsOneWidget,
    );

    await openMenu(copy.id);
    await tester.tap(find.text(l10n.commonRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, l10n.commonSave),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Soft shading');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Soft shading'), findsOneWidget);

    await openMenu(copy.id);
    await tester.tap(find.text(l10n.commonDuplicate));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.projectDuplicateName('Soft shading')),
      findsOneWidget,
    );

    await openMenu(copy.id);
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.text('Soft shading'), findsOneWidget);
    await openMenu(copy.id);
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(find.text('Soft shading'), findsNothing);
    expect(find.text(l10n.filterNameGaussianBlur), findsOneWidget);

    final restored = FilterService();
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.filters.any((f) => f.id == copy.id), isFalse);
    expect(restored.filters.any((f) => f.name == 'Soft shading (コピー)'), isTrue);
    expect(tester.takeException(), isNull);
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
          providers: [
            ...providers,
            ChangeNotifierProvider<PremiumService>(
              create: (_) => _FilterAccess(),
            ),
          ],
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
      expect(service.currentFilter, isNull);
      expect(find.byKey(const ValueKey('filter-apply-button')), findsNothing);
      final filters = service.filters;
      expect(filters, isNotEmpty);
      expect(filters.map((f) => f.id).toSet(), hasLength(filters.length));
      final gallery = find.byKey(const ValueKey('filter-tile-grid'));
      expect(gallery, findsOneWidget);
      expect(tester.widget<GridView>(gallery).scrollDirection, Axis.vertical);
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
        await _tapFilterCard(tester, card);
        expect(
          panelContext.read<FilterService>().currentFilter?.id,
          filter.id,
          reason:
              '${filter.id} ${filter.name} must be selectable through the UI',
        );
        // Preview mode removes the tile gallery to give the canvas more
        // space. The user returns to the same gallery by cancelling.
        expect(
          find.byKey(const ValueKey('filter-apply-button')),
          findsOneWidget,
        );
        if (filter.kind == FilterKind.outline ||
            filter.kind == FilterKind.inkPool) {
          // This isolated panel does not provide a canvas-pick callback:
          // an eyedropper button would misleadingly do nothing on tap.
          expect(
            find.descendant(
              of: find.byType(FilterPanel),
              matching: find.byIcon(Icons.colorize),
            ),
            findsNothing,
          );
        }
        expect(
          find.byKey(const ValueKey('filter-cancel-button')),
          findsOneWidget,
        );
        expect(gallery, findsNothing);
        expect(
          find.byKey(const ValueKey('noise-style-option-color')),
          filter.kind == FilterKind.noise ? findsOneWidget : findsNothing,
          reason: '${filter.id}: Noise has the three radio options',
        );
        expect(
          find.byKey(const ValueKey('filter-collapse-button')),
          filter.id == 'Filter0025' ? findsNothing : findsOneWidget,
          reason: '${filter.id}: one-step inversion must not collapse',
        );
        if (filter.id == 'Filter0025') {
          // Color invert uses the tone-curve engine internally, but is a
          // one-tap operation, not an editable RGB curve.
          expect(
            find.byKey(const ValueKey('tone-curve-channel-selector')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('tone-curve-editor-0')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('filter-undo-button')),
            findsNothing,
          );
        }
        await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
        await tester.pump();
        expect(panelContext.read<FilterService>().currentFilter, isNull);
        expect(gallery, findsOneWidget);
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
          providers: [
            ...providers,
            ChangeNotifierProvider<PremiumService>(
              create: (_) => _FilterAccess(),
            ),
          ],
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
          of: find.byKey(const ValueKey('filter-tile-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      await _tapFilterCard(tester, card);
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
      await tester.ensureVisible(redEditor);
      await tester.pump();
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
      // A long press on a point (not an end) deletes it, as the hint says.
      final l10n = AppLocalizations.of(panelContext)!;
      expect(find.text(l10n.filterToneCurveHint), findsOneWidget);
      await tester.longPressAt(
        Offset(
          redBox.left + redBox.width * .4,
          redBox.top + redBox.height * .6,
        ),
      );
      await tester.pump();
      expect(service.currentFilter!.toneCurveRedPoints, const [0, 0, 1, 1]);

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
          of: find.byKey(const ValueKey('filter-tile-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      await _tapFilterCard(tester, levelsCard);
      expect(
        find.byKey(const ValueKey('levels-channel-selector')),
        findsOneWidget,
      );
      // The gamma is a fraction and shows its decimals (1.4 is not "1").
      expect(find.text('${l10n.filterLevelsGamma}: 1.00'), findsOneWidget);
      service.updateFilterParams(service.currentFilter!.id, inputGamma: 1.4);
      await tester.pump();
      expect(find.text('${l10n.filterLevelsGamma}: 1.40'), findsOneWidget);
      await tester.tap(find.text('R'));
      await tester.pump();
      expect(find.text(l10n.filterLevelsHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _doNothing() {}

class _FilterPanelHarness extends StatelessWidget {
  const _FilterPanelHarness();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
