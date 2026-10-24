import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GridProjects extends ProjectService {
  final favoriteIds = <String>{};
  final favoriteCalls = <String>[];

  @override
  List<Project> get projects => [
    Project(
      id: 'project',
      name: 'Project',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      totalWorkSeconds: 0,
      isFavorite: favoriteIds.contains('project'),
    ),
  ];

  @override
  List<ProjectFolder> get folders => [
    ProjectFolder(
      id: 'folder',
      name: 'Folder',
      isFavorite: favoriteIds.contains('folder'),
    ),
  ];

  Future<void> _toggle(String id) async {
    favoriteCalls.add(id);
    if (!favoriteIds.remove(id)) favoriteIds.add(id);
    notifyListeners();
  }

  @override
  Future<void> toggleFavorite(String id) => _toggle(id);

  @override
  Future<void> toggleFolderFavorite(String id) => _toggle(id);
}

Widget _host(
  _GridProjects service,
  ProjectViewMode mode, {
  required ValueChanged<String> onOpenFolder,
  required ValueChanged<String> onSelectionChanged,
  bool isSelectionMode = false,
  Set<String> selectedIds = const {},
  ThemeData? theme,
  ValueChanged<String>? onPickProject,
}) => ChangeNotifierProvider<ProjectService>.value(
  value: service,
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProjectListWidget(
        viewMode: mode,
        sortMode: ProjectSortMode.nameAsc,
        isSelectionMode: isSelectionMode,
        selectedIds: selectedIds,
        onLongPress: (_) {},
        onSelectionChanged: onSelectionChanged,
        currentFolderId: null,
        onOpenFolder: onOpenFolder,
        onPickProject: onPickProject,
      ),
    ),
  ),
);

Finder _card(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Card));

Finder _menu(String name) => find.descendant(
  of: _card(name),
  matching: find.byType(PopupMenuButton<String>),
);

