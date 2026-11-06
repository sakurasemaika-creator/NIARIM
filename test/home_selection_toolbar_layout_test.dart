import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  Future<AppLocalizations> toolbar(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double width = 320,
    double height = 844,
    double scale = 1,
    int count = 2,
    ThemeData? theme,
    List<String>? actions,
    bool disabled = false,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: HomeSelectionToolbar(
              selectedCount: count,
              onSelectAll: () => actions?.add('all'),
              onDeselectAll: () => actions?.add('none'),
              onCut: disabled ? null : () => actions?.add('cut'),
              onCopy: disabled ? null : () => actions?.add('copy'),
              onTrash: disabled ? null : () => actions?.add('trash'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(HomeSelectionToolbar)),
    )!;
  }

  void resetView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'selection actions fit all 1638 locale size and text conditions',
    (tester) async {
      resetView(tester);
      await loadAppFonts(tester);
      const widths = <double>[
        240,
        280,
        320,
        360,
        375,
        390,
        430,
        480,
        520,
        559,
        560,
        600,
        640,
        641,
        700,
        759,
        760,
        834,
        900,
        1024,
        1180,
        1280,
        1366,
        1440,
        1600,
        1920,
      ];
      var checked = 0;
      for (final locale in AppLocalizations.supportedLocales) {
        for (final width in widths) {
          for (final height in <double>[220, 844, 900]) {
            for (final scale in <double>[1, 1.3, 2]) {
              final l10n = await toolbar(
                tester,
                locale: locale,
                width: width,
                height: height,
                scale: scale,
              );
              final reason = '$locale ${width}x$height scale=$scale';
              final labels = [
                l10n.homeSelectionAllSelect,
                l10n.homeSelectionAllDeselect,
                l10n.commonCut,
                l10n.commonCopy,
                l10n.homeMoveToTrash,
              ];
              final rects = <Rect>[];
              for (final label in labels) {
                final target = find.byTooltip(label);
                expect(target.hitTestable(), findsOneWidget, reason: reason);
                final rect = tester.getRect(target);
                expect(rect.width, greaterThanOrEqualTo(48), reason: reason);
                expect(rect.height, greaterThanOrEqualTo(48), reason: reason);
                expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
                expect(rect.right, lessThanOrEqualTo(width), reason: reason);
                for (final previous in rects) {
                  expect(rect.overlaps(previous), isFalse, reason: reason);
                }
                rects.add(rect);
              }
              for (final element
                  in find
                      .descendant(
                        of: find.byType(HomeSelectionToolbar),
                        matching: find.byType(Text),
                      )
                      .evaluate()) {
                final paragraph = element.renderObject! as RenderParagraph;
                expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
                expect(paragraph.size.width, greaterThan(0), reason: reason);
              }
              expect(tester.takeException(), isNull, reason: reason);
              checked++;
            }
          }
        }
      }
      expect(checked, 1638);
      debugPrint('SELECTION COMPONENT MATRIX $checked conditions PASS');
    },
  );

  testWidgets(
    '28 built-in palettes and custom menu values drive actual controls',
    (tester) async {
      resetView(tester);
      await loadAppFonts(tester);
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.presets, hasLength(28));
      final custom = AppThemePreset.defaultDark.copyWith(
        id: 'selection-custom',
        name: 'Selection custom',
        menuBgColor: const Color(0xFF263747),
        menuTextColor: const Color(0xFFE7C9A3),
        accentColor: const Color(0xFF8BD9B5),
      );
      service.savePreset(custom);
      var checked = 0;
      for (final preset in service.presets) {
        service.applyPreset(preset.id);
        for (final width in <double>[320, 1440]) {
          await toolbar(tester, width: width, theme: service.themeData);
          final container = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(HomeSelectionToolbar),
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(container.color, preset.menuBgColor, reason: preset.id);
          for (final icon in [
            Icons.content_cut,
            Icons.content_copy,
            Icons.delete,
          ]) {
            final actual = IconTheme.of(
              tester.element(find.byIcon(icon)),
            ).color;
            expect(
              actual,
              icon == Icons.delete ? preset.accentColor : preset.menuTextColor,
              reason: preset.id,
            );
          }
          expect(
            tester
                .widget<Text>(find.byKey(const Key('home-selection-count')))
                .style!
                .color,
            preset.menuTextColor,
            reason: preset.id,
          );
          expect(tester.takeException(), isNull, reason: preset.id);
          checked++;
        }
      }
      expect(checked, 58);
    },
  );

  testWidgets(
    'compact controls support keyboard, count semantics and disabled state',
    (tester) async {
      resetView(tester);
      await loadAppFonts(tester);
      final actions = <String>[];
      final l10n = await toolbar(
        tester,
        scale: 2,
        count: 99999,
        actions: actions,
      );
      expect(
        find.bySemanticsLabel(l10n.homeSelectionCount(99999)),
        findsOneWidget,
      );
      for (final expected in ['all', 'none', 'cut', 'copy', 'trash']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(actions.last, expected);
      }
      final disabledL10n = await toolbar(tester, count: 0, disabled: true);
      for (final label in [
        disabledL10n.commonCut,
        disabledL10n.commonCopy,
        disabledL10n.homeMoveToTrash,
      ]) {
        final button = find.ancestor(
          of: find.byTooltip(label),
          matching: find.byType(IconButton),
        );
        expect(tester.widget<IconButton>(button).onPressed, isNull);
        expect(
          tester
              .getSemantics(button)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'French expanded Home selection controls stay visually identifiable',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'fr',
        'force_pc_mode': 0,
        'is_premium': true,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final directory = Directory.systemTemp.createTempSync(
        'selection-toolbar-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        directory.deleteSync(recursive: true);
      });
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadAppFonts(tester);
      final owned = <ChangeNotifier>[];
      final providers = await tester.runAsync(
        () => buildAppProviders(debugOnCreated: owned.add),
      );
      addTearDown(() {
        for (final notifier in owned.reversed) {
          notifier.dispose();
        }
      });
      appRouter.go('/home');
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(HomeScreen));
      final service = context.read<ProjectService>();
      final l10n = AppLocalizations.of(context)!;
      await tester.runAsync(() async {
        final target = await service.createProject(
          name: 'TARGET',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFF123456,
          exportWidth: 64,
          exportHeight: 64,
        );
        await service.setFavorite(target.id, true);
        final folder = await service.createFolder('Folder');
        await service.createProject(
          name: 'OTHER',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFF123456,
          exportWidth: 64,
          exportHeight: 64,
        );
        final child = await service.createProject(
          name: 'TARGET CHILD',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFF123456,
          exportWidth: 64,
          exportHeight: 64,
        );
        await service.moveToFolder(child.id, folder.id);
        final base = await NiaproSerializer.projectsBasePath();
        final data = await NiaproSerializer.load(
          '$base/${target.id}/${target.id}.niapro',
        );
        final shared = await service.importSharedProject(data);
        await service.saveProject(shared.id);
      });
      await tester.pumpAndSettle();
      await tester.longPress(find.text('TARGET'));
      await tester.pumpAndSettle();
      // The controls must remain reachable in the real Home Scaffold, where
      // floating actions can otherwise cover a second toolbar row.
      tester.view.physicalSize = const Size(240, 220);
      await tester.pumpAndSettle();
      for (final label in [
        l10n.commonCut,
        l10n.commonCopy,
        l10n.homeMoveToTrash,
      ]) {
        expect(
          find.byTooltip(label).hitTestable(),
          findsOneWidget,
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(320, 844);
      await tester.pumpAndSettle();
      for (final label in [
        l10n.homeSelectionAllSelect,
        l10n.homeSelectionAllDeselect,
      ]) {
        final control = find.byTooltip(label);
        expect(control.hitTestable(), findsOneWidget, reason: label);
        final text = find.descendant(of: control, matching: find.text(label));
        if (text.evaluate().isNotEmpty) {
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          expect(paragraph.size.width, greaterThan(0));
        } else {
          expect(
            find
                .descendant(of: control, matching: find.byType(Icon))
                .hitTestable(),
            findsOneWidget,
            reason: 'A compact alternative needs a visible, accessible icon.',
          );
        }
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      }
      Future<void> selectAllCount(int count) async {
        await tester.tap(find.byTooltip(l10n.homeSelectionAllSelect));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const Key('home-selection-count')))
              .data,
          '$count',
          reason:
              'Select All must use the visible scope, including filters and excluding shared imports.',
        );
      }

      Future<void> deselect() async {
        await tester.tap(find.byTooltip(l10n.homeSelectionAllDeselect));
        await tester.pumpAndSettle();
        expect(find.byType(HomeSelectionToolbar), findsNothing);
      }

      await selectAllCount(3);
      await tester.tap(find.widgetWithText(FilterChip, l10n.homeFavoritesOnly));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSelectionToolbar), findsNothing);
      await tester.longPress(find.text('TARGET'));
      await tester.pumpAndSettle();
      await selectAllCount(1);
      await tester.tap(find.widgetWithText(FilterChip, l10n.homeFavoritesOnly));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSelectionToolbar), findsNothing);
      await tester.longPress(find.text('OTHER'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSelectionToolbar), findsNothing);
      await tester.enterText(find.byType(TextField), 'TARGET');
      await tester.pumpAndSettle();
      await tester.longPress(find.text('TARGET CHILD'));
      await tester.pumpAndSettle();
      await selectAllCount(2);
      await tester.enterText(find.byType(TextField), 'OTHER');
      await tester.pumpAndSettle();
      expect(find.byType(HomeSelectionToolbar), findsNothing);
      final visibleOther = find.descendant(
        of: find.byType(ProjectListWidget),
        matching: find.text('OTHER'),
      );
      expect(visibleOther.hitTestable(), findsOneWidget);
      await tester.longPress(visibleOther);
      await tester.pumpAndSettle();
      await selectAllCount(1);
      await deselect();
      expect(service.projects, hasLength(4));
      expect(service.trash, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
