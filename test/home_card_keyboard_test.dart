import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_keyboard_harness.dart';

/// ホームのカードの本体（星・︙だけでなく）にTabで止まり、Enterで開き、
/// Spaceで選ぶ（長押しと同じ。選んでいる間のSpaceは選ぶ・外すの切り替え）。
/// 止まったカードはキーボードで操作している間だけ印が見える。プロジェクト
/// （作品・フォルダ）・作品一覧（書き出した作品・フォルダ）・共有（受け取った
/// 作品・フォルダ、作成したファイル）・ゴミ箱の各カード。スマホ360・PC1280。
///
/// 以前はプロジェクトの格子のカードの本体がフォーカスを持たず、Tabは星と︙に
/// しか止まらなかった（キーボードだけではカードを開けず、選べなかった）。
/// ほかのタブのカードはTabで止まるが、SpaceもEnterと同じく開くだけで、選べ
/// なかった（DISC143）。
void main() {
  for (final (label, size, pc) in const [
    ('phone 360', Size(360, 740), false),
    ('PC 1280', Size(1280, 800), true),
  ]) {
    testWidgets('$label: card bodies are Tab stops, Enter opens and Space '
        'selects', (tester) async {
      final home = await HomeKeyboardHarness.open(
        tester,
        size: size,
        prefs: {'force_pc_mode': pc ? 1 : 0},
      );
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final projects = home.projects;
      final works = tester
          .element(find.byType(HomeScreen))
          .read<WorkFolderService>();
      final problems = <String>[];

      Future<void> io([int rounds = 4]) async {
        for (var i = 0; i < rounds; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await home.settle();
      }

      await tester.runAsync(() async {
        // プロジェクト：フォルダ「Folder P」と作品「Card P」。ゴミ箱へ
        // 「Trashed P」。
        await projects.createFolder('Folder P');
        await projects.createProject(
          name: 'Card P',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 32,
          exportHeight: 32,
        );
        final trashed = await projects.createProject(
          name: 'Trashed P',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 32,
          exportHeight: 32,
        );
        await projects.deleteProject(trashed.id);
        // 作品一覧：フォルダ「Folder W」と書き出した作品「card_w.gif」。
        final exports = await ExportStorage.createManagedDirectory();
        final gif = img.encodeGif(img.Image(width: 8, height: 8));
        File('${exports.path}/card_w.gif').writeAsBytesSync(gif);
        File('${exports.path}/inside_w.gif').writeAsBytesSync(gif);
        final folder = await works.createFolder('Folder W');
        await works.moveFileToFolder('inside_w.gif', folder.id);
        ExportStorage.invalidate();
        await ExportEngine.listExportedFiles(forceRefresh: true);
        // 共有：受け取った「Card S」とフォルダ「Folder S」。
        final original = await projects.createProject(
          name: 'Card S',
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
        await projects.createSharedFolder('Folder S');
      });
      await io();

      /// 今フォーカスのある所が、名前[name]のカードの本体（星・︙ではない）か。
      bool onBody(String name) {
        final node = FocusManager.instance.primaryFocus;
        // 名前は折り返しの印（幅の無い空白・語結合子）を挟んで描くことがある。
        final text = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? w.textSpan?.toPlainText() ?? '')
                  .replaceAll(RegExp('[\u200B\u2060]'), '')
                  .contains(name),
        );
        if (node == null || text.evaluate().isEmpty) return false;
        final rect = node.rect;
        return rect.width > 60 &&
            text.evaluate().any(
              (e) => rect.contains(tester.getCenter(find.byWidget(e.widget))),
            );
      }

      /// 一覧の一番上からTabで進み、[name]のカードの本体に止まるか。
      Future<bool> tabTo(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        for (var i = 0; i < 60; i++) {
          await home.tab();
          if (onBody(name)) return true;
        }
        return false;
      }

      /// 止まったカードの印が、キーボードで操作している間だけ見えるか。
      Future<void> checkRing(String where) async {
        final rect = FocusManager.instance.primaryFocus!.rect.inflate(4);
        final keyboard = await home.shot();
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await tester.pump();
        final touch = await home.shot();
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
        await tester.pump();
        var changed = 0;
        for (var y = rect.top.ceil(); y < rect.bottom.floor(); y += 1) {
          for (var x = rect.left.ceil(); x < rect.right.floor(); x += 1) {
            final p = Offset(x.toDouble(), y.toDouble());
            if (keyboard.at(p) != touch.at(p)) changed++;
          }
        }
        if (changed < 40) {
          problems.add('$where: no visible focus mark ($changed px)');
        }
        // 確かめに見る画面（build/home-card-keyboard/、止まったカードの所）。
        final crop = rect.inflate(12).intersect(Offset.zero & size);
        Directory('build/home-card-keyboard').createSync(recursive: true);
        File(
          'build/home-card-keyboard/${pc ? 'pc' : 'sp'}_'
          '${where.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.png',
        ).writeAsBytesSync(
          img.encodePng(
            img.copyCrop(
              img.Image.fromBytes(
                width: keyboard.width,
                height: keyboard.height,
                bytes: keyboard.rgba.buffer,
                numChannels: 4,
              ),
              x: crop.left.floor(),
              y: crop.top.floor(),
              width: crop.width.floor(),
              height: crop.height.floor(),
            ),
          ),
        );
      }

      bool selecting() =>
          find.byType(HomeSelectionToolbar).evaluate().isNotEmpty;

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await io(2);
      }

      /// Spaceで選び、もう一度で外す（フォーカスはカードに残る）。
      Future<void> checkSpace(String where, String name) async {
        await press(LogicalKeyboardKey.space);
        if (!selecting()) {
          problems.add('$where: Space did not select');
          return;
        }
        if (!onBody(name)) problems.add('$where: focus left the card');
        await press(LogicalKeyboardKey.space);
        if (selecting()) problems.add('$where: second Space kept selecting');
      }

      /// Enterで開く（ホームが別の画面・ダイアログに覆われるか、[opened]が
      /// 出る）。戻ってホームの一覧に戻す。
      Future<void> checkEnter(String where, {Finder? opened}) async {
        await press(LogicalKeyboardKey.enter);
        await io(4);
        final covered = find
            .byType(TabBarView)
            .hitTestable()
            .evaluate()
            .isEmpty;
        final shown = opened != null && opened.evaluate().isNotEmpty;
        if (!covered && !shown) problems.add('$where: Enter did not open');
        await tester.binding.handlePopRoute();
        await io(4);
      }

      Future<void> card(
        int tab,
        String name, {
        bool enter = true,
        Finder? opened,
      }) async {
        await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
        await io();
        final where = 'tab $tab "$name"';
        if (!await tabTo(name)) {
          problems.add('$where: Tab never stopped on the card');
          return;
        }
        await checkRing(where);
        await checkSpace(where, name);
        if (enter) {
          if (!onBody(name) && !await tabTo(name)) return;
          await checkEnter(where, opened: opened);
        }
      }

      final l10n = home.l10n;
      await card(0, 'Card P');
      await card(
        0,
        'Folder P',
        opened: find.byTooltip(l10n.projectListFolderRootOption),
      );
      await card(1, 'card_w');
      await card(1, 'Folder W');
      await card(2, 'Card S');
      await card(2, 'Folder S');
      await card(3, 'Trashed P', enter: false);

      expect(problems, isEmpty, reason: problems.join('\n'));
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
