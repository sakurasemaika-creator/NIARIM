import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/export_storage.dart';

import 'helpers/home_keyboard_harness.dart';

/// 作品一覧のタブを一度開いてから別のタブへ移っても、Tab・Shift+Tabは例外を
/// 出さず、見えていない作品一覧のカード・絞り込みには止まらない。止まった
/// カードは今までどおり見える所へ送り出す。スマホ360・PC1280。
///
/// 作品一覧のタブは開き直しで読み直さないよう、ほかのタブにいる間も作った
/// まま残す（AutomaticKeepAlive）。残したページの中の止まり先がTabの順に
/// 入り、見せようとした所でページの並びの中で並べていないページの位置を
/// 求め、`RenderViewportBase.getOffsetToReveal`のnullの確かめで例外になった
/// （DISC257）。
void main() {
  for (final (label, size, pc) in const [
    ('phone 360', Size(360, 740), false),
    ('PC 1280', Size(1280, 800), true),
  ]) {
    for (final shift in [false, true]) {
      testWidgets('$label ${shift ? 'Shift+Tab' : 'Tab'}: no exception and no '
          'stop in the hidden Works page', (tester) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          size: size,
          works: 12,
          prefs: {'force_pc_mode': pc ? 1 : 0},
        );
        await tester.runAsync(() async {
          final exports = await ExportStorage.createManagedDirectory();
          final gif = img.encodeGif(img.Image(width: 8, height: 8));
          for (var i = 0; i < 6; i++) {
            File('${exports.path}/clip_$i.gif').writeAsBytesSync(gif);
          }
          ExportStorage.invalidate();
          await ExportEngine.listExportedFiles(forceRefresh: true);
        });
        Future<void> io() async {
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          await home.settle();
        }

        // 作品一覧を開いて（カードを作らせて）から、共有・ゴミ箱を通って
        // プロジェクトへ戻る。
        await tester.tap(find.byKey(const ValueKey('home_tab_1')));
        await io();
        expect(find.byType(ExportedWorkCard), findsWidgets);
        for (final tab in const [2, 3, 0]) {
          await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
          await io();
        }

        final problems = <String>[];
        final cards = <String>{};
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        for (var step = 0; step < 90; step++) {
          await home.tab(shift: shift);
          final error = tester.takeException();
          if (error != null) {
            problems.add('step $step: ${error.toString().split('\n').first}');
            break;
          }
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused == null) continue;
          var inWorks = false;
          focused.visitAncestorElements((element) {
            inWorks = element.widget is ExportedWorkCard;
            return !inWorks;
          });
          if (inWorks) {
            problems.add('step $step: stopped in the hidden Works page');
            break;
          }
          final name = home.describeFocus();
          if (name.startsWith('collectionMenu_')) cards.add(name);
          // 止まった所は画面の中に見えている。
          final rect = FocusManager.instance.primaryFocus!.rect;
          if (!(Offset.zero & size).overlaps(rect)) {
            problems.add('step $step: $name off screen at $rect');
          }
        }
        if (cards.length < 12) {
          problems.add('reached ${cards.length} of 12 project cards');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
