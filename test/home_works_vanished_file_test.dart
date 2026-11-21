import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/widgets/sort_mode_control.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

/// 作品一覧が読んだ後で、アプリの外（ファイルの管理アプリ・別のアプリ）で
/// 書き出したファイルが消えても、作品一覧は組み立てられ、消えたファイルは
/// 出さない（書き出したファイルの一覧〔`ExportStorage.listFiles`〕にも、
/// フォルダの表紙の候補にも、消えたファイルは入らない）。
///
/// 外部の変更を非同期で読み直す入口（並べ替え、タブへの戻り、
/// フォルダを開く）から消えたファイルが取り除かれることを確認する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<String> shown(WidgetTester tester) => tester
      .widgetList<ExportedWorkCard>(find.byType(ExportedWorkCard))
      .map((card) => card.name)
      .toList();

  SortModeControl worksSort(WidgetTester tester) =>
      tester.widget<SortModeControl>(
        find.descendant(
          of: find.ancestor(
            of: find.byKey(const Key('worksFavoritesOnlyFilter')),
            matching: find.byKey(const Key('homeCollectionSortHeader')),
          ),
          matching: find.byType(SortModeControl),
        ),
      );

  /// 書き出したファイルの更新日時（a・b・cの順に新しい）。
  void stamp(HomeClipboardHarness home) {
    final now = DateTime.now();
    for (final (i, name) in ['a.gif', 'b.gif', 'c.gif'].indexed) {
      File(
        '${home.dir.path}/exports/$name',
      ).setLastModifiedSync(now.subtract(Duration(hours: 10 - i)));
    }
  }

  testWidgets('a works file removed outside the app is not listed in any '
      'sort order, and the Works tab still builds', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['a.gif', 'b.gif', 'c.gif'],
    );
    stamp(home);
    await tester.runAsync(
      () => ExportEngine.listExportedFiles(forceRefresh: true),
    );
    await home.showTab(1);
    expect(shown(tester), ['c.gif', 'b.gif', 'a.gif']);

    // 作品一覧が覚えている一覧（読み直していない）のまま、ファイルだけが消える。
    File('${home.dir.path}/exports/b.gif').deleteSync();

    // 新しい順（既定）→名前の降順→名前の昇順→古い順。どれも作品一覧が
    // 覚えている一覧を使ってすぐ描画し、ファイルの変更は非同期で反映する。
    final orders = <String, List<String>>{};
    Future<void> record(String label) async {
      await home.waitFor(() => !shown(tester).contains('b.gif'));
      await home.settle();
      expect(tester.takeException(), isNull, reason: label);
      orders[label] = shown(tester);
    }

    worksSort(tester).onSortByNameChanged(false);
    await record('updatedDesc');
    worksSort(tester).onSortByNameChanged(true);
    await record('nameDesc');
    worksSort(tester).onToggleDirection();
    await record('nameAsc');
    worksSort(tester).onSortByNameChanged(false);
    await record('updatedAsc');

    expect(orders, {
      'updatedDesc': ['c.gif', 'a.gif'],
      'nameDesc': ['c.gif', 'a.gif'],
      'nameAsc': ['a.gif', 'c.gif'],
      'updatedAsc': ['a.gif', 'c.gif'],
    });

    // ほかのタブから戻っても（覚えている一覧から作り直す）出さない。
    await home.showTab(0);
    await home.showTab(1);
    expect(tester.takeException(), isNull);
    expect(shown(tester), isNot(contains('b.gif')));
    await home.close();
  });

  testWidgets('a file removed outside the app is not listed inside its works '
      'folder', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['a.gif', 'b.gif', 'c.gif'],
    );
    stamp(home);
    final folders = tester
        .element(find.byType(HomeScreen))
        .read<WorkFolderService>();
    final clips = (await tester.runAsync(() async {
      final folder = await folders.createFolder('Clips');
      await folders.moveFileToFolder('a.gif', folder.id);
      await folders.moveFileToFolder('b.gif', folder.id);
      return folder;
    }))!;
    await home.showTab(1);
    File('${home.dir.path}/exports/b.gif').deleteSync();
    await tester.tap(find.byKey(ValueKey('collectionFolder_${clips.id}')));
    await home.waitFor(() {
      final names = shown(tester);
      return names.contains('a.gif') && !names.contains('b.gif');
    });
    await home.settle();
    expect(tester.takeException(), isNull);
    expect(shown(tester), ['a.gif']);
    await home.close();
  });
}
