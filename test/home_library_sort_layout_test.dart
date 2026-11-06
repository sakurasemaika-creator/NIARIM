import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontsLoaded = false;

  Future<AppLocalizations> open(
    WidgetTester tester, {
    required bool trash,
    Locale locale = const Locale('fr'),
    Size size = const Size(320, 844),
    double scale = 2,
    bool seedProjects = false,
    ThemeData? theme,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final directory = Directory.systemTemp.createTempSync(
      'library-sort-layout-',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    final service = await tester.runAsync(() async {
      final service = ProjectService();
      await service.init();
      if (seedProjects) {
        for (final name in ['Gamma', 'Alpha', 'Beta']) {
          final original = await service.createProject(
            name: name,
            fps: 1,
            durationSeconds: 1,
            backgroundColor: 0xFFFFFFFF,
            exportWidth: 64,
            exportHeight: 64,
          );
          await service.saveProject(original.id);
          final base = await NiaproSerializer.projectsBasePath();
          final data = await NiaproSerializer.load(
            '$base/${original.id}/${original.id}.niapro',
          );
          final imported = await service.importSharedProject(data);
          await service.saveProject(imported.id);
          await service.deleteProject(original.id);
        }
        if (!trash) await service.createSharedFolder('Audit folder');
      }
      return service;
    });
    addTearDown(() {
      service!.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectService>.value(value: service!),
          ChangeNotifierProvider(create: (_) => PremiumService()),
        ],
        child: MaterialApp(
          key: ValueKey((trash, locale, size, scale)),
          theme: theme ?? ThemeService().themeData,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: trash ? const TrashScreen() : const SharedScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(trash ? TrashScreen : SharedScreen)),
    )!;
  }

  for (final trash in [false, true]) {
    testWidgets(
      '${trash ? 'Trash' : 'Shared'} screen name stays readable beside sorting',
      (tester) async {
        for (final locale in AppLocalizations.supportedLocales) {
          for (final (size, scale) in [
            (const Size(240, 844), 1.0),
            (const Size(320, 844), 1.0),
            (const Size(320, 844), 2.0),
            (const Size(320, 220), 2.0),
            (const Size(640, 360), 2.0),
            (const Size(1440, 900), 2.0),
          ]) {
            final l10n = await open(
              tester,
              trash: trash,
              locale: locale,
              size: size,
              scale: scale,
            );
            final name = find.text(
              trash ? l10n.homeTabTrash : l10n.homeTabShared,
            );
            final label = tester.renderObject<RenderParagraph>(name);
            expect(
              label.size.width + 0.01,
              greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity)),
              reason:
                  'The actual screen name must remain readable: $trash $locale $size/$scale',
            );
            expect(
              tester
                  .getRect(name)
                  .overlaps(tester.getRect(find.byType(SortModeControl))),
              isFalse,
            );
            expect(tester.takeException(), isNull);
            if (!trash) {
              final favorite = find.byType(FilterChip);
              final before = tester.widget<FilterChip>(favorite).selected;
              await tester.tap(favorite);
              await tester.pumpAndSettle();
              expect(tester.widget<FilterChip>(favorite).selected, !before);
              expect(tester.takeException(), isNull);
            }
            final field = find.byWidgetPredicate(
              (w) => w is PopupMenuButton<bool>,
            );
            final direction = find.widgetWithIcon(
              IconButton,
              Icons.arrow_downward,
            );
            for (final control in [field, direction]) {
              final bounds = tester.getRect(control);
              expect(bounds.width, greaterThanOrEqualTo(48));
              expect(bounds.height, greaterThanOrEqualTo(48));
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(size.width));
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('library sorting has two 48px interactive targets', (
    tester,
  ) async {
    await open(tester, trash: false, locale: const Locale('en'), scale: 1);
    final field = find.byWidgetPredicate((w) => w is PopupMenuButton<bool>);
    final direction = find.widgetWithIcon(IconButton, Icons.arrow_downward);
    final undersized = <String>[];
    for (final (label, control) in [
      ('field', field),
      ('direction', direction),
    ]) {
      final size = tester.getSize(control);
      if (size.width < 48 || size.height < 48) undersized.add('$label: $size');
    }
    expect(
      undersized,
      isEmpty,
      reason: 'Real interactive control bounds, not icon size',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('scaled translated sort labels stay whole or use a named icon', (
    tester,
  ) async {
    await open(tester, trash: false);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final byName in [false, true]) {
        for (final width in [96.0, 132.0, 154.0, 200.0, 240.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey((locale, byName, width, scale)),
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      child: SortModeControl(
                        sortByName: byName,
                        sortAscending: false,
                        onSortByNameChanged: (_) {},
                        onToggleDirection: () {},
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
            final fieldLabel = byName
                ? l10n.homeSortFieldName
                : l10n.homeSortFieldUpdated;
            final scope = '$locale $byName $width/$scale';
            final label = find.text(fieldLabel);
            if (label.evaluate().isNotEmpty) {
              final text = tester.renderObject<RenderParagraph>(label);
              expect(
                text.size.width + .01,
                greaterThanOrEqualTo(
                  text.getMaxIntrinsicWidth(double.infinity),
                ),
                reason: scope,
              );
            } else {
              expect(
                find.byIcon(byName ? Icons.sort_by_alpha : Icons.update),
                findsOneWidget,
                reason: scope,
              );
            }
            final field = find.byTooltip(fieldLabel);
            expect(field, findsOneWidget, reason: scope);
            expect(tester.getSize(field).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(field).height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull, reason: scope);
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Shared favorites use the configured accent foreground', (
    tester,
  ) async {
    final base = ThemeService().themeData;
    const configuredForeground = Color(0xFF164A30);
    await open(
      tester,
      trash: false,
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFFF1D780),
          onPrimary: configuredForeground,
        ),
      ),
    );
    final control = find.byType(FilterChip);
    await tester.tap(control);
    await tester.pumpAndSettle();
    final chip = tester.widget<FilterChip>(control);
    expect(chip.selected, isTrue);
    expect((chip.label as Text).style!.color, configuredForeground);
    expect(chip.checkmarkColor, configuredForeground);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final trash in [false, true]) {
    testWidgets(
      '${trash ? 'Trash' : 'Shared'} sorting changes actual project order without rewriting saves',
      (tester) async {
        final l10n = await open(
          tester,
          trash: trash,
          locale: const Locale('en'),
          scale: 1,
          seedProjects: true,
        );
        final service = tester
            .element(find.byType(trash ? TrashScreen : SharedScreen))
            .read<ProjectService>();
        final base = await tester.runAsync(NiaproSerializer.projectsBasePath);
        final bytes = <String, List<int>>{};
        for (final project in [...service.projects, ...service.trash]) {
          final path = '$base/${project.id}/${project.id}.niapro';
          bytes[path] = File(path).readAsBytesSync();
        }
        void expectOrder(
          List<String> expected, {
          required bool byName,
          required bool ascending,
        }) {
          expect(
            find.text('Gamma'),
            findsOneWidget,
            reason:
                'shared=${service.shared.map((p) => p.name).toList()} trash=${service.trash.map((p) => p.name).toList()} visible=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
          );
          final positions = {
            for (final name in ['Alpha', 'Beta', 'Gamma'])
              name: tester.getTopLeft(find.text(name)).dy,
          };
          final actual = positions.keys.toList()
            ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
          expect(actual, expected);
          final state = tester.widget<SortModeControl>(
            find.byType(SortModeControl),
          );
          expect(state.sortByName, byName);
          expect(state.sortAscending, ascending);
        }

        Future<void> choose(String label) async {
          await tester.tap(
            find.byWidgetPredicate((w) => w is PopupMenuButton<bool>),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        expectOrder(
          ['Beta', 'Alpha', 'Gamma'],
          byName: false,
          ascending: false,
        );
        await choose(l10n.homeSortFieldName);
        expectOrder(['Gamma', 'Beta', 'Alpha'], byName: true, ascending: false);
        await tester.tap(find.byTooltip(l10n.homeSortDirectionDescTooltip));
        await tester.pumpAndSettle();
        expectOrder(['Alpha', 'Beta', 'Gamma'], byName: true, ascending: true);
        if (!trash) {
          await tester.tap(find.text('Audit folder'));
          await tester.pumpAndSettle();
          expect(find.text(l10n.homeSharedFolderEmpty), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expectOrder(
            ['Alpha', 'Beta', 'Gamma'],
            byName: true,
            ascending: true,
          );
        }
        await choose(l10n.homeSortFieldUpdated);
        expectOrder(['Gamma', 'Alpha', 'Beta'], byName: false, ascending: true);
        await tester.tap(find.byTooltip(l10n.homeSortDirectionAscTooltip));
        await tester.pumpAndSettle();
        expectOrder(
          ['Beta', 'Alpha', 'Gamma'],
          byName: false,
          ascending: false,
        );
        for (final entry in bytes.entries) {
          expect(File(entry.key).readAsBytesSync(), entry.value);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Trash card leaves space for a complete short project name', (
    tester,
  ) async {
    await open(
      tester,
      trash: true,
      locale: const Locale('en'),
      scale: 1,
      seedProjects: true,
    );
    final title = tester.renderObject<RenderParagraph>(find.text('Beta'));
    expect(
      title.size.width + 0.01,
      greaterThanOrEqualTo(title.getMaxIntrinsicWidth(double.infinity)),
      reason:
          'Restore/delete actions must not squeeze a four-letter name into a vertical column; actual size ${title.size}',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Trash labels and both actions remain reachable in every locale',
    (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        for (final (size, scale) in [
          (const Size(320, 844), 1.0),
          (const Size(320, 844), 2.0),
          (const Size(320, 220), 2.0),
          (const Size(1440, 900), 2.0),
          (const Size(599, 900), 1.0),
          (const Size(600, 900), 1.0),
          (const Size(601, 900), 1.0),
          (const Size(1199, 900), 2.0),
          (const Size(1200, 900), 2.0),
          (const Size(1201, 900), 2.0),
        ]) {
          final l10n = await open(
            tester,
            trash: true,
            locale: locale,
            size: size,
            scale: scale,
            seedProjects: true,
          );
          final title = tester.renderObject<RenderParagraph>(find.text('Beta'));
          expect(
            title.size.width + 0.01,
            greaterThanOrEqualTo(title.getMaxIntrinsicWidth(double.infinity)),
            reason: '$locale $size/$scale',
          );
          for (final label in [l10n.commonRestore, l10n.homePermanentDelete]) {
            final control = find.widgetWithText(TextButton, label).first;
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
            final rect = tester.getRect(control);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.top, greaterThanOrEqualTo(112));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(tester.widget<TextButton>(control).onPressed, isNotNull);
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale $size/$scale',
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
