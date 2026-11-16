import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers/home_keyboard_harness.dart';

/// ホームの検索欄のヒントは、開いているタブで何を探すかを言う（プロジェクト・
/// 書き出した作品・共有ファイル・ゴミ箱の中）。どの言語でも、320・360の幅で
/// 「…」で切れず、上部バーの中に収まる（タブの列に重ならない）。文字2倍でも
/// 上部バーからはみ出さない。
///
/// 以前は作品一覧・共有・ゴミ箱のタブでも「プロジェクト名で検索」と出た
/// （DISC201）。仏語の360ではゴミ箱のタブでも「Rechercher par nom …」と切れた。
void main() {
  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  // タブごとのヒントのARBのキー（プロジェクトは今までの「プロジェクト名で検索」）。
  const keys = [
    'homeSearchHint',
    'homeSearchHintWorks',
    'homeSearchHintShared',
    'homeSearchHintTrash',
  ];

  String? arb(String language, String key) =>
      (jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>)[key]
          as String?;

  for (final language in languages) {
    for (final (width, scale) in const [(320, 1.0), (360, 1.0), (360, 2.0)]) {
      testWidgets('$language $width x$scale: the search hint names what each '
          'tab searches and is not cut', (tester) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: Size(width.toDouble(), 740),
          textScale: scale,
          works: 1,
        );
        final problems = <String>[];
        final hints = <String>[];
        for (var tab = 0; tab < 4; tab++) {
          await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
          await home.settle();
          await tester.tap(find.byKey(const Key('homeSearchButton')));
          await home.settle();
          final field = tester.widget<TextField>(
            find.byKey(const Key('homeSearchInput')),
          );
          final shownHint = field.decoration?.hintText ?? '';
          // 折り返しを止める語結合子（U+2060）は文の一部ではない。
          final hint = shownHint.replaceAll('\u2060', '');
          hints.add(hint);
          final expected = arb(language, keys[tab]);
          if (expected == null) {
            problems.add('tab $tab: no ARB text ${keys[tab]}');
          } else if (hint != expected) {
            problems.add('tab $tab: hint "$hint", expected "$expected"');
          }
          final shown = find.descendant(
            of: find.byType(AppBar),
            matching: find.text(shownHint),
          );
          if (shown.evaluate().isEmpty) {
            problems.add('tab $tab: hint "$hint" not drawn');
          } else {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: shown, matching: find.byType(RichText)),
            );
            final rect = tester.getRect(shown);
            final tabs = tester.getRect(find.byType(TabBar));
            // 文字1倍では切らない。2倍でも上部バーからはみ出さない。
            if (scale == 1.0 && paragraph.didExceedMaxLines) {
              problems.add('tab $tab: hint "$hint" cut at $rect');
            }
            if (rect.bottom > tabs.top + 2 || rect.top < 0) {
              problems.add('tab $tab: hint $rect leaves the bar (tabs $tabs)');
            }
            // 韓国語は語（空白で区切った所）の途中で行を変えない。
            if (language == 'ko') {
              final text = paragraph.text.toPlainText();
              int? previous;
              double? previousTop;
              for (var i = 0; i < text.length; i++) {
                if (text[i] == ' ' || text[i] == '\u2060') continue;
                final boxes = paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: i, extentOffset: i + 1),
                );
                if (boxes.isEmpty) continue;
                final top = boxes.first.top;
                if (previous != null &&
                    top > previousTop! + 1 &&
                    !text.substring(previous, i).contains(' ')) {
                  problems.add('tab $tab: "$hint" breaks a word at $i');
                }
                previous = i;
                previousTop = top;
              }
            }
          }
          // 打ち始めたら、打った字の行は隣のボタン（検索を閉じる）と縦の
          // 真ん中がそろう（折り返したヒントの1行目の高さに残らない）。
          await tester.enterText(
            find.byKey(const Key('homeSearchInput')),
            'zzqx',
          );
          await home.settle();
          final typed = tester.getRect(
            find.descendant(
              of: find.byKey(const Key('homeSearchInput')),
              matching: find.byType(EditableText),
            ),
          );
          final closeButton = tester.getRect(
            find.byKey(const Key('homeSearchCloseButton')),
          );
          if ((typed.center.dy - closeButton.center.dy).abs() > 2) {
            problems.add(
              'tab $tab: typed line $typed is not level with the close '
              'button $closeButton',
            );
          }
          await tester.enterText(find.byKey(const Key('homeSearchInput')), '');
          await home.settle();
          // 確かめに見る画面（build/home-search-hints/、上部バーとタブ）。
          final shot = await home.shot();
          final image = img.copyCrop(
            img.Image.fromBytes(
              width: shot.width,
              height: shot.height,
              bytes: shot.rgba.buffer,
              numChannels: 4,
            ),
            x: 0,
            y: 0,
            width: shot.width,
            height: 112,
          );
          Directory('build/home-search-hints').createSync(recursive: true);
          File(
            'build/home-search-hints/${language}_${width}_x${scale}_tab$tab.png',
          ).writeAsBytesSync(img.encodePng(image));
          await tester.tap(find.byKey(const Key('homeSearchCloseButton')));
          await home.settle();
        }
        if (hints.toSet().length != 4) {
          problems.add('the four tabs do not have four hints: $hints');
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
