import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// 詳細表示の行に更新の日時を出す（所有者の判断9「日時出してください」）。
/// 作品は最後に保存した日時、フォルダは作った日時（フォルダの「更新日時」の
/// 並びに使う日時）を、その言語の日付と時刻の書き方で出す。
void main() {
  const workName = 'シーン1';
  const folderName = '第1話';

  Future<void> seed(ProjectService service) async {
    await service.createFolder(folderName);
    await HomeAppHarness.work(service, workName);
  }

  // 表示の文（日時を途中で折り返さないための語結合子・改行しない空白を
  // 普通の文に戻したもの）。
  String plain(Text text) =>
      (text.data ?? '').replaceAll('\u2060', '').replaceAll('\u00A0', ' ');

  // 行（ListTile）の中の文を全部つなげたもの。
  String rowText(WidgetTester tester, String name) {
    final row = HomeAppHarness.inProjects(
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    ).first;
    return find
        .descendant(of: row, matching: find.byType(Text))
        .evaluate()
        .map((e) => plain(e.widget as Text))
        .join('\n');
  }

  String dateTime(WidgetTester tester, DateTime value) {
    final localeName = AppLocalizations.of(
      tester.element(find.byType(ProjectListWidget)),
    )!.localeName;
    return intl.DateFormat.yMd(localeName).add_jm().format(value);
  }

  void expectDates(WidgetTester tester, ProjectService service, String why) {
    expect(tester.takeException(), isNull, reason: why);
    final work = service.projects.firstWhere((p) => p.name == workName);
    final folder = service.folders.firstWhere((f) => f.name == folderName);
    final workRow = rowText(tester, workName);
    expect(workRow, contains(dateTime(tester, work.updatedAt)), reason: why);
    final folderRow = rowText(tester, folderName);
    expect(
      folderRow,
      contains(dateTime(tester, folder.createdAt)),
      reason: why,
    );
  }

  testWidgets('detail rows show when a work was saved and a folder made', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'detail'},
    );
    final service = await home.open(seed: seed);
    expectDates(tester, service, 'ja');
    // 日本語の文（作品は「更新」、フォルダは「作成」）。
    final work = service.projects.firstWhere((p) => p.name == workName);
    final folder = service.folders.firstWhere((f) => f.name == folderName);
    expect(
      rowText(tester, workName),
      contains('${dateTime(tester, work.updatedAt)} 更新'),
    );
    expect(
      rowText(tester, folderName),
      contains('${dateTime(tester, folder.createdAt)} 作成'),
    );
    await home.close();
  });

  // 共有の「受け取ったもの」の詳細表示の行も、同じ書き方で日時を出す。
  testWidgets('received shares show their date in detail rows', (tester) async {
    const sharedName = '受け取った絵';
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.sharedViewMode.v1': 'detail'},
    );
    final service = await home.open(
      seed: (service) async {
        final original = await HomeAppHarness.work(service, sharedName);
        await service.saveProject(original.id);
        final base = await NiaproSerializer.projectsBasePath();
        final data = await NiaproSerializer.load(
          '$base/${original.id}/${original.id}.niapro',
        );
        await service.importSharedProject(data);
        await service.deleteProject(original.id);
      },
    );
    await tester.tap(find.byIcon(Icons.share_outlined).first);
    await home.settle();
    final shared = service.shared.single;
    final row = find
        .ancestor(of: find.text(sharedName), matching: find.byType(ListTile))
        .first;
    final text = find
        .descendant(of: row, matching: find.byType(Text))
        .evaluate()
        .map((e) => plain(e.widget as Text))
        .join('\n');
    final localeName = AppLocalizations.of(
      tester.element(find.byType(ListTile).first),
    )!.localeName;
    expect(
      text,
      contains(
        '${intl.DateFormat.yMd(localeName).add_jm().format(shared.updatedAt)} 更新',
      ),
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 7言語・320/360/1280px・文字1倍/2倍で、日時の行がはみ出さず、切れない。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('detail dates read in $language at every width', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(
        tester,
        language: language,
        preferences: {'home.projectViewMode.v1': 'detail'},
      );
      final service = await home.open(seed: seed);
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 800), textScale: scale);
          expectDates(tester, service, '$language $width x$scale');
        }
      }
      await home.close();
    });
  }
}
