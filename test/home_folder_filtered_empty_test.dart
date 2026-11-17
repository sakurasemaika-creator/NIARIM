import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_keyboard_harness.dart';

/// 作品一覧・共有のフォルダの中の画面で、タブから引き継いだ検索・「お気に
/// 入りだけ」の絞り込みが中身を全部隠したときは、タブと同じ文（「…に一致
/// する作品はありません」「このフォルダにお気に入りはありません」）と、
/// 絞り込みを外すボタン（「検索をやめる」「すべて表示」）を出す。押すと
/// フォルダの中身が出る。7言語×スマホ（360）・PC（1280）。
///
/// 以前は中身があるのに「このフォルダには書き出した作品がありません」
/// 「このフォルダには共有プロジェクトがありません」と言い、外す道が無かった
/// （DISC202、タブの空の表示を直したDISC138と同じ形）。
void main() {
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  for (final (label, size, pc) in const [
    ('phone 360', Size(360, 740), false),
    ('PC 1280', Size(1280, 800), true),
  ]) {
    for (final language in languages) {
      testWidgets('$language $label: a folder hidden by the carried-over '
          'filter says so and can show its contents', (tester) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          prefs: {'force_pc_mode': pc ? 1 : 0},
        );
        final l10n = home.l10n;
        final problems = <String>[];
        final context = tester.element(find.byType(HomeScreen));
        final works = context.read<WorkFolderService>();
        final projects = home.projects;

        /// ファイルの読み書きを終わらせてから描く。
        Future<void> io([int rounds = 4]) async {
          for (var i = 0; i < rounds; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          await home.settle();
        }

        late String workBox;
        late String sharedBox;
        late String alpha;
        await tester.runAsync(() async {
          // 作品一覧：フォルダ「Box」に alpha.gif・beta.gif。
          final exports = await ExportStorage.createManagedDirectory();
          final gif = img.encodeGif(img.Image(width: 8, height: 8));
          for (final name in ['alpha.gif', 'beta.gif']) {
            File('${exports.path}/$name').writeAsBytesSync(gif);
          }
          workBox = (await works.createFolder('Box')).id;
          await works.moveFileToFolder('alpha.gif', workBox);
          await works.moveFileToFolder('beta.gif', workBox);
          ExportStorage.invalidate();
          await ExportEngine.listExportedFiles(forceRefresh: true);
          // 共有：受け取ったフォルダ「Box」に Alpha・Beta。
          final ids = <String>[];
          for (final name in ['Alpha', 'Beta']) {
            final original = await projects.createProject(
              name: name,
              fps: 1,
              durationSeconds: 1,
              backgroundColor: 0xFFFFFFFF,
              exportWidth: 32,
              exportHeight: 32,
            );
            await projects.saveProject(original.id);
            final base = await NiaproSerializer.projectsBasePath();
            final data = await NiaproSerializer.load(
              '$base/${original.id}/${original.id}.niapro',
            );
            final imported = await projects.importSharedProject(data);
            await projects.saveProject(imported.id);
            await projects.deleteProject(original.id);
            ids.add(imported.id);
          }
          sharedBox = (await projects.createSharedFolder('Box')).id;
          for (final id in ids) {
            await projects.moveToSharedFolder(id, sharedBox);
          }
          alpha = ids.first;
        });
        await io();

        Future<void> openTab(int tab) async {
          await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
          await io();
        }

        Future<void> search(String query) async {
          await tester.tap(find.byKey(const Key('homeSearchButton')));
          await home.settle();
          await tester.enterText(
            find.byKey(const Key('homeSearchInput')),
            query,
          );
          await io();
        }

        Future<void> closeSearch() async {
          await tester.tap(find.byKey(const Key('homeSearchCloseButton')));
          await io();
        }

        Future<void> enterFolder(String id) async {
          final folder = find.byKey(ValueKey('collectionFolder_$id'));
          await tester.ensureVisible(folder);
          await tester.tap(folder);
          await io(6);
        }

        Future<void> leaveFolder() async {
          await tester.binding.handlePopRoute();
          await io();
        }

        /// フォルダの中の空の表示が[title]で、[action]を押すと[shown]が出るか。
        Future<void> expectWayOut(
          String where,
          String title,
          String action,
          String shown,
        ) async {
          if (find.text(title).evaluate().isEmpty) {
            final texts = [
              for (final e in find.bySubtype<Text>().evaluate())
                (e.widget as Text).data ?? '',
            ].where((t) => t.isNotEmpty).join(' | ');
            problems.add('$where: no "$title" (shown: $texts)');
          }
          final button = find.widgetWithText(OutlinedButton, action);
          if (button.evaluate().isEmpty) {
            problems.add('$where: no "$action"');
            return;
          }
          // 確かめに見る画面（build/home-folder-filtered-empty/）。
          final shot = await home.shot();
          Directory(
            'build/home-folder-filtered-empty',
          ).createSync(recursive: true);
          File(
            'build/home-folder-filtered-empty/'
            '${language}_${pc ? 'pc' : 'sp'}_${where.replaceAll(' ', '_')}.png',
          ).writeAsBytesSync(
            img.encodePng(
              img.Image.fromBytes(
                width: shot.width,
                height: shot.height,
                bytes: shot.rgba.buffer,
                numChannels: 4,
              ),
            ),
          );
          final rect = tester.getRect(button);
          if (!(Offset.zero & size).contains(rect.center)) {
            problems.add('$where: "$action" off screen at $rect');
            return;
          }
          await tester.tap(button);
          await io();
          if (find.textContaining(shown).evaluate().isEmpty) {
            problems.add('$where: "$shown" not shown after "$action"');
          }
        }

        // 作品一覧：「alp」で探してフォルダへ入り、当たった作品がフォルダの
        // 外へ移ると、残りの beta.gif は検索で隠れる。
        await openTab(1);
        await search('alp');
        await enterFolder(workBox);
        expect(find.textContaining('alpha'), findsWidgets);
        await tester.runAsync(() => works.moveFileToFolder('alpha.gif', null));
        await io();
        await expectWayOut(
          'works search',
          l10n.projectListNoMatchTitle('alp'),
          l10n.projectListClearSearch,
          'beta',
        );
        await leaveFolder();
        await closeSearch();
        await tester.runAsync(
          () => works.moveFileToFolder('alpha.gif', workBox),
        );
        await io();

        // 作品一覧：お気に入りの alpha.gif だけで入り、星を外すと隠れる。
        await enterFolder(workBox);
        final star = find.descendant(
          of: find.ancestor(
            of: find.textContaining('alpha'),
            matching: find.byType(ExportedWorkCard),
          ),
          matching: find.byTooltip(l10n.colorPickerFavoriteAdd),
        );
        await tester.tap(star.first);
        await io();
        await leaveFolder();
        await tester.tap(find.byKey(const Key('worksFavoritesOnlyFilter')));
        await io();
        await enterFolder(workBox);
        await tester.tap(find.byTooltip(l10n.colorPickerFavoriteRemove).first);
        await io();
        await expectWayOut(
          'works favourites',
          l10n.projectListNoFavoritesInFolderTitle,
          l10n.projectListShowAll,
          'beta',
        );
        await leaveFolder();
        await tester.tap(find.byKey(const Key('worksFavoritesOnlyFilter')));
        await io();

        // 共有：「alp」で探してフォルダへ入り、当たった作品の名前が変わると
        // 残りの Beta も検索で隠れる。
        await openTab(2);
        await search('alp');
        await enterFolder(sharedBox);
        await tester.runAsync(() => projects.renameProject(alpha, 'Gamma'));
        await io();
        await expectWayOut(
          'shared search',
          l10n.projectListNoMatchTitle('alp'),
          l10n.projectListClearSearch,
          'Beta',
        );
        await leaveFolder();
        await closeSearch();

        // 共有：お気に入りの Gamma だけで入り、お気に入りから外すと隠れる。
        await tester.runAsync(() => projects.setFavorite(alpha, true));
        await io();
        await tester.tap(find.byKey(const Key('sharedFavoritesOnlyFilter')));
        await io();
        await enterFolder(sharedBox);
        await tester.tap(find.byKey(Key('collectionFavorite_$alpha')).first);
        // お気に入りの印は保存の後で変わる（本物のファイルの書き込み）。
        for (
          var i = 0;
          i < 40 && projects.shared.firstWhere((p) => p.id == alpha).isFavorite;
          i++
        ) {
          await io(1);
        }
        expect(
          projects.shared.firstWhere((p) => p.id == alpha).isFavorite,
          isFalse,
        );
        await expectWayOut(
          'shared favourites',
          l10n.projectListNoFavoritesInFolderTitle,
          l10n.projectListShowAll,
          'Beta',
        );
        await leaveFolder();

        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
