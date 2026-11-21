import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers/home_keyboard_harness.dart';

/// 作品一覧・共有のタブで検索に何も当たらないとき、「検索をやめる」は
/// スクロールしなくても浮かぶボタン（新しいフォルダ）の上に出て、押せる。
/// fr・ko×320/360×文字1倍・2倍。
///
/// 以前はプロジェクトのタブだけが空の表示に残りの高さ（fitIn）を渡して
/// 丸い印を小さくしていて、作品一覧・共有では大きな印のまま「検索をやめる」が
/// 浮かぶボタンの下に半分隠れた（fr 360・文字2倍、DISC204）。
void main() {
  for (final language in const ['fr', 'ko']) {
    for (final width in const [320, 360]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('$language $width x$scale: "clear search" sits above the '
            'floating buttons in Works and Shared', (tester) async {
          final home = await HomeKeyboardHarness.open(
            tester,
            language: language,
            size: Size(width.toDouble(), 740),
            textScale: scale,
          );
          final l10n = home.l10n;
          final problems = <String>[];
          for (final tab in const [1, 2]) {
            await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
            await home.settle();
            await tester.tap(find.byKey(const Key('homeSearchButton')));
            await home.settle();
            await tester.enterText(
              find.byKey(const Key('homeSearchInput')),
              'zzqx',
            );
            await home.settle();
            final clear = find.widgetWithText(
              OutlinedButton,
              l10n.projectListClearSearch,
            );
            if (clear.evaluate().isEmpty) {
              problems.add('tab $tab: no "clear search"');
              continue;
            }
            final rect = tester.getRect(clear);
            final fabs = home.fabRects();
            if (fabs.isEmpty) problems.add('tab $tab: no floating button');
            for (final fab in fabs) {
              // 浮かぶボタンの上に間を空けて出す。
              if (rect.bottom > fab.top - 8) {
                problems.add(
                  'tab $tab: "clear search" $rect reaches the floating '
                  'button $fab',
                );
              }
            }
            final hit = tester.hitTestOnBinding(rect.center).path;
            final button = tester.renderObject(clear);
            if (!hit.any((e) => identical(e.target, button))) {
              problems.add('tab $tab: "clear search" is not hit at its centre');
            }
            final shot = await home.shot();
            Directory(
              'build/home-no-match-above-fabs',
            ).createSync(recursive: true);
            File(
              'build/home-no-match-above-fabs/${language}_${width}_x${scale}_tab$tab.png',
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
            // 押すと検索が閉じる。
            if (problems.isEmpty) {
              await tester.tap(clear);
              await home.settle();
              expect(find.byKey(const Key('homeSearchInput')), findsNothing);
            } else {
              await tester.tap(find.byKey(const Key('homeSearchCloseButton')));
              await home.settle();
            }
          }
          expect(problems, isEmpty, reason: problems.join('\n'));
          expect(tester.takeException(), isNull);
          await home.close();
        });
      }
    }
  }
}
