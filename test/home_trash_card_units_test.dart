import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

/// ゴミ箱のカードの2行目（種類・移した日・fps・長さ・中身の件数）は、狭い幅・
/// 大きな文字で折り返しても、数と単位（「12fps」「10秒」「フォルダ2件」
/// 「2 folders」「2개」）と日付の途中で行を変えない（DISC162：ja 360px・
/// 文字1.0で「12fps · 10 / 秒」と切れていた）。ゴミ箱に出るどのカードでも
/// （作成したプロジェクト・受け取った作品・作品の入ったフォルダ・フォルダ
/// だけの入ったフォルダ・読めていない作品の入ったフォルダ・書き出した
/// ファイル・作品一覧のフォルダ・作成した共有ファイル）、7言語・320/360/
/// 412px・文字1.0/1.3/2.0で。同梱の書体で描く。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const widths = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.3, 2.0];

  /// 数とその単位：すぐ後に続く字（「12fps」「10s」「10秒」「2件」「2개」
  /// 「2个」）、または空白を1つ挟んだ語（「2 folders」「1 projet」）。日付の
  /// 中の数（「2026/11/15」「15.」）からは始めない。
  final numberWithUnit = RegExp(
    r'(?<![\d.,/:])\d+(?:[.,]\d+)?'
    r'(?:fps|ips|\s*i/s|\s*s\b|[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}'
    r'\p{Script=Hangul}]| \p{L}+)',
    unicode: true,
  );

  /// どの種類の数と単位を確かめたか（fps・長さ・件数）。
  String kindOf(String part) {
    if (RegExp(r'fps|ips|i/s').hasMatch(part)) return 'fps';
    if (RegExp(r'^\d+(?:\s*s|s|秒|초)').hasMatch(part)) return 'duration';
    return 'count';
  }

  for (final language in languages) {
    testWidgets('Trash card subtitles keep numbers with their units and '
        'dates whole ($language)', (tester) async {
      // 読めていない作品（保存がファイルでなく開けない）を2件含む、ゴミ箱の
      // フォルダ。2行目は記録の件数（「プロジェクト2件・フォルダ1件」）と
      // 読み込めていないことの2行になる。
      final held = DateTime.now();
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(412, 4000),
        exports: ['clip_1.gif', 'clip_2.gif'],
        prefs: {
          'trashed_projects': [
            for (final id in ['unread_a', 'unread_b'])
              '$id|${held.toIso8601String()}',
          ],
          'trashed_project_folders': jsonEncode([
            TrashedFolder(
              folder: ProjectFolder(id: 'held', name: 'held', createdAt: held),
              subfolders: [
                ProjectFolder(
                  id: 'held_inner',
                  name: 'inner',
                  parentFolderId: 'held',
                  createdAt: held,
                ),
              ],
              projectIds: const ['unread_a', 'unread_b'],
              deletedAt: held,
            ).toJson(),
          ]),
        },
        beforeBoot: (documents) {
          for (final id in ['unread_a', 'unread_b']) {
            Directory(
              '${documents.path}/niarim/projects/$id/$id.niapro',
            ).createSync(recursive: true);
          }
        },
      );
      final l10n = home.l10n;
      final projects = home.projects;
      // 作成したプロジェクト（12fps・10秒）。
      final clip = (await tester.runAsync(
        () => projects.createProject(
          name: 'clip',
          fps: 12,
          durationSeconds: 10,
          backgroundColor: 0xFFFFFFFF,
        ),
      ))!;
      await tester.runAsync(() async {
        await projects.saveProject(clip.id);
        await projects.deleteProject(clip.id);
      });
      // 受け取った作品。
      final gift = await home.addReceived('gift');
      await tester.runAsync(() => projects.deleteProject(gift.id));
      // 作品の入ったフォルダと、フォルダだけの入ったフォルダ。
      final box = await home.addFolder('box');
      await home.addWork('pear', folderId: box.id);
      final outer = await home.addFolder('outer');
      await home.addFolder('one', parentId: outer.id);
      await home.addFolder('two', parentId: outer.id);
      await tester.runAsync(() async {
        await projects.moveFolderToTrash(box.id);
        await projects.moveFolderToTrash(outer.id);
      });
      // 書き出したファイル・作品一覧のフォルダ・作成した共有ファイル。
      final share = File(
        '${home.dir.path}/niarim/shared/outgoing/mine_share.niashare',
      )..createSync(recursive: true);
      share.writeAsBytesSync(List.filled(64, 1));
      await tester.runAsync(() async {
        await LocalFileTrashService.move(
          File('${home.dir.path}/exports/clip_1.gif'),
          LocalTrashKind.exportedWork,
        );
        await LocalFileTrashService.moveWorkFolder(
          folderName: 'Clips',
          files: [File('${home.dir.path}/exports/clip_2.gif')],
        );
        await LocalFileTrashService.move(share, LocalTrashKind.outgoingShare);
      });
      await home.settleIo(2);
      await home.showTab(3);
      final tiles = find.descendant(
        of: find.byType(Card),
        matching: find.byType(ListTile),
      );
      await home.waitFor(
        () => tiles.evaluate().length == 8,
        reason: 'the Trash does not list the 8 cards',
      );
      expect(
        projects.trashedFolders.map((t) => t.folder.id),
        containsAll(['held', box.id, outer.id]),
      );
      expect(
        projects.trashedFolderHasUnreadWorks(
          projects.trashedFolders.firstWhere((t) => t.folder.id == 'held'),
        ),
        isTrue,
        reason: 'the folder with unread works is not marked',
      );
      final dates = {
        for (final when in [
          projects.deletedAtOf(clip.id)!,
          held,
          ...(await tester.runAsync(
            LocalFileTrashService.list,
          ))!.map((e) => e.deletedAt),
        ])
          DateFormat.yMd(l10n.localeName).format(when),
      };
      final problems = <String>[];
      final checked = <String, int>{};
      for (final scale in scales) {
        for (final width in widths) {
          tester.view.physicalSize = Size(width, 4000);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await home.settle();
          // ゴミ箱のカード8枚がすべて描かれている。
          expect(tiles, findsNWidgets(8), reason: '$width x$scale');
          for (final tile in tiles.evaluate()) {
            final subtitle = (tile.widget as ListTile).subtitle!;
            for (final element
                in find
                    .descendant(
                      of: find.byWidget(subtitle),
                      matching: find.byType(RichText),
                    )
                    .evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              final lines = ParagraphLines(paragraph);
              // 改行しない空白は空白として探す（字の数は同じ）。
              final text = lines.visible.replaceAll('\u00a0', ' ');
              final parts = <(String, String, int)>[
                for (final date in dates)
                  for (final m in RegExp(RegExp.escape(date)).allMatches(text))
                    ('date', date, m.start),
                for (final m in numberWithUnit.allMatches(text))
                  (kindOf(m[0]!), m[0]!, m.start),
              ];
              for (final (kind, part, at) in parts) {
                // 行の幅そのものより広いかたまりは、どこかで折るしかない。
                final painter = TextPainter(
                  text: TextSpan(
                    text: part,
                    style: (paragraph.text as TextSpan).style,
                  ),
                  textDirection: paragraph.textDirection,
                  textScaler: paragraph.textScaler,
                  locale: paragraph.locale,
                )..layout();
                final fits = painter.width <= paragraph.constraints.maxWidth;
                painter.dispose();
                if (!fits) continue;
                checked[kind] = (checked[kind] ?? 0) + 1;
                if (lines.breaksWithin(at, at + part.length).isNotEmpty) {
                  problems.add(
                    '${width.toInt()} x$scale 「$part」: '
                    '${lines.lines.join(' / ')}',
                  );
                }
              }
            }
          }
        }
      }
      debugPrint('$language: checked $checked, ${problems.length} split');
      for (final problem in problems.take(20)) {
        debugPrint('  $problem');
      }
      // fps・長さ・件数・日付のどれも、すべての幅と文字の大きさで確かめた。
      for (final kind in ['fps', 'duration', 'count', 'date']) {
        expect(
          checked[kind] ?? 0,
          greaterThanOrEqualTo(widths.length * scales.length),
          reason: 'too few $kind parts checked: $checked',
        );
      }
      expect(problems, isEmpty);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
