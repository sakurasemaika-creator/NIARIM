import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';

Project _project(String id, String name, List<String> tags) => Project(
      id: id,
      name: name,
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      totalWorkSeconds: 0,
      tags: tags,
    );

Widget _host({required String query, required bool byTag}) {
  final projects = [
    _project('p1', 'Moonlight', ['Fantasy', 'Night']),
    _project('p2', 'School Days', ['School']),
  ];
  return ChangeNotifierProvider(
    create: (_) => ProjectService(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProjectListWidget(
          projects: projects,
          viewMode: ProjectViewMode.detail,
          sortMode: ProjectSortMode.nameAsc,
          isSelectionMode: false,
          selectedIds: const {},
          onLongPress: (_) {},
          onSelectionChanged: (_) {},
          currentFolderId: null,
          onOpenFolder: (_) {},
          searchQuery: query,
          searchByTag: byTag,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tag mode matches saved tags across projects', (tester) async {
    await tester.pumpWidget(_host(query: 'fantasy', byTag: true));
    await tester.pumpAndSettle();

    expect(find.text('Moonlight'), findsOneWidget);
    expect(find.text('School Days'), findsNothing);
  });

  testWidgets('tag mode accepts a leading hash and ignores case', (tester) async {
    await tester.pumpWidget(_host(query: '#NIGHT', byTag: true));
    await tester.pumpAndSettle();

    expect(find.text('Moonlight'), findsOneWidget);
    expect(find.text('School Days'), findsNothing);
  });

  testWidgets('keyword mode does not treat project tags as names', (tester) async {
    await tester.pumpWidget(_host(query: 'fantasy', byTag: false));
    await tester.pumpAndSettle();

    expect(find.text('Moonlight'), findsNothing);
    expect(find.text('School Days'), findsNothing);
  });
}