void main() {
  for (final mode in [
    ProjectViewMode.large,
    ProjectViewMode.medium,
    ProjectViewMode.small,
  ]) {
    testWidgets(
      '${mode.name}: card menus toggle each item without opening it',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _GridProjects();
        addTearDown(service.dispose);
        final opened = <String>[];
        final selected = <String>[];
        await tester.pumpWidget(
          _host(
            service,
            mode,
            onOpenFolder: opened.add,
            onSelectionChanged: selected.add,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
        expect(find.byIcon(Icons.star), findsNothing);
        final l10n = AppLocalizations.of(tester.element(_card('Project')))!;

        for (final name in ['Project', 'Folder']) {
          await tester.tap(_menu(name));
          await tester.pump(
            kDoubleTapTimeout + const Duration(milliseconds: 1),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.colorPickerFavoriteAdd));
          await tester.pumpAndSettle();
          final star = find.descendant(
            of: _card(name),
            matching: find.byIcon(Icons.star),
          );
          expect(star, findsOneWidget);
          expect(
            tester.getRect(star).top,
            greaterThan(tester.getRect(_menu(name)).bottom),
          );
          expect(
            tester
                .getRect(_card(name))
                .contains(tester.getRect(star).bottomRight),
            isTrue,
          );
        }
        expect(service.favoriteIds, {'project', 'folder'});

        for (final name in ['Project', 'Folder']) {
          await tester.tap(_menu(name));
          await tester.pump(
            kDoubleTapTimeout + const Duration(milliseconds: 1),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.colorPickerFavoriteRemove));
          await tester.pumpAndSettle();
        }
        expect(find.byIcon(Icons.star), findsNothing);
        expect(service.favoriteCalls, [
          'project',
          'folder',
          'project',
          'folder',
        ]);
        expect(opened, isEmpty);
        expect(selected, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mode in [
    ProjectViewMode.large,
    ProjectViewMode.medium,
    ProjectViewMode.small,
  ]) {
    testWidgets('${mode.name}: selection stars stay at the top right', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = _GridProjects()
        ..favoriteIds.addAll(['project', 'folder']);
      addTearDown(service.dispose);
      final selected = <String>[];
      for (final size in [
        const Size(240, 844),
        const Size(320, 844),
        const Size(390, 844),
        const Size(640, 360),
        const Size(1280, 720),
        const Size(2560, 900),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(
            _host(
              service,
              mode,
              isSelectionMode: true,
              onOpenFolder: (_) =>
                  fail('Folder should not open while selecting'),
              onSelectionChanged: selected.add,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(find.byIcon(Icons.star), findsNWidgets(2));
          selected.clear();
          for (final name in ['Folder', 'Project']) {
            final star = find.descendant(
              of: _card(name),
              matching: find.byIcon(Icons.star),
            );
            final cardRect = tester.getRect(_card(name));
            final starRect = tester.getRect(star);
            expect(
              starRect.top - cardRect.top,
              lessThan(16),
              reason: '$name at $size / $scale',
            );
            expect(
              cardRect.right - starRect.right,
              lessThan(16),
              reason: '$name at $size / $scale',
            );
            expect(
              cardRect.contains(starRect.topLeft) &&
                  cardRect.contains(starRect.bottomRight),
              isTrue,
            );
            await tester.tap(star);
          }
          await tester.pumpAndSettle();
          expect(selected, ['folder', 'project']);
          expect(service.favoriteCalls, isEmpty);
          expect(tester.takeException(), isNull, reason: '$size / $scale');
        }
      }
    });
  }

  testWidgets('favorite stars use the theme accent, never a fixed yellow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final themeService = ThemeService();
    addTearDown(themeService.dispose);
    await themeService.init();
    final projects = _GridProjects()
      ..favoriteIds.addAll(['project', 'folder']);
    addTearDown(projects.dispose);

    // Match NiarimApp: ThemeService notifies a listener which rebuilds
    // MaterialApp, rather than substituting an independent static theme.
    await tester.pumpWidget(AnimatedBuilder(
      animation: themeService,
      builder: (context, _) => _host(
        projects,
        ProjectViewMode.medium,
        theme: themeService.themeData,
        onOpenFolder: (_) {},
        onSelectionChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    for (final accent in [
      const Color(0xFFE53935),
      const Color(0xFF2867DA),
    ]) {
      // 星は背景の上のアイコンなので「アクセントの文字・アイコン色」で描く。
      // 既定のテーマはこの色を指定しているので、未指定（＝差し色に従う）にする。
      themeService.previewCurrent(
        AppThemePreset.defaultLight.copyWith(
          accentColor: accent,
          accentTextColor: null,
        ),
      );
      await tester.pumpAndSettle();
      // Check both the service's source-of-truth theme and actual widget tree.
      expect(themeService.current.accentColor, accent);
      expect(themeService.themeData.colorScheme.primary, accent);
      for (final name in ['Project', 'Folder']) {
        final star = find.descendant(
          of: _card(name), matching: find.byIcon(Icons.star));
        expect(star, findsOneWidget, reason: '$name with $accent');
        expect(Theme.of(tester.element(star)).colorScheme.primary, accent,
          reason: '$name must receive the active ThemeData');
        expect(tester.widget<Icon>(star).color, accent,
          reason: '$name must use the selected accent');
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selected project and folder checks follow custom selection colors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    const selectedBg = Color(0xFF334455);
    const selectedForeground = Color(0xFFF1B777);
    final themeService = ThemeService();
    addTearDown(themeService.dispose);
    await themeService.init();
    themeService.previewCurrent(AppThemePreset.defaultLight.copyWith(
      accentColor: const Color(0xFFEE5577),
      buttonTextColor: Colors.white,
      selectionColor: selectedBg,
      selectionTextColor: selectedForeground,
    ));
    final projectService = _GridProjects();
    addTearDown(projectService.dispose);
    await tester.pumpWidget(_host(
      projectService,
      ProjectViewMode.medium,
      isSelectionMode: true,
      selectedIds: const {'project', 'folder'},
      theme: themeService.themeData,
      onOpenFolder: (_) {},
      onSelectionChanged: (_) {},
    ));
    await tester.pumpAndSettle();
    for (final name in ['Project', 'Folder']) {
      final check = find.descendant(
        of: _card(name), matching: find.byIcon(Icons.check));
      expect(check, findsOneWidget);
      expect(tester.widget<Icon>(check).color, selectedForeground);
      // Project badge uses AnimatedContainer, folder badge uses Container.
      final anim = tester.widgetList<AnimatedContainer>(
        find.ancestor(of: check, matching: find.byType(AnimatedContainer)));
      final containers = tester.widgetList<Container>(
        find.ancestor(of: check, matching: find.byType(Container)));
      final hasSelectedFill = [
        ...anim.map((w) => w.decoration),
        ...containers.map((w) => w.decoration),
      ].any((decoration) =>
          decoration is BoxDecoration && decoration.color == selectedBg);
      expect(hasSelectedFill, isTrue, reason: '$name selection background');
    }
    final checkboxTheme = themeService.themeData.checkboxTheme;
    expect(
      checkboxTheme.fillColor!.resolve({WidgetState.selected}), selectedBg);
    expect(
      checkboxTheme.checkColor!.resolve({WidgetState.selected}),
      selectedForeground);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project picker keeps editing menus hidden', (tester) async {
    final service = _GridProjects();
    addTearDown(service.dispose);
    final picked = <String>[];
    await tester.pumpWidget(
      _host(
        service,
        ProjectViewMode.small,
        onOpenFolder: (_) {},
        onSelectionChanged: (_) {},
        onPickProject: picked.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(picked, ['project']);
    expect(tester.takeException(), isNull);
  });
}
