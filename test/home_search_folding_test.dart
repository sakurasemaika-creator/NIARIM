import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';

import 'helpers/exported_work_name.dart';
import 'helpers/home_app_harness.dart';

/// ホームの検索は、大文字・小文字、全角・半角、カタカナ・ひらがなの違いを
/// 区別しない（「abc」で「ＡＢＣ全角」、「かたかな」で「ｶﾀｶﾅ半角」が
/// 見つかる）。どのタブの検索も同じ決まり。
void main() {
  Future<void> search(WidgetTester tester, String query) async {
    if (find.byKey(const Key('homeSearchInput')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('homeSearchButton')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('homeSearchInput')), query);
    await tester.pumpAndSettle();
  }

  Finder shown(String name) => find
      .byWidgetPredicate(
        (w) => w is Text && (w.semanticsLabel ?? w.data) == name,
      )
      .hitTestable();

  testWidgets('project and folder names fold case, width and kana', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      seed: (service) async {
        for (final name in ['ＡＢＣ全角', 'ｶﾀｶﾅ半角', 'シーン1', 'ｶﾞｯﾂﾎﾟｰｽﾞ']) {
          await HomeAppHarness.work(service, name);
        }
        await service.createFolder('Ｆｏｌｄｅｒ');
      },
    );
    for (final (query, hit) in [
      ('abc', 'ＡＢＣ全角'),
      ('ＡＢＣ', 'ＡＢＣ全角'),
      ('かたかな', 'ｶﾀｶﾅ半角'),
      ('カタカナ', 'ｶﾀｶﾅ半角'),
      ('しーん', 'シーン1'),
      ('がっつ', 'ｶﾞｯﾂﾎﾟｰｽﾞ'),
      ('folder', 'Ｆｏｌｄｅｒ'),
    ]) {
      await search(tester, query);
      expect(
        HomeAppHarness.inProjects(shown(hit)),
        findsOneWidget,
        reason: query,
      );
    }
    await search(tester, 'しーん2');
    expect(HomeAppHarness.inProjects(shown('シーン1')), findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  Project project(String id, String name, List<String> tags) => Project(
    id: id,
    name: name,
    fps: 12,
    durationSeconds: 1,
    backgroundColor: 0xFFFFFFFF,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    totalWorkSeconds: 0,
    tags: tags,
  );

  testWidgets('tag search folds case, width and kana', (tester) async {
    final projects = [
      project('p1', 'Moonlight', ['ＡＢＣ', 'カタカナ']),
      project('p2', 'School Days', ['School']),
    ];
    for (final query in ['abc', '#ａｂｃ', '＃abc', 'かたかな', 'ｶﾀｶﾅ']) {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ProjectService(),
          child: MaterialApp(
            locale: const Locale('ja'),
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
                searchByTag: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Moonlight'), findsOneWidget, reason: query);
      expect(find.text('School Days'), findsNothing, reason: query);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> openTab(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey('home_tab_$index')));
    await tester.pumpAndSettle();
  }

  testWidgets('works, shares and trash searches fold the same way', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    final exports = Directory('${home.dir.path}/exports')..createSync();
    for (final name in ['ＡＢＣ.gif', 'other.gif']) {
      File('${exports.path}/$name').writeAsBytesSync(
        base64Decode(
          'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        ),
      );
    }
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    await home.open(
      seed: (service) async {
        final shared = await HomeAppHarness.work(service, 'ｶﾀｶﾅ共有');
        await service.saveProject(shared.id);
        final base = await NiaproSerializer.projectsBasePath();
        final data = await NiaproSerializer.load(
          '$base/${shared.id}/${shared.id}.niapro',
        );
        await service.importSharedProject(data);
        await service.deleteProject(shared.id);
        final trashed = await HomeAppHarness.work(service, 'Ｔｒａｓｈ');
        await service.deleteProject(trashed.id);
      },
    );
    // 作品一覧：全角の名前のファイルを半角で探す。
    await openTab(tester, 1);
    await search(tester, 'abc');
    expect(findExportedWorkName('ＡＢＣ.gif').hitTestable(), findsOneWidget);
    expect(findExportedWorkName('other.gif').hitTestable(), findsNothing);
    // 共有：半角カタカナの名前をひらがなで探す。
    await openTab(tester, 2);
    await search(tester, 'かたかな');
    expect(shown('ｶﾀｶﾅ共有'), findsOneWidget);
    // ゴミ箱：全角の名前を小文字で探す。
    await openTab(tester, 3);
    await search(tester, 'trash');
    expect(shown('Ｔｒａｓｈ'), findsOneWidget);
    expect(shown('ｶﾀｶﾅ共有'), findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
