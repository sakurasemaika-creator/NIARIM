import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_app_harness.dart';

/// ホームの名前の並びは人が読む順（数字は数として、大文字・小文字、全角・
/// 半角、カタカナ・ひらがなの違いは区別しない）。同じ名前・同じ時刻の項目は
/// もう一方の基準で決まった順に並ぶ（描き直すたびに入れ替わらない）。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  Future<void> chooseName(WidgetTester tester, {bool ascending = true}) async {
    await tester.tap(find.byTooltip(ja.homeSortFieldUpdated).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ja.homeSortFieldName).last);
    await tester.pumpAndSettle();
    // 名前を選ぶと降順のまま。
    if (ascending) {
      await tester.tap(find.byTooltip(ja.homeSortDirectionDescTooltip).first);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the projects tab sorts names for people', (tester) async {
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'detail'},
    );
    await home.open(
      size: const Size(800, 1200),
      seed: (service) async {
        for (final name in [
          '作品10',
          '作品2',
          '作品1',
          'Banana',
          'apple',
          'ＡＢＣ全角',
          'ｶﾀｶﾅ',
        ]) {
          await HomeAppHarness.work(service, name);
        }
        await service.createFolder('フォルダB');
      },
    );
    await chooseName(tester);
    // フォルダは作品と一緒に名前で並ぶ（今の並べ方）。
    expect(home.shownNames(), [
      'ＡＢＣ全角',
      'apple',
      'Banana',
      'ｶﾀｶﾅ',
      'フォルダB',
      '作品1',
      '作品2',
      '作品10',
    ]);
    // 降順は逆の順。
    await tester.tap(find.byTooltip(ja.homeSortDirectionAscTooltip).first);
    await tester.pumpAndSettle();
    expect(home.shownNames(), [
      '作品10',
      '作品2',
      '作品1',
      'フォルダB',
      'ｶﾀｶﾅ',
      'Banana',
      'apple',
      'ＡＢＣ全角',
    ]);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  Project project(String id, String name, {int fps = 12, int day = 1}) =>
      Project(
        id: id,
        name: name,
        fps: fps,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        createdAt: DateTime(2026, 1, day),
        updatedAt: DateTime(2026, 1, day),
        totalWorkSeconds: 0,
      );

  Widget list(List<Project> projects, ProjectSortMode sortMode) =>
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
              sortMode: sortMode,
              isSelectionMode: false,
              selectedIds: const {},
              onLongPress: (_) {},
              onSelectionChanged: (_) {},
              currentFolderId: null,
              onOpenFolder: (_) {},
            ),
          ),
        ),
      );

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.textContaining(text)).dy;

  testWidgets('equal names or times keep a fixed order', (tester) async {
    // 名前が同じなら新しい方が先（一覧の元の並びは古い方が先）。
    for (final mode in [ProjectSortMode.nameAsc, ProjectSortMode.nameDesc]) {
      await tester.pumpWidget(
        list([
          project('old', '同じ', fps: 12, day: 1),
          project('new', '同じ', fps: 24, day: 2),
        ], mode),
      );
      await tester.pump();
      expect(
        top(tester, ja.homeProjectMeta(24, 1)),
        lessThan(top(tester, ja.homeProjectMeta(12, 1))),
        reason: '$mode',
      );
    }
    // 時刻が同じなら名前の順（一覧の元の並びは名前の逆）。
    for (final mode in [
      ProjectSortMode.updatedAsc,
      ProjectSortMode.updatedDesc,
    ]) {
      await tester.pumpWidget(
        list([project('b', '作品10'), project('a', '作品2')], mode),
      );
      await tester.pump();
      expect(
        top(tester, '作品2'),
        lessThan(top(tester, '作品10')),
        reason: '$mode',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
