import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';

class _Items extends ProjectService {
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
    ),
  ];

  @override
  List<ProjectFolder> get folders => [
    ProjectFolder(id: 'folder', name: 'Folder'),
  ];
}

/// 表示サイズの大・中・小は、どの幅でも見た目が変わること。以前は基準の
/// 幅だけで列数を決めていたため、360pxでは大と中が2列、390〜430pxでは
/// 中と小が3列になり、選んでも何も変わらなかった。
void main() {
  const widths = <double>[240, 320, 360, 390, 412, 430, 600, 844, 1280, 1920];

  testWidgets('large, medium and small cards always differ in width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _Items();
    addTearDown(service.dispose);
    for (final width in widths) {
      tester.view.physicalSize = Size(width, 844);
      final cardWidths = <double>[];
      final folderIcons = <ProjectViewMode, double>{};
      for (final mode in [
        ProjectViewMode.large,
        ProjectViewMode.medium,
        ProjectViewMode.small,
      ]) {
        await tester.pumpWidget(
          ChangeNotifierProvider<ProjectService>.value(
            value: service,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ProjectListWidget(
                  viewMode: mode,
                  sortMode: ProjectSortMode.nameAsc,
                  isSelectionMode: false,
                  selectedIds: const {},
                  onLongPress: (_) {},
                  onSelectionChanged: (_) {},
                  currentFolderId: null,
                  onOpenFolder: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        cardWidths.add(
          tester
              .getSize(
                find.ancestor(
                  of: find.text('Project'),
                  matching: find.byType(Card),
                ),
              )
              .width,
        );
        folderIcons[mode] = tester
            .widget<Icon>(find.byIcon(Icons.folder_rounded))
            .size!;
        expect(tester.takeException(), isNull, reason: '$mode at $width');
      }
      // 大表示の1列のカードではフォルダのアイコンを絵に合わせて大きくし、
      // 中・小は46pxのまま。
      if (width == 390) {
        expect(folderIcons[ProjectViewMode.large], greaterThan(90));
        expect(folderIcons[ProjectViewMode.medium], 46);
        expect(folderIcons[ProjectViewMode.small], 46);
      }
      if (width < 300) continue;
      expect(
        cardWidths[0],
        greaterThan(cardWidths[1]),
        reason: 'large vs medium at $width: $cardWidths',
      );
      expect(
        cardWidths[1],
        greaterThan(cardWidths[2]),
        reason: 'medium vs small at $width: $cardWidths',
      );
    }
  });

  test('phones get one, two and three columns', () {
    for (final width in const <double>[320, 360, 390, 412, 430]) {
      final usable = width - 16;
      expect(
        [
          ProjectListWidget.gridColumnsFor(ProjectViewMode.large, usable),
          ProjectListWidget.gridColumnsFor(ProjectViewMode.medium, usable),
          ProjectListWidget.gridColumnsFor(ProjectViewMode.small, usable),
        ],
        [1, 2, 3],
        reason: '$width',
      );
    }
  });

  test('widths where the sizes already differed keep their columns', () {
    int byExtent(double extent, double usable) =>
        math.max(1, (usable / (extent + 8)).ceil());
    for (var width = 300.0; width <= 2560; width += 4) {
      final usable = width - 16;
      final before = [
        byExtent(240, usable),
        byExtent(170, usable),
        byExtent(130, usable),
      ];
      if (before[0] >= before[1] || before[1] >= before[2]) continue;
      expect(
        [
          ProjectListWidget.gridColumnsFor(ProjectViewMode.large, usable),
          ProjectListWidget.gridColumnsFor(ProjectViewMode.medium, usable),
          ProjectListWidget.gridColumnsFor(ProjectViewMode.small, usable),
        ],
        before,
        reason: '$width',
      );
    }
  });

  testWidgets('a folder without its own colour is the accent in every view', (
    tester,
  ) async {
    // 一覧の行の先頭アイコンはテーマで「アクセントの文字・アイコン色」に
    // なるので、詳細表示のフォルダだけ大・中・小と違う色になっていた。
    final theme = ThemeService();
    addTearDown(theme.dispose);
    theme.previewCurrent(
      AppThemePreset.defaultLight.copyWith(
        accentTextColor: const Color(0xFF123456),
      ),
    );
    final data = theme.themeData;
    final service = _Items();
    addTearDown(service.dispose);
    for (final mode in [
      ProjectViewMode.large,
      ProjectViewMode.medium,
      ProjectViewMode.small,
      ProjectViewMode.detail,
    ]) {
      await tester.pumpWidget(
        ChangeNotifierProvider<ProjectService>.value(
          value: service,
          child: MaterialApp(
            theme: data,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ProjectListWidget(
                viewMode: mode,
                sortMode: ProjectSortMode.nameAsc,
                isSelectionMode: false,
                selectedIds: const {},
                onLongPress: (_) {},
                onSelectionChanged: (_) {},
                currentFolderId: null,
                onOpenFolder: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.folder || w.icon == Icons.folder_rounded),
        ),
      );
      expect(icon.color, data.colorScheme.primary, reason: '$mode');
    }
  });
}
